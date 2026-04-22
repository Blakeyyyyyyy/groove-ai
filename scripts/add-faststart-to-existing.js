import { S3Client, ListObjectsV2Command, GetObjectCommand, PutObjectCommand } from "@aws-sdk/client-s3";
import { Readable } from "stream";
import { spawn } from "child_process";
import { writeFileSync, unlinkSync, createReadStream, existsSync } from "fs";
import { tmpdir } from "os";

const s3 = new S3Client({
  region: "auto",
  credentials: {
    accessKeyId: process.env.R2_ACCESS_KEY_ID,
    secretAccessKey: process.env.R2_SECRET_ACCESS_KEY,
  },
  endpoint: `https://${process.env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
});

const BUCKET = "groove-ai-videos";

// Helper: promisify ffmpeg
function runFFmpeg(inputPath, outputPath) {
  return new Promise((resolve, reject) => {
    const ffmpeg = spawn("ffmpeg", [
      "-i", inputPath,
      "-movflags", "faststart",
      "-vcodec", "copy",
      "-acodec", "copy",
      "-y", // overwrite output
      outputPath
    ]);

    let stderr = "";
    ffmpeg.stderr.on("data", (data) => {
      stderr += data.toString();
    });

    ffmpeg.on("close", (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`ffmpeg exited with code ${code}: ${stderr}`));
      }
    });

    ffmpeg.on("error", (err) => reject(err));
  });
}

// Helper: download from R2
async function downloadFromR2(key) {
  const command = new GetObjectCommand({
    Bucket: BUCKET,
    Key: key,
  });
  
  const response = await s3.send(command);
  const stream = response.Body;
  const chunks = [];
  
  for await (const chunk of stream) {
    chunks.push(chunk);
  }
  
  return Buffer.concat(chunks);
}

// Helper: upload to R2
async function uploadToR2(key, data, contentType = "video/mp4") {
  const command = new PutObjectCommand({
    Bucket: BUCKET,
    Key: key,
    Body: data,
    ContentType: contentType,
    CacheControl: "public, max-age=31536000",
  });
  
  await s3.send(command);
}

async function main() {
  console.log("📁 Listing videos in presets/ folder...\n");

  const listCommand = new ListObjectsV2Command({
    Bucket: BUCKET,
    Prefix: "presets/",
  });

  const listResult = await s3.send(listCommand);
  
  if (!listResult.Contents || listResult.Contents.length === 0) {
    console.log("No videos found in presets/ folder.");
    return;
  }

  const videos = listResult.Contents.filter(obj => !obj.Key.endsWith("/") && obj.Key.endsWith(".mp4"));
  console.log(`Found ${videos.length} videos.\n`);

  let successCount = 0;
  let errorCount = 0;

  for (const obj of videos) {
    const key = obj.Key;
    const filename = key.split("/").pop();
    
    try {
      console.log(`⬇️ Downloading ${filename}...`);
      const videoData = await downloadFromR2(key);
      
      // Write temp file
      const tempInput = `${tmpdir()}/faststart-input-${Date.now()}.mp4`;
      const tempOutput = `${tmpdir()}/faststart-output-${Date.now()}.mp4`;
      
      writeFileSync(tempInput, videoData);
      
      console.log(`⚙️ Re-encoding with faststart...`);
      await runFFmpeg(tempInput, tempOutput);
      
      // Read re-encoded file
      const reencodedData = createReadStream(tempOutput);
      const chunks = [];
      for await (const chunk of reencodedData) {
        chunks.push(chunk);
      }
      const finalData = Buffer.concat(chunks);
      
      console.log(`⬆️ Uploading ${filename}...`);
      await uploadToR2(key, finalData);
      
      // Cleanup
      unlinkSync(tempInput);
      unlinkSync(tempOutput);
      
      console.log(`✅ ${filename} — faststart added\n`);
      successCount++;
    } catch (err) {
      console.log(`❌ ${filename} — ${err.message}\n`);
      errorCount++;
    }
  }

  console.log(`\n✅ Complete. ${successCount} videos re-encoded with faststart.`);
  if (errorCount > 0) {
    console.log(`❌ ${errorCount} errors.`);
  }
}

main().catch(console.error);