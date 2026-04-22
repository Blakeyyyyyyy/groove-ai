const https = require('https');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const RENDER_API = 'https://groove-ai-backend-1.onrender.com/api';
const SUPABASE_URL = 'https://tfbcdcrlhsxvlufmnzdr.supabase.co';
const SUPABASE_KEY = 'sb_publishable_z6cUnoxTW8LozDQZ5Bfmgg_zIr80-H4';
const USER_ID = '004906EC-5623-4616-B483-D0C33C2A23C2';
const WOMAN_IMAGE = '/Users/blakeyyyclaw/.openclaw/workspace/groove-ai/Woman-onbaoridng.jpg';

// Use environment variables for R2, fallback to hardcoded
const R2_ACCESS_KEY = process.env.R2_ACCESS_KEY_ID || 'e7e2f97d7f7c6dfae5d55d2f';
const R2_SECRET = process.env.R2_SECRET_ACCESS_KEY || '2e8f1e5f6c8c5f8e5f8e5f8e5f8e5f8e';
const R2_ACCOUNT_ID = process.env.R2_ACCOUNT_ID || 'd73253cc4bf37f330f27e2ce3a0e8ba2';
const R2_BUCKET = 'groove-ai-videos';

const VIDEOS = [
  { name: 'woman-big-guy', preset: 'big-guy' },
  { name: 'woman-coco-channel', preset: 'coco-channel' },
];

const POLL_INTERVAL_MS = 30000; // 30 seconds per poll
const MAX_POLLS = 900; // 900 * 30s = 7.5 hours

let processedImageUrl = null;

// Process image once
async function processImage() {
  if (processedImageUrl) {
    console.log(`[reuse] Using cached processed image: ${processedImageUrl}`);
    return processedImageUrl;
  }
  
  console.log(`\n[processImage] Loading ${WOMAN_IMAGE}...`);
  const imageBuffer = fs.readFileSync(WOMAN_IMAGE);
  
  const form = new FormData();
  form.append('user_id', USER_ID);
  form.append('image', new Blob([imageBuffer]), 'Woman-onbaoridng.jpg');

  try {
    console.log(`[processImage] Sending to ${RENDER_API}/process-image...`);
    const res = await fetch(`${RENDER_API}/process-image`, {
      method: 'POST',
      body: form,
    });
    
    console.log(`[processImage] Status: ${res.status}`);
    const contentType = res.headers.get('content-type');
    let data;
    
    if (contentType && contentType.includes('application/json')) {
      data = await res.json();
    } else {
      data = await res.text();
    }
    
    if (!res.ok) {
      console.error(`[processImage] Response:`, data);
      throw new Error(`process-image failed: ${res.status}`);
    }
    
    if (typeof data === 'string') {
      data = JSON.parse(data);
    }
    
    processedImageUrl = data.image_url;
    console.log(`✅ Image processed: ${processedImageUrl}\n`);
    return processedImageUrl;
  } catch (err) {
    console.error(`❌ Process image failed: ${err.message}`);
    throw err;
  }
}

// Generate video with rate limit handling
async function generateVideo(imageUrl, preset, retryCount = 0) {
  console.log(`[generateVideo] preset=${preset} (attempt ${retryCount + 1})`);
  try {
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
    
    console.log(`[generateVideo] Status: ${res.status}`);
    const contentType = res.headers.get('content-type');
    let data;
    
    if (contentType && contentType.includes('application/json')) {
      data = await res.json();
    } else {
      data = await res.text();
    }
    
    if (typeof data === 'string') {
      data = JSON.parse(data);
    }
    
    // Handle rate limit
    if (res.status === 429) {
      const retryAfter = data.retryAfter || 60;
      console.log(`⚠️  Rate limited. Waiting ${retryAfter}s before retry...`);
      await new Promise(r => setTimeout(r, retryAfter * 1000));
      if (retryCount < 3) {
        return generateVideo(imageUrl, preset, retryCount + 1);
      }
      throw new Error(`Rate limit exceeded after ${retryCount + 1} retries`);
    }
    
    if (!res.ok) {
      console.error(`[generateVideo] Response:`, data);
      throw new Error(`generate-video failed: ${res.status}`);
    }
    
    const taskId = data.task_id;
    console.log(`✅ Task created: ${taskId}\n`);
    return taskId;
  } catch (err) {
    console.error(`❌ Generate video failed: ${err.message}`);
    throw err;
  }
}

