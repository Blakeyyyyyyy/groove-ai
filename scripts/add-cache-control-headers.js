import { S3Client, ListObjectsV2Command, CopyObjectCommand } from "@aws-sdk/client-s3";

const s3 = new S3Client({
  region: "auto",
  credentials: {
    accessKeyId: process.env.R2_ACCESS_KEY_ID,
    secretAccessKey: process.env.R2_SECRET_ACCESS_KEY,
  },
  endpoint: `https://${process.env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
});

const BUCKET = "groove-ai-videos";

async function main() {
  console.log("📁 Listing objects in presets/ folder...\n");

  const listCommand = new ListObjectsV2Command({
    Bucket: BUCKET,
    Prefix: "presets/",
  });

  const listResult = await s3.send(listCommand);
  
  if (!listResult.Contents || listResult.Contents.length === 0) {
    console.log("No objects found in presets/ folder.");
    return;
  }

  console.log(`Found ${listResult.Contents.length} objects.\n`);

  let successCount = 0;
  let errorCount = 0;

  for (const obj of listResult.Contents) {
    const key = obj.Key;
    
    // Skip directories
    if (key.endsWith("/")) {
      console.log(`⏭️ ${key} (directory, skipping)`);
      continue;
    }

    try {
      // Copy in-place with new headers
      const copyCommand = new CopyObjectCommand({
        Bucket: BUCKET,
        CopySource: encodeURIComponent(`${BUCKET}/${key}`),
        Key: key,
        ContentType: "video/mp4",
        CacheControl: "public, max-age=31536000",
        MetadataDirective: "REPLACE",
      });

      await s3.send(copyCommand);
      console.log(`✅ ${key} — Cache-Control header added`);
      successCount++;
    } catch (err) {
      console.log(`❌ ${key} — ${err.message}`);
      errorCount++;
    }
  }

  console.log(`\n✅ Complete. ${successCount} videos updated.`);
  if (errorCount > 0) {
    console.log(`❌ ${errorCount} errors.`);
  }
}

main().catch(console.error);