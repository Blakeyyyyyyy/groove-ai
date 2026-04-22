#!/usr/bin/env node

/**
 * GROOVE AI - Regenerate & Upload Demo Videos
 * 
 * Complete pipeline:
 * 1. Regenerates all 5 demo videos through Render backend (Kling)
 * 2. IMMEDIATELY downloads each video while tokens are fresh
 * 3. IMMEDIATELY re-encodes with faststart
 * 4. Uploads to R2 with Cache-Control header
 * 5. Updates DancePreset.swift with R2 URLs
 * 
 * IMPORTANT: Synchronous - no time gap between generation and download
 */

import fs from "fs"
import path from "path"
import { fileURLToPath } from "url"
import { spawn } from "child_process"

const __dirname = path.dirname(fileURLToPath(import.meta.url))

// Config
const RENDER_API_URL = "https://groove-ai-backend-1.onrender.com/api"
const USER_ID = "004906EC-5623-4616-B483-D0C33C2A23C2"
const R2_BUCKET = "groove-ai-videos"
const R2_FOLDER = "demos"
const TEMP_DIR = "/tmp/groove-demos"

// Video configurations
const videos = [
  { 
    imageFile: "Gemini_Generated_Image_1555co1555co1555.png", 
    dancePreset: "big-guy", 
    subjectType: "dog", 
    outputName: "golden-retriever-big-guy.mp4",
    presetId: "dog-big-guy"
  },
  { 
    imageFile: "Gemini_Generated_Image_1555co1555co1555.png", 
    dancePreset: "coco-channel", 
    subjectType: "dog", 
    outputName: "golden-retriever-coco-channel.mp4",
    presetId: "dog-coco-channel"
  },
  { 
    imageFile: "Gemini_Generated_Image_1555co1555co1555.png", 
    dancePreset: "c-walk", 
    subjectType: "dog", 
    outputName: "golden-retriever-c-walk.mp4",
    presetId: "dog-c-walk"
  },
  { 
    imageFile: "06183b6c390a4741f1cdfa11a3f06e82.jpg", 
    dancePreset: "big-guy", 
    subjectType: "human", 
    outputName: "woman-big-guy.mp4",
    presetId: "woman-big-guy"
  },
  { 
    imageFile: "06183b6c390a4741f1cdfa11a3f06e82.jpg", 
    dancePreset: "coco-channel", 
    subjectType: "human", 
    outputName: "woman-coco-channel.mp4",
    presetId: "woman-coco-channel"
  },
]

// Helper: Run command
function runCommand(cmd, args) {
  return new Promise((resolve, reject) => {
    const proc = spawn(cmd, args, { shell: true })
    let stdout = ""
    let stderr = ""
    
    proc.stdout.on("data", d => stdout += d)
    proc.stderr.on("data", d => stderr += d)
    
    proc.on("close", code => {
      if (code === 0) resolve(stdout)
      else reject(new Error(`${cmd} ${args.join(" ")} failed: ${stderr || stdout}`))
    })
    proc.on("error", reject)
  })
}

// Step 1: Process image (Gemini recognition + upload to R2)
async function processImage(imageBuffer) {
  console.log(`[processImage] Sending to Render backend...`)
  
  const formData = new FormData()
  formData.append("user_id", USER_ID)
  formData.append("image", new Blob([imageBuffer], { type: "image/jpeg" }), "photo.jpg")
  
  const response = await fetch(`${RENDER_API_URL}/process-image`, {
    method: "POST",
    body: formData,
  })

  const result = await response.json()
  if (!response.ok) {
    throw new Error(`process-image failed: ${result.error || result.message || "unknown error"}`)
  }

  console.log(`[processImage] ✅ Processed. URL: ${result.image_url}, Type: ${result.subject_type}`)
  return result
}

// Step 2: Generate video (Kling) with retry logic
async function generateVideo(imageUrl, dancePreset, subjectType, maxRetries = 5) {
  console.log(`[generateVideo] Requesting Kling generation...`)

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const response = await fetch(`${RENDER_API_URL}/generate-video`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          user_id: USER_ID,
          image_url: imageUrl,
          dance_style: dancePreset,
          subject_type: subjectType,
        }),
      })

      const result = await response.json()
      if (!response.ok) {
        if (result.error?.includes("Rate limit") && attempt < maxRetries) {
          const waitTime = 30 * attempt // 30, 60, 90, 120 seconds
          console.log(`[generateVideo] Rate limited. Waiting ${waitTime}s before retry (attempt ${attempt}/${maxRetries})...`)
          await new Promise(resolve => setTimeout(resolve, waitTime * 1000))
          continue
        }
        throw new Error(`generate-video failed: ${result.error || result.message || "unknown error"}`)
      }

      console.log(`[generateVideo] ✅ Task created. ID: ${result.task_id}`)
      return result
    } catch (err) {
      if (attempt === maxRetries) throw err
      const waitTime = 30 * attempt
      console.log(`[generateVideo] Error: ${err.message}. Retrying in ${waitTime}s...`)
      await new Promise(resolve => setTimeout(resolve, waitTime * 1000))
    }
  }
}