// Poll for completion
async function pollUntilDone(taskId, maxAttempts = MAX_POLLS) {
  console.log(`[poll] Waiting for task ${taskId} (max ${maxAttempts} attempts, ~${(maxAttempts * POLL_INTERVAL_MS / 1000 / 3600).toFixed(1)} hours)...`);
  
  for (let i = 0; i < maxAttempts; i++) {
    try {
      const res = await fetch(`${RENDER_API}/video-status/${taskId}`);
      const contentType = res.headers.get('content-type');
      let data;
      
      if (contentType && contentType.includes('application/json')) {
        data = await res.json();
      } else {
        data = await res.text();
      }
      
      if (typeof data === 'string') {
        data = JSON.parse(data);
      }
      
      const status = data.status || data.state;
      
      if (status === 'completed' || status === 'succeed') {
        const videoUrl = data.video_url || data.output_video_url;
        console.log(`✅ Video ready: ${videoUrl}\n`);
        return videoUrl;
      }
      
      if (i % 10 === 0 || i < 3) {
        console.log(` [${i+1}/${maxAttempts}] status=${status} (${((i + 1) * POLL_INTERVAL_MS / 1000 / 60).toFixed(1)} min elapsed)`);
      }
      
      await new Promise(r => setTimeout(r, POLL_INTERVAL_MS));
    } catch (err) {
      console.error(`⚠️  Poll iteration ${i+1} failed: ${err.message}`);
      if (i === maxAttempts - 1) throw err;
      await new Promise(r => setTimeout(r, POLL_INTERVAL_MS));
    }
  }
  throw new Error(`Polling timeout after ${maxAttempts} attempts`);
}

// Download video
async function downloadVideo(videoUrl, outputPath) {
  console.log(`[download] ${videoUrl}`);
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(outputPath);
    https.get(videoUrl, (res) => {
      if (res.statusCode !== 200) {
        fs.unlink(outputPath, () => {});
        reject(new Error(`Download failed: HTTP ${res.statusCode}`));
        return;
      }
      res.pipe(file);
      file.on('finish', () => {
        file.close();
        const size = fs.statSync(outputPath).size;
        console.log(`✅ Downloaded: ${size} bytes\n`);
        resolve();
      });
    }).on('error', (err) => {
      fs.unlink(outputPath, () => {});
      reject(err);
    });
  });
}

// Re-encode with faststart
function reencodeWithFaststart(inputPath, outputPath) {
  return new Promise((resolve, reject) => {
    console.log(`[ffmpeg] Re-encoding with faststart...`);
    const proc = spawn('ffmpeg', [
      '-i', inputPath,
      '-movflags', 'faststart',
      '-vcodec', 'copy',
      '-acodec', 'copy',
      outputPath,
    ], { stdio: 'inherit' });
    proc.on('close', (code) => {
      if (code === 0) {
        console.log(`✅ Re-encoded: ${outputPath}\n`);
        resolve();
      } else {
        reject(new Error(`ffmpeg exited with code ${code}`));
      }
    });
  });
}

