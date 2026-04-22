const https = require('https');
const fs = require('fs');

const RENDER_API = 'https://groove-ai-backend-1.onrender.com/api';
const USER_ID = '004906EC-5623-4616-B483-D0C33C2A23C2';

const VIDEOS = [
  { name: 'woman-big-guy', filePath: '/tmp/woman-big-guy.mp4' },
];

// Try to upload via Render backend with raw POST of the file
async function uploadViaRender(filePath, videoName) {
  console.log(`\n[render-upload] ${videoName}`);
  console.log(`File: ${filePath}`);
  
  if (!fs.existsSync(filePath)) {
    throw new Error(`File not found: ${filePath}`);
  }
  
  const fileContent = fs.readFileSync(filePath);
  console.log(`Size: ${fileContent.length} bytes`);
  
  // Try different endpoint variations
  const endpoints = [
    '/upload-video',
    '/store-video',
    '/save-video',
    '/upload-demo',
    '/publish-video',
  ];
  
  for (const endpoint of endpoints) {
    try {
      console.log(`Trying ${endpoint}...`);
      
      const form = new FormData();
      form.append('user_id', USER_ID);
      form.append('video_name', videoName);
      form.append('video', new Blob([fileContent], { type: 'video/mp4' }), `${videoName}.mp4`);
      
      const res = await fetch(`${RENDER_API}${endpoint}`, {
        method: 'POST',
        body: form,
      });
      
      console.log(` Response: ${res.status}`);
      
      if (res.status === 404) {
        console.log(` Not found, trying next...`);
        continue;
      }
      
      const data = await res.json();
      
      if (res.ok) {
        const url = data.video_url || data.url || data.s3_url;
        console.log(`✅ Success via ${endpoint}: ${url}\n`);
        return url;
      } else {
        console.log(` Error: ${data.error || data.message}`);
        if (res.status !== 404) break;
      }
    } catch (err) {
      console.log(` Failed: ${err.message}`);
    }
  }
  
  return null;
}

// Main
(async () => {
  console.log('\n🎬 DIRECT RENDER UPLOAD TEST\n');
  console.log(`API: ${RENDER_API}`);
  console.log(`User: ${USER_ID}\n`);
  
  for (const video of VIDEOS) {
    try {
      const url = await uploadViaRender(video.filePath, video.name);
      if (url) {
        console.log(`Result: ${url}\n`);
      } else {
        console.log(`No suitable endpoint found\n`);
      }
    } catch (err) {
      console.error(`Error: ${err.message}\n`);
    }
  }
})();
