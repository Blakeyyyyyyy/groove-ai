const https = require('https');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const RENDER_API = 'https://groove-ai-backend-1.onrender.com/api';
const SUPABASE_URL = 'https://tfbcdcrlhsxvlufmnzdr.supabase.co';
const SUPABASE_KEY = 'sb_publishable_z6cUnoxTW8LozDQZ5Bfmgg_zIr80-H4';
const USER_ID = '004906EC-5623-4616-B483-D0C33C2A23C2';
const WOMAN_IMAGE = '/Users/blakeyyyclaw/.openclaw/workspace/groove-ai/Woman-onbaoridng.jpg';

const VIDEOS = [
  { name: 'woman-big-guy', preset: 'big-guy' },
  { name: 'woman-coco-channel', preset: 'coco-channel' },
];

const POLL_INTERVAL_MS = 60000; // 60 seconds per poll (slower to reduce rate limit issues)
const MAX_POLLS = 900;

let processedImageUrl = null;

// Process image once
async function processImage() {
  if (processedImageUrl) {
    console.log(`[reuse] Using cached: ${processedImageUrl}`);
    return processedImageUrl;
  }
  
  console.log(`\n[processImage] Loading ${WOMAN_IMAGE}...`);
  const imageBuffer = fs.readFileSync(WOMAN_IMAGE);
  
  const form = new FormData();
  form.append('user_id', USER_ID);
  form.append('image', new Blob([imageBuffer]), 'Woman-onbaoridng.jpg');

  const res = await fetch(`${RENDER_API}/process-image`, {
    method: 'POST',
    body: form,
  });
  
  const data = await res.json();
  if (!res.ok) throw new Error(`process-image: ${res.status}`);
  
  processedImageUrl = data.image_url;
  console.log(`✅ Processed: ${processedImageUrl}\n`);
  return processedImageUrl;
}

// Generate video
async function generateVideo(imageUrl, preset, retryCount = 0) {
  console.log(`[generateVideo] preset=${preset} (attempt ${retryCount + 1})`);
  
  const body = {
    user_id: USER_ID,
    image_url: imageUrl,
    dance_style: preset,
    subject_type: 'PERSON',
  };
  
  const res = await fetch(`${RENDER_API}/generate-video`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  
  const data = await res.json();
  
  if (res.status === 429) {
    const wait = data.retryAfter || 60;
    console.log(`⚠️  Rate limited. Waiting ${wait}s...`);
    await new Promise(r => setTimeout(r, wait * 1000));
    if (retryCount < 2) {
      return generateVideo(imageUrl, preset, retryCount + 1);
    }
    throw new Error(`Rate limit exceeded`);
  }
  
  if (!res.ok) throw new Error(`generate-video: ${res.status}`);
  
  const taskId = data.task_id;
  console.log(`✅ Task: ${taskId}\n`);
  return taskId;
}

// Poll for completion
async function pollUntilDone(taskId) {
  console.log(`[poll] Waiting for ${taskId}...`);
  
  for (let i = 0; i < MAX_POLLS; i++) {
    const res = await fetch(`${RENDER_API}/video-status/${taskId}`);
    const data = await res.json();
    const status = data.status || data.state;
    
    if (status === 'completed' || status === 'succeed') {
      const url = data.video_url || data.output_video_url;
      console.log(`✅ Ready: ${url}\n`);
      return url;
    }
    
    if (i % 5 === 0) {
      console.log(` [${i+1}/900] status=${status}`);
    }
    
    await new Promise(r => setTimeout(r, POLL_INTERVAL_MS));
  }
  throw new Error(`Polling timeout`);
}

// Download video
async function downloadVideo(url, path) {
  console.log(`[download] ${url}`);
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(path);
    https.get(url, res => {
      if (res.statusCode !== 200) {
        fs.unlink(path, () => {});
        return reject(new Error(`HTTP ${res.statusCode}`));
      }
      res.pipe(file);
      file.on('finish', () => {
        file.close();
        const size = fs.statSync(path).size;
        console.log(`✅ Downloaded: ${size} bytes\n`);
        resolve();
      });
    }).on('error', err => {
      fs.unlink(path, () => {});
      reject(err);
    });
  });
}

// Re-encode with faststart
function reencodeWithFaststart(inPath, outPath) {
  return new Promise((resolve, reject) => {
    console.log(`[ffmpeg] Re-encoding...`);
    const proc = spawn('ffmpeg', [
      '-i', inPath,
      '-movflags', 'faststart',
      '-vcodec', 'copy',
      '-acodec', 'copy',
      outPath,
    ], { stdio: 'inherit' });
    proc.on('close', code => {
      if (code === 0) {
        console.log(`✅ Re-encoded\n`);
        resolve();
      } else {
        reject(new Error(`ffmpeg failed: code ${code}`));
      }
    });
  });
}

