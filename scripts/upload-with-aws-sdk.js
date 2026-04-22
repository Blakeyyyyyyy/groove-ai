const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const fs = require('fs');

const R2_ACCOUNT_ID = process.env.R2_ACCOUNT_ID || 'd73253cc4bf37f330f27e2ce3a0e8ba2';
const R2_ACCESS_KEY = process.env.R2_ACCESS_KEY_ID || 'e7e2f97d7f7c6dfae5d55d2f';
const R2_SECRET = process.env.R2_SECRET_ACCESS_KEY || '2e8f1e5f6c8c5f8e5f8e5f8e5f8e5f8e';
const R2_BUCKET = 'groove-ai-videos';
const SUPABASE_URL = 'https://tfbcdcrlhsxvlufmnzdr.supabase.co';
const SUPABASE_KEY = 'sb_publishable_z6cUnoxTW8LozDQZ5Bfmgg_zIr80-H4';

const VIDEOS = [
  { name: 'woman-big-guy', filePath: '/tmp/woman-big-guy.mp4' },
];

// Create R2 client
const client = new S3Client({
  region: 'auto',
  endpoint: `https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: R2_ACCESS_KEY,
    secretAccessKey: R2_SECRET,
  },
});

// Upload to R2 using AWS SDK
async function uploadToR2(filePath, fileName) {
  console.log(`[R2 upload] ${fileName}`);
  console.log(`[R2] File: ${filePath}`);
  
  if (!fs.existsSync(filePath)) {
    throw new Error(`File not found: ${filePath}`);
  }
  
  const fileContent = fs.readFileSync(filePath);
  console.log(`[R2] Size: ${fileContent.length} bytes`);
  
  const command = new PutObjectCommand({
    Bucket: R2_BUCKET,
    Key: `demos/${fileName}`,
    Body: fileContent,
    ContentType: 'video/mp4',
  });
  
  try {
    console.log(`[R2] Uploading...`);
    const response = await client.send(command);
    const publicUrl = `https://videos.trygrooveai.com/demos/${fileName}`;
    console.log(`✅ Uploaded: ${publicUrl}`);
    console.log(`[R2] ETag: ${response.ETag}`);
    return publicUrl;
  } catch (err) {
    console.error(`[R2] Upload error:`, err.message);
    throw err;
  }
}

// Verify file exists on R2
async function verifyR2(r2Url) {
  console.log(`[verify] Checking: ${r2Url}`);
  
  return new Promise((resolve, reject) => {
    const https = require('https');
    const req = https.request(r2Url, { method: 'HEAD' }, (res) => {
      console.log(`[verify] Status: ${res.statusCode}`);
      if (res.statusCode === 200 || res.statusCode === 302) {
        console.log(`✅ Verified on R2`);
        resolve();
      } else {
        reject(new Error(`Verification failed: HTTP ${res.statusCode}`));
      }
    });
    req.on('error', reject);
    req.end();
  });
}

// Update Supabase
async function updateSupabase(videoName, r2Url) {
  console.log(`[supabase] Updating ${videoName}`);
  
  const encodedName = encodeURIComponent(videoName);
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/demo_videos?name=eq.${encodedName}`,
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
  
  const body = await res.json();
  console.log(`[supabase] Status: ${res.status}`);
  
  if (!res.ok) {
    console.warn(`⚠️  Response:`, body);
    return;
  }
  
  console.log(`✅ Supabase updated`);
}

// Main
(async () => {
  console.log('\n🎬 UPLOAD VIDEOS WITH AWS SDK\n');
  console.log(`R2 Account: ${R2_ACCOUNT_ID}`);
  console.log(`R2 Bucket: ${R2_BUCKET}\n`);
  
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
      console.log(`✅ SUCCESS\n`);
      
    } catch (err) {
      console.error(`❌ FAILED: ${err.message}\n`);
      results[video.name] = { status: 'failed', error: err.message };
    }
  }
  
  // Summary
  console.log('\n' + '='.repeat(60));
  console.log('SUMMARY');
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
})();
