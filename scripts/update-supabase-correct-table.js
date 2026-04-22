const SUPABASE_URL = 'https://tfbcdcrlhsxvlufmnzdr.supabase.co';
const SUPABASE_KEY = 'sb_publishable_z6cUnoxTW8LozDQZ5Bfmgg_zIr80-H4';

const VIDEOS = [
  { name: 'woman-big-guy', url: 'https://videos.trygrooveai.com/demos/woman-big-guy.mp4' },
  { name: 'woman-coco-channel', url: 'https://videos.trygrooveai.com/demos/woman-coco-channel.mp4' },
];

async function updateSupabase(videoName, videoUrl) {
  console.log(`\n[supabase] Updating videos table: ${videoName}`);
  console.log(`URL: ${videoUrl}`);
  
  // Try different query patterns
  const queries = [
    `videos?name=eq.${encodeURIComponent(videoName)}`,
    `videos?title=eq.${encodeURIComponent(videoName)}`,
    `videos?video_name=eq.${encodeURIComponent(videoName)}`,
  ];
  
  for (const query of queries) {
    try {
      console.log(`Trying: /rest/v1/${query}`);
      
      const res = await fetch(`${SUPABASE_URL}/rest/v1/${query}`, {
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${SUPABASE_KEY}`,
          'apikey': SUPABASE_KEY,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          video_url: videoUrl,
          status: 'completed',
        }),
      });
      
      console.log(`Status: ${res.status}`);
      const body = await res.json();
      
      if (res.ok) {
        console.log(`✅ Updated`);
        return true;
      } else if (res.status !== 404) {
        console.log(`Error:`, body);
        return false;
      }
      // 404 means wrong column, try next
    } catch (err) {
      console.log(`Failed: ${err.message}`);
    }
  }
  
  return false;
}

// First, let's get the table schema
async function getTableSchema() {
  console.log('\n[schema] Fetching table structure...\n');
  
  try {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/videos?limit=0`, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${SUPABASE_KEY}`,
        'apikey': SUPABASE_KEY,
      },
    });
    
    const headers = Object.fromEntries(res.headers);
    const schema = headers['content-profile'] || 'unknown';
    
    console.log(`Response headers:`, JSON.stringify(Object.fromEntries(res.headers), null, 2));
    
    const body = await res.text();
    console.log(`Body:`, body);
    
  } catch (err) {
    console.error(`Error:`, err.message);
  }
}

// Main
(async () => {
  console.log('\n🎬 SUPABASE UPDATE TEST\n');
  console.log(`URL: ${SUPABASE_URL}`);
  console.log(`Key: ${SUPABASE_KEY.substring(0, 20)}...\n`);
  
  // First, check the schema
  await getTableSchema();
  
  // Then try updating
  for (const video of VIDEOS) {
    const success = await updateSupabase(video.name, video.url);
    if (success) {
      console.log(`✅ SUCCESS: ${video.name}\n`);
    } else {
      console.log(`❌ FAILED: ${video.name}\n`);
    }
  }
})();