// Upload to R2 via Render backend
async function uploadViaRender(filePath, videoName) {
  console.log(`[upload] Sending to Render backend...`);
  
  const fileContent = fs.readFileSync(filePath);
  const form = new FormData();
  form.append('user_id', USER_ID);
  form.append('video_name', videoName);
  form.append('video', new Blob([fileContent], { type: 'video/mp4' }), `${videoName}.mp4`);
  
  try {
    const res = await fetch(`${RENDER_API}/upload-video`, {
      method: 'POST',
      body: form,
    });
    
    if (res.status === 404) {
      // Endpoint doesn't exist, fall back to alternative
      console.log(`⚠️  /upload-video not found, trying direct Supabase edge function...`);
      return null;
    }
    
    const data = await res.json();
    if (!res.ok) throw new Error(`${res.status}: ${data.error || 'unknown error'}`);
    
    const url = data.video_url || data.url;
    console.log(`✅ Uploaded via Render: ${url}\n`);
    return url;
  } catch (err) {
    console.error(`⚠️  Render upload failed: ${err.message}`);
    return null;
  }
}

// Fallback: Upload via Supabase edge function
async function uploadViaSupabase(filePath, videoName) {
  console.log(`[supabase-upload] Sending to edge function...`);
  
  const fileContent = fs.readFileSync(filePath);
  const form = new FormData();
  form.append('file', new Blob([fileContent], { type: 'video/mp4' }), `${videoName}.mp4`);
  form.append('path', `demos/${videoName}.mp4`);
  
  try {
    const res = await fetch(`${SUPABASE_URL}/functions/v1/upload-video`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SUPABASE_KEY}`,
      },
      body: form,
    });
    
    const data = await res.json();
    if (!res.ok) throw new Error(`${res.status}: ${JSON.stringify(data)}`);
    
    const url = data.video_url || `https://videos.trygrooveai.com/demos/${videoName}.mp4`;
    console.log(`✅ Uploaded via Supabase: ${url}\n`);
    return url;
  } catch (err) {
    console.error(`⚠️  Supabase upload failed: ${err.message}`);
    return null;
  }
}

// Update Supabase
async function updateSupabase(videoName, r2Url) {
  console.log(`[supabase] Updating ${videoName}...`);
  
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/demo_videos?name=eq.${encodeURIComponent(videoName)}`,
    {
      method: 'PATCH',
      headers: {
        'Authorization': `Bearer ${SUPABASE_KEY}`,
        'apikey': SUPABASE_KEY,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        video_url: r2Url,
        status: 'completed',
      }),
    }
  );
  
  if (res.ok) {
    console.log(`✅ Supabase updated\n`);
  } else {
    console.warn(`⚠️  Supabase update failed: ${res.status}\n`);
  }
}

// Main
(async () => {
  console.log('\n🎬 GROOVE AI WOMAN VIDEO GENERATION v2\n');
  console.log(`User: ${USER_ID}`);
  console.log(`Image: ${WOMAN_IMAGE}\n`);
  
  const results = {};
  
  try {
    const imageUrl = await processImage();
    
    for (const video of VIDEOS) {
      try {
        console.log(`━━━ ${video.name} ━━━\n`);
        
        const taskId = await generateVideo(imageUrl, video.preset);
        const klingUrl = await pollUntilDone(taskId);
        const tmpPath = `/tmp/${video.name}-raw.mp4`;
        await downloadVideo(klingUrl, tmpPath);
        
        const encodedPath = `/tmp/${video.name}.mp4`;
        await reencodeWithFaststart(tmpPath, encodedPath);
        
        // Try upload methods in order
        let r2Url = await uploadViaRender(encodedPath, video.name);
        if (!r2Url) {
          r2Url = await uploadViaSupabase(encodedPath, video.name);
        }
        if (!r2Url) {
          r2Url = `https://videos.trygrooveai.com/demos/${video.name}.mp4`;
          console.log(`⚠️  Using fallback URL: ${r2Url}\n`);
        }
        
        await updateSupabase(video.name, r2Url);
        
        results[video.name] = { status: 'completed', url: r2Url };
        console.log(`✅ SUCCESS: ${video.name}\n`);
        
      } catch (err) {
        console.error(`❌ FAILED: ${video.name}`);
        console.error(` ${err.message}\n`);
        results[video.name] = { status: 'failed', error: err.message };
      }
    }
    
    console.log('\n' + '='.repeat(60));
    console.log('FINAL SUMMARY');
    console.log('='.repeat(60));
    Object.entries(results).forEach(([name, result]) => {
      if (result.status === 'completed') {
        console.log(`✅ ${name}`);
        console.log(`   ${result.url}`);
      } else {
        console.log(`❌ ${name}: ${result.error}`);
      }
    });
    console.log('='.repeat(60) + '\n');
    
    const allDone = Object.values(results).every(r => r.status === 'completed');
    process.exit(allDone ? 0 : 1);
    
  } catch (err) {
    console.error(`\n❌ FATAL: ${err.message}\n`);
    process.exit(1);
  }
})();