// Step 3: Poll for completion
async function pollForCompletion(taskId) {
  console.log(`[polling] Starting poll for taskId: ${taskId}`)

  for (let i = 0; i < 120; i++) {
    const response = await fetch(`${RENDER_API_URL}/video-status/${taskId}`, {
      method: "GET",
      headers: { "Content-Type": "application/json" },
    })

    const result = await response.json()
    const status = result.status

    if (status === "succeed" || status === "completed") {
      console.log(`[polling] ✅ Complete! Video URL: ${result.video_url}`)
      return result.video_url
    }

    if (status === "failed" || status === "error") {
      throw new Error(`Kling generation failed: ${result.error || "unknown error"}`)
    }

    console.log(`[polling] Status: ${status} (attempt ${i + 1}/120)`)
    await new Promise(resolve => setTimeout(resolve, 10000))
  }

  throw new Error("Polling timeout (20 minutes)")
}

// Step 4: Download video immediately
async function downloadVideo(videoUrl, outputPath) {
  console.log(`[download] Starting immediate download...`)
  
  const response = await fetch(videoUrl)
  if (!response.ok) {
    throw new Error(`Download failed: ${response.status} ${response.statusText}`)
  }

  const fileStream = fs.createWriteStream(outputPath)
  
  await new Promise((resolve, reject) => {
    response.body.pipeTo(new WritableStream({
      write(chunk) { fileStream.write(chunk) },
      close() { fileStream.end(); resolve() },
      error(err) { fileStream.end(); reject(err) }
    }))
  })

  const stats = fs.statSync(outputPath)
  console.log(`[download] ✅ Downloaded: ${outputPath} (${stats.size} bytes)`)
  return outputPath
}

// Step 5: Re-encode with faststart
async function addFaststart(inputPath) {
  const tempPath = inputPath + ".faststart.mp4"
  console.log(`[faststart] Re-encoding with faststart...`)
  
  // Use ffmpeg to add faststart atom
  await runCommand("ffmpeg", [
    "-y", // overwrite
    "-i", inputPath,
    "-c", "copy",
    "-movflags", "+faststart",
    "-f", "mp4",
    tempPath
  ])
  
  // Replace original with faststart version
  fs.unlinkSync(inputPath)
  fs.renameSync(tempPath, inputPath)
  
  const stats = fs.statSync(inputPath)
  console.log(`[faststart] ✅ Faststart added: ${inputPath} (${stats.size} bytes)`)
  return inputPath
}

// Step 6: Upload to R2 via Render backend (fetches from Kling URL)
async function uploadToR2(klingUrl, keyName) {
  console.log(`[upload] Uploading to R2: demos/${keyName}...`)
  
  const response = await fetch(`${RENDER_API_URL}/upload-demo-video`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      video_url: klingUrl,
      key_name: keyName,
      content_type: "video/mp4"
    }),
  })

  const result = await response.json()
  if (!response.ok) {
    throw new Error(`Upload failed: ${result.error || result.message || "unknown error"}`)
  }

  console.log(`[upload] ✅ Uploaded: ${result.video_url}`)
  return result.video_url
}

// Generate one complete video
async function generateOne(video) {
  const { imageFile, dancePreset, subjectType, outputName, presetId } = video
  
  console.log(`\n${"═".repeat(50)}`)
  console.log(`🎬 Generating: ${outputName}`)
  console.log(`   Preset: ${dancePreset} | Subject: ${subjectType}`)
  console.log("═".repeat(50))

  try {
    // 1. Load image
    const imagePath = imageFile.includes("06183b")
      ? "/Users/blakeyyyclaw/.openclaw/workspace/memory/thumbnails/Blake reference/06183b6c390a4741f1cdfa11a3f06e82.jpg"
      : "/Users/blakeyyyclaw/.openclaw/workspace/groove-ai/Gemini_Generated_Image_1555co1555co1555.png"

    console.log(`[load] Reading: ${imagePath}`)
    const imageBuffer = fs.readFileSync(imagePath)
    console.log(`[load] ✅ Loaded: ${imageBuffer.length} bytes`)

    // 2. Process image (Gemini for dog, upload for all)
    const processResult = await processImage(imageBuffer)
    const imageUrl = processResult.image_url

    // 3. Generate video
    const genResult = await generateVideo(imageUrl, dancePreset, subjectType)
    const taskId = genResult.task_id

    // 4. Poll for completion
    const videoUrl = await pollForCompletion(taskId)

    // 5. Download IMMEDIATELY while tokens are fresh
    const downloadPath = path.join(TEMP_DIR, outputName)
    console.log(`[download] Path: ${downloadPath}`)
    await downloadVideo(videoUrl, downloadPath)
    
    // Verify download
    const stats = fs.statSync(downloadPath)
    if (stats.size === 0) throw new Error("Downloaded file is empty!")
    console.log(`[download] Verified: ${stats.size} bytes`)

    // 6. Add faststart encoding
    await addFaststart(downloadPath)

    // 7. Upload to R2 (passing Kling URL so Render can fetch it)
    const r2Url = await uploadToR2(videoUrl, outputName)

    console.log(`\n✅ SUCCESS: ${outputName}`)
    console.log(`   R2 URL: ${r2Url}`)
    
    return { success: true, outputName, presetId, r2Url }
  } catch (error) {
    console.error(`\n❌ FAILED: ${outputName}`)
    console.error(`   Error: ${error.message}`)
    return { success: false, outputName, presetId, error: error.message }
  }
}

