const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const { FormData } = require('formdata-node');

const RENDER_API = 'https://groove-ai-backend-1.onrender.com/api';
const R2_BASE = 'https://d73253cc4bf37f330f27e2ce3a0e8ba2.r2.cloudflarestorage.com';
const SUPABASE_URL = 'https://tfbcdcrlhsxvlufmnzdr.supabase.co';
const SUPABASE_KEY = 'sb_publishable_z6cUnoxTW8LozDQZ5Bfmgg_zIr80-H4';
const USER_ID = '004906EC-5623-4616-B483-D0C33C2A23C2';
const DOG_IMAGE = '/Users/blakeyyyclaw/.openclaw/workspace/groove-ai/Gemini_Generated_Image_1555co1555co1555.png';
const WOMAN_IMAGE = '/Users/blakeyyyclaw/.openclaw/workspace/memory/thumbnails/Blake reference/06183b6c390a4741f1cdfa11a3f06e82.jpg';
const VIDEOS = [
  { name: 'golden-retriever-big-guy', image: DOG_IMAGE, preset: 'big-guy' },
  { name: 'golden-retriever-coco-channel', image: DOG_IMAGE, preset: 'coco-channel' },
  { name: 'golden-retriever-c-walk', image: DOG_IMAGE, preset: 'c-walk' },
  { name: 'woman-big-guy', image: WOMAN_IMAGE, preset: 'big-guy' },
  { name: 'woman-coco-channel', image: WOMAN_IMAGE, preset: 'coco-channel' },
];

// HTTP request helper function
function makeRequest(url, options = {}) {
  return new Promise((resolve, reject) => {
    const requestFn = url.startsWith('https') ? https : http;
    const req = requestFn.request(url, { method: 'GET', ...options }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve({ status: res.statusCode, data, headers: res.headers }));
    });
    req.on('error', reject);
    req.end(options.body);
  });
}

// Post helper function
function postRequest(url, body, headers = {}) {
  return new Promise((resolve, reject) => {
    const bodyStr = JSON.stringify(body);
    const opts = {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(bodyStr),
        ...headers,
      },
    };
    const requestFn = url.startsWith('https') ? https : http;
    const req = requestFn.request(url, opts, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve({ status: res.statusCode, data, headers: res.headers }));
    });
    req.on('error', reject);
    req.write(bodyStr);
    req.end();
  });
}

// Process image
async function processImage(imagePath) {
  console.log(`[processImage] ${imagePath}`);
  const imageData = fs.readFileSync(imagePath);
  const formData = new FormData();
  formData.append('user_id', USER_ID);
  formData.append('image', new Blob([imageData]), path.basename(imagePath));

  const res = await fetch(`${RENDER_API}/process-image`, {
    method: 'POST',
    body: formData,
  });
  if (!res.ok) throw new Error(`process-image failed: ${res.status}`);
  const data = await res.json();
  console.log(`✅ Processed: ${data.image_url}`);
  return data.image_url;
}

// Generate video
async function generateVideo(imageUrl, preset) {
  console.log(`[generateVideo] preset=${preset}`);
  const res = await fetch(`${RENDER_API}/generate-video`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      user_id: USER_ID,
      image_url: imageUrl,
      dance_style: preset,
      subject_type: 'PET',
    }),
  });
  if (!res.ok) throw new Error(`generate-video failed: ${res.status}`);
  const data = await res.json();
  console.log(`✅ Task created: ${data.task_id}`);
  return data.task_id;
}

// Poll for completion
async function pollUntilDone(taskId) {
  console.log(`[poll] Waiting for task ${taskId}...`);
  for (let i = 0; i < 120; i++) {
    const res = await fetch(`${RENDER_API}/video-status/${taskId}`);
    const data = await res.json();
    if (data.status === 'completed' || data.status === 'succeed') {
      console.log(`✅ Video ready: ${data.video_url}`);
      return data.video_url;
    }
    console.log(` [${i+1}/120] status=${data.status}`);
    await new Promise(r => setTimeout(r, 10000)); // 10s intervals
  }
  throw new Error('Polling timeout');
}

// Download video
async function downloadVideo(videoUrl, outputPath) {
  console.log(`[download] ${videoUrl}`);
  return new Promise((resolve, reject) => {
    const requestFn = videoUrl.startsWith('https') ? https : http;
    const file = fs.createWriteStream(outputPath);
    requestFn.get(videoUrl, (res) => {
      res.pipe(file);
      file.on('finish', () => {
        file.close();
        const size = fs.statSync(outputPath).size;
        console.log(`✅ Downloaded: ${size} bytes`);
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
    ]);
    proc.on('close', (code) => {
      if (code === 0) {
        console.log(`✅ Re-encoded: ${outputPath}`);
        resolve();
      } else {
        reject(new Error(`ffmpeg exited with code ${code}`));
      }
    });
  });
}

// Upload to R2
async function uploadToR2(filePath, fileName) {
  console.log(`[R2 upload] ${fileName}`);
  const fileContent = fs.readFileSync(filePath);
  const key = `demos/${fileName}`;
  const res = await fetch(`${R2_BASE}/${key}`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'video/mp4',
      'Cache-Control': 'public, max-age=31536000',
      'Authorization': `Bearer ${SUPABASE_KEY}`,
    },
    body: fileContent,
  });
  if (!res.ok) throw new Error(`R2 upload failed: ${res.status}`);
  const r2Url = `https://videos.trygrooveai.com/demos/${fileName}`;
  console.log(`✅ Uploaded: ${r2Url}`);
  return r2Url;
}

// Main
(async () => {
  console.log('\n🎬 GROOVE AI VIDEO GENERATION\n');
  for (const video of VIDEOS) {
    try {
      console.log(`\n━━━ ${video.name} ━━━`);
      // 1. Process image
      const processedUrl = await processImage(video.image);
      // 2. Generate video
      const taskId = await generateVideo(processedUrl, video.preset);
      // 3. Poll until done
      const klingUrl = await pollUntilDone(taskId);
      // 4. Download immediately (while tokens fresh)
      const tmpPath = `/tmp/${video.name}-raw.mp4`;
      await downloadVideo(klingUrl, tmpPath);
      // 5. Re-encode
      const encodedPath = `/tmp/${video.name}.mp4`;
      await reencodeWithFaststart(tmpPath, encodedPath);
      // 6. Upload to R2
      const r2Url = await uploadToR2(encodedPath, `${video.name}.mp4`);
      console.log(`✅ SUCCESS: ${video.name}`);
      console.log(` ${r2Url}\n`);
    } catch (err) {
      console.error(`❌ FAILED: ${video.name}`);
      console.error(` ${err.message}\n`);
    }
  }
  console.log('\n✅ DONE\n');
})();