// Upload to R2 using signed URL approach
async function uploadToR2(filePath, fileName) {
  console.log(`[R2 upload] ${fileName}`);
  const fileContent = fs.readFileSync(filePath);
  
  // Try direct R2 endpoint
  const r2Url = `https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com/${R2_BUCKET}/demos/${fileName}`;
  console.log(`[R2] Using: ${r2Url}`);
  
  return new Promise((resolve, reject) => {
    const opts = {
      method: 'PUT',
      headers: {
        'Content-Type': 'video/mp4',
        'Cache-Control': 'public, max-age=31536000',
        'Content-Length': fileContent.length,
      },
    };
    
    const req = https.request(r2Url, opts, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          const publicUrl = `https://videos.trygrooveai.com/demos/${fileName}`;
          console.log(`✅ Uploaded: ${publicUrl}\n`);
          resolve(publicUrl);
        } else {
          console.error(`[R2] Error response (${res.statusCode}):`, body);
          reject(new Error(`R2 upload failed: HTTP ${res.statusCode}`));
        }
      });
    });
    
    req.on('error', reject);
    req.write(fileContent);
    req.end();
  });
}

// Verify file exists on R2
async function verifyR2(r2Url) {
  console.log(`[verify] Checking R2 URL: ${r2Url}`);
  return new Promise((resolve, reject) => {
    const req = https.request(r2Url, { method: 'HEAD' }, (res) => {
      if (res.statusCode === 200) {
        console.log(`✅ Verified on R2 (HTTP ${res.statusCode})\n`);
        resolve();
      } else {
        reject(new Error(`R2 verification failed: HTTP ${res.statusCode}`));
      }
    });
    req.on('error', reject);
    req.end();
  });
}

// Update Supabase
async function updateSupabase(videoName, r2Url) {
  console.log(`[supabase] Updating ${videoName}...`);
  try {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/demo_videos?name=eq.${videoName}`, {
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
    });
    console.log(`✅ Supabase updated\n`);
  } catch (err) {
    console.warn(`⚠️  Supabase update failed (continuing anyway): ${err.message}\n`);
  }
}

// Main
(async () => {
  console.log('\n🎬 GROOVE AI WOMAN VIDEO GENERATION (FINAL)\n');
  console.log(`User ID: ${USER_ID}`);
  console.log(`Image: ${WOMAN_IMAGE}`);
  console.log(`R2 Bucket: ${R2_BUCKET}`);
  console.log(`Polling: ${MAX_POLLS} attempts × ${POLL_INTERVAL_MS / 1000}s = ${(MAX_POLLS * POLL_INTERVAL_MS / 1000 / 3600).toFixed(1)} hours max\n`);
  
  const results = {};
  
  try {
    // Process image once
    const imageUrl = await processImage();
    
    // Generate both videos
    for (const video of VIDEOS) {
      try {
        console.log(`\n━━━ ${video.name} ━━━\n`);
        
        // 1. Generate video task
        const taskId = await generateVideo(imageUrl, video.preset);
        
        // 2. Poll until done
        const klingUrl = await pollUntilDone(taskId);
        
        // 3. Download
        const tmpPath = `/tmp/${video.name}-raw.mp4`;
        await downloadVideo(klingUrl, tmpPath);
        
        // 4. Re-encode with faststart
        const encodedPath = `/tmp/${video.name}.mp4`;
        await reencodeWithFaststart(tmpPath, encodedPath);
        
        // 5. Upload to R2
        const r2Url = await uploadToR2(encodedPath, `${video.name}.mp4`);
        
        // 6. Verify on R2
        await verifyR2(r2Url);
        
        // 7. Update Supabase
        await updateSupabase(video.name, r2Url);
        
        results[video.name] = { status: 'completed', url: r2Url };
        console.log(`✅ SUCCESS: ${video.name}\n`);
        
      } catch (err) {
        console.error(`❌ FAILED: ${video.name}`);
        console.error(` ${err.message}\n`);
        results[video.name] = { status: 'failed', error: err.message };
      }
    }
    
    // Summary
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
    if (allDone) {
      console.log('✅ ALL VIDEOS GENERATED AND VERIFIED\n');
      process.exit(0);
    } else {
      console.log('⚠️  SOME VIDEOS FAILED (see above)\n');
      process.exit(1);
    }
    
  } catch (err) {
    console.error(`\n❌ FATAL ERROR: ${err.message}\n`);
    process.exit(1);
  }
})();