// Update DancePreset.swift with R2 URLs
function updateDancePreset(results) {
  const swiftPath = "/Users/blakeyyyclaw/.openclaw/workspace/groove-ai/GrooveAI/Models/DancePreset.swift"
  let content = fs.readFileSync(swiftPath, "utf8")
  
  // Build the new mappings
  const dogDemoSection = results
    .filter(r => r.success && r.presetId.startsWith("dog-"))
    .map(r => {
      const preset = r.presetId.replace("dog-", "")
      return `        "${preset}": "${r.r2Url}"`
    })
    .join(",\n")
  
  const womanDemoSection = results
    .filter(r => r.success && r.presetId.startsWith("woman-"))
    .map(r => {
      const preset = r.presetId.replace("woman-", "")
      return `        "${preset}": "${r.r2Url}"`
    })
    .join(",\n")

  // Find and replace dogDemoVideos
  const dogPattern = /static let dogDemoVideos: \[String: String\] = \[[\s\S]*?\]/
  const newDogSection = `static let dogDemoVideos: [String: String] = [
${dogDemoSection}
    ]`
  content = content.replace(dogPattern, newDogSection)

  // Find and replace womanDemoVideos
  const womanPattern = /static let womanDemoVideos: \[String: String\] = \[[\s\S]*?\]/
  const newWomanSection = `static let womanDemoVideos: [String: String] = [
${womanDemoSection}
    ]`
  content = content.replace(womanPattern, newWomanSection)

  fs.writeFileSync(swiftPath, content)
  console.log(`\n[update] ✅ DancePreset.swift updated with R2 URLs`)
}

// Main
async function main() {
  console.log(`\n🎬 GROOVE AI - REGENERATE & UPLOAD DEMO VIDEOS`)
  console.log(`═══════════════════════════════════════════════════\n`)
  console.log(`Render API: ${RENDER_API_URL}`)
  console.log(`R2 Bucket: ${R2_BUCKET}`)
  console.log(`R2 Folder: ${R2_FOLDER}`)
  console.log(`Total videos: ${videos.length}\n`)

  // Ensure temp dir
  if (!fs.existsSync(TEMP_DIR)) {
    fs.mkdirSync(TEMP_DIR, { recursive: true })
  }

  const results = []

  for (const video of videos) {
    const result = await generateOne(video)
    results.push(result)

    // Wait 5 sec between requests to avoid rate limiting
    if (videos.indexOf(video) < videos.length - 1) {
      console.log(`\n⏳ Waiting 5 seconds before next generation...`)
      await new Promise(resolve => setTimeout(resolve, 5000))
    }
  }

  // Summary
  console.log(`\n\n${"═".repeat(50)}`)
  console.log(`📊 FINAL RESULTS`)
  console.log("═".repeat(50))

  let successCount = 0
  results.forEach(r => {
    if (r.success) {
      console.log(`✅ ${r.outputName}`)
      console.log(`   ${r.r2Url}`)
      successCount++
    } else {
      console.log(`❌ ${r.outputName}`)
      console.log(`   ${r.error}`)
    }
  })

  console.log(`\n${successCount}/${results.length} videos processed successfully\n`)

  if (successCount > 0) {
    // Update DancePreset.swift
    updateDancePreset(results)
    
    // Print mapping
    console.log(`\n📱 DANCEPRESET.M SWIFT MAPPING:\n`)
    console.log(`// Dog Demo Videos`)
    console.log(`static let dogDemoVideos: [String: String] = [`)
    results.filter(r => r.success && r.presetId.startsWith("dog-")).forEach(r => {
      const preset = r.presetId.replace("dog-", "")
      console.log(`    "${preset}": "${r.r2Url}",`)
    })
    console.log(`]\n`)
    
    console.log(`// Woman Demo Videos`)
    console.log(`static let womanDemoVideos: [String: String] = [`)
    results.filter(r => r.success && r.presetId.startsWith("woman-")).forEach(r => {
      const preset = r.presetId.replace("woman-", "")
      console.log(`    "${preset}": "${r.r2Url}",`)
    })
    console.log(`]`)
  }

  if (successCount === results.length) {
    console.log(`\n🎉 ALL 5 DEMO VIDEOS READY!\n`)
  }

  process.exit(successCount === results.length ? 0 : 1)
}

main().catch(err => {
  console.error("Fatal error:", err)
  process.exit(1)
})