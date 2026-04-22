const https = require('https');
const fs = require('fs');

const SUPABASE_URL = 'https://tfbcdcrlhsxvlufmnzdr.supabase.co';
const SUPABASE_KEY = 'sb_publishable_z6cUnoxTW8LozDQZ5Bfmgg_zIr80-H4';
const R2_ACCOUNT_ID = 'd73253cc4bf37f330f27e2ce3a0e8ba2';
const R2_BUCKET = 'groove-ai-videos';

const VIDEOS = [
  { name: 'woman-big-guy', filePath: '/tmp/woman-big-guy.mp4' },
];

// Upload to R2
async function uploadToR2(filePath, fileName) {
  console.log(`[R2 upload] ${fileName} from ${filePath}`);
  
  if (!fs.existsSync(filePath)) {
    throw new Error(`File not found: ${filePath}`);
  }
  
  const fileContent = fs.readFileSync(filePath);
  const r2Url = `https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com/${R2_BUCKET}/demos/${fileName}`;
  
  console.log(`[R2] Uploading to: ${r2Url}`);
  console.log(`[R2] File size: ${fileContent.length} bytes`);
  
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
        console.log(`[R2] Response status: ${res.statusCode}`);
        if (res.statusCode >= 200 && res.statusCode < 300) {
          const publicUrl = `https://videos.trygrooveai.com/demos/${fileName}`;
          console.log(`✅ Uploaded to: ${publicUrl}`);
          resolve(publicUrl);
        } else {
          console.error(`[R2] Error body:`, body);
          reject(new Error(`R2 upload failed: HTTP ${res.statusCode} - ${body}`));
        }
      });
    });
    
    req.on('error', (err) => {
      reject(new Error(`R2 request failed: ${err.message}`));
    });
    
    req.write(fileContent);
    req.end();
  });
}

// Verify file exists on R2
async function verifyR2(r2Url) {
  console.log(`[verify] Checking R2 URL: ${r2Url}`);
  
  return new Promise((resolve, reject) => {
    const req = https.request(r2Url, { method: 'HEAD' }, (res) => {
      console.log(`[verify] Response status: ${res.statusCode}`);
      if (res.statusCode === 200 || res.statusCode === 302) {
        console.log(`✅ Verified on R2 (HTTP ${res.statusCode})`);
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
  console.log(`[supabase] Updating ${videoName} with URL: ${r2Url}`);
  try {
    const encodedName = encodeURIComponent(videoName);
    const res = await fetch(`${SUPABASE_URL}/rest/v1/demo_videos?name=eq.${encodedName}`, {
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
    
    console.log(`[supabase] Response status: ${res.status}`);
    const body = await res.json();
    console.log(`[supabase] Response:`, body);
    
    if (res.ok) {
      console.log(`✅ Supabase updated`);
    } else {
      console.warn(`⚠️  Supabase response: ${res.status}`);
    }
  } catch (err) {
    console.warn(`⚠️  Supabase update failed: ${err.message}`);
  }
}

// Main
(async () => {
  console.log('\n🎬 UPLOAD EXISTING VIDEOS\n');
  
  const results = {};
  
  for (const video of VIDEOS) {
    try {
      console.log(`\n━━━ ${video.name} ━━━\n`);
      
      // 1. Upload to R2
      const r2Url = await uploadToR2(video.filePath, `${video.name}.mp4`);
      
      // 2. Verify
      await verifyR2(r2Url);
      
      // 3. Update Supabase
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
  console.log('SUMMARY');
  console.log('='.repeat(60));
  Object.entries(results).forEach(([name, result]) => {
    if (result.status === 'completed') {
      console.log(`✅ ${name}: ${result.url}`);
    } else {
      console.log(`❌ ${name}: ${result.error}`);
    }
  });
  console.log('='.repeat(60) + '\n');
})();
