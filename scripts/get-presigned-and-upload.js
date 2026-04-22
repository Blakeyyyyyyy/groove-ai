const https = require('https');
const fs = require('fs');

const RENDER_API = 'https://groove-ai-backend-1.onrender.com/api';
const SUPABASE_URL = 'https://tfbcdcrlhsxvlufmnzdr.supabase.co';
const SUPABASE_KEY = 'sb_publishable_z6cUnoxTW8LozDQZ5Bfmgg_zIr80-H4';
const USER_ID = '004906EC-5623-4616-B483-D0C33C2A23C2';

const VIDEOS = [
  { name: 'woman-big-guy', filePath: '/tmp/woman-big-guy.mp4' },
];

// Try to get a pre-signed URL from Render
async function getPresignedUrl(videoName) {
  console.log(`\n[presigned] Requesting URL for ${videoName}...`);
  
  const body = {
    user_id: USER_ID,
    video_name: videoName,
    bucket: 'groove-ai-videos',
    path: `demos/${videoName}.mp4`,
  };
  
  const res = await fetch(`${RENDER_API}/get-upload-url`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  
  console.log(`Response: ${res.status}`);
  
  if (!res.ok) {
    console.log(`Not available (${res.status})`);
    return null;
  }
  
  const data = await res.json();
  console.log(`✅ URL: ${data.upload_url ? 'received' : 'not in response'}`);
  return data.upload_url || data.presignedUrl || data.url;
}

// Upload using pre-signed URL
async function uploadToPresignedUrl(filePath, presignedUrl) {
  console.log(`[upload] Using pre-signed URL`);
  
  const fileContent = fs.readFileSync(filePath);
  
  return new Promise((resolve, reject) => {
    const opts = {
      method: 'PUT',
      headers: {
        'Content-Type': 'video/mp4',
        'Content-Length': fileContent.length,
      },
    };
    
    const req = https.request(presignedUrl, opts, (res) => {
      console.log(` Status: ${res.statusCode}`);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        resolve(true);
      } else {
        reject(new Error(`Upload failed: HTTP ${res.statusCode}`));
      }
    });
    req.on('error', reject);
    req.write(fileContent);
    req.end();
  });
}

// Update Supabase with public URL
async function updateSupabase(videoName) {
  console.log(`\n[supabase] Updating ${videoName}...`);
  
  const r2Url = `https://videos.trygrooveai.com/demos/${videoName}.mp4`;
  
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
  
  console.log(`Status: ${res.status}`);
  if (res.ok) {
    console.log(`✅ Updated\n`);
    return true;
  } else {
    const err = await res.json();
    console.log(`Error:`, err);
    return false;
  }
}

// Main
(async () => {
  console.log('\n🎬 PRESIGNED URL UPLOAD TEST\n');
  
  for (const video of VIDEOS) {
    try {
      if (!fs.existsSync(video.filePath)) {
        console.log(`❌ File not found: ${video.filePath}\n`);
        continue;
      }
      
      console.log(`━━━ ${video.name} ━━━`);
      
      // Try to get pre-signed URL
      const presignedUrl = await getPresignedUrl(video.name);
      
      if (presignedUrl) {
        await uploadToPresignedUrl(video.filePath, presignedUrl);
        console.log(`✅ Uploaded`);
      } else {
        console.log(`⚠️  No presigned URL available, skipping upload`);
      }
      
      // Always update Supabase
      await updateSupabase(video.name);
      
    } catch (err) {
      console.error(`❌ Error: ${err.message}\n`);
    }
  }
})();
