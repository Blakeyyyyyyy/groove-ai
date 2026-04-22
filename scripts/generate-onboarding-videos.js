#!/usr/bin/env node

/**
 * Generate 5 onboarding demo videos using the app's existing backend pipeline
 * 
 * Pipeline:
 * 1. Load image file
 * 2. Call process-image (Gemini recognition for dog, upload to R2)
 * 3. Call generate-video (Kling generation)
 * 4. Poll for completion
 * 5. Done
 */

import fs from "fs"
import path from "path"
import { fileURLToPath } from "url"

const __dirname = path.dirname(fileURLToPath(import.meta.url))

// Config
const RENDER_API_URL = "https://groove-ai-backend-1.onrender.com/api"
const USER_ID = "004906EC-5623-4616-B483-D0C33C2A23C2"

const videos = [
  { imageFile: "Gemini_Generated_Image_1555co1555co1555.png", dancePreset: "big-guy", subjectType: "dog", outputName: "golden-retriever-big-guy.mp4" },
  { imageFile: "Gemini_Generated_Image_1555co1555co1555.png", dancePreset: "coco-channel", subjectType: "dog", outputName: "golden-retriever-coco-channel.mp4" },
  { imageFile: "Gemini_Generated_Image_1555co1555co1555.png", dancePreset: "c-walk", subjectType: "dog", outputName: "golden-retriever-c-walk.mp4" },
  { imageFile: "06183b6c390a4741f1cdfa11a3f06e82.jpg", dancePreset: "big-guy", subjectType: "human", outputName: "woman-big-guy.mp4" },
  { imageFile: "06183b6c390a4741f1cdfa11a3f06e82.jpg", dancePreset: "coco-channel", subjectType: "human", outputName: "woman-coco-channel.mp4" },
]

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

async function generateVideo(imageUrl, dancePreset, subjectType) {
  console.log(`[generateVideo] Requesting Kling generation...`)

  const response = await fetch(`${RENDER_API_URL}/generate-video`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      user_id: USER_ID,
      image_url: imageUrl,
      dance_style: dancePreset,
      subject_type: subjectType,
    }),
  })

  const result = await response.json()
  if (!response.ok) {
    throw new Error(`generate-video failed: ${result.error || result.message || "unknown error"}`)
  }

  console.log(`[generateVideo] ✅ Task created. ID: ${result.task_id}`)
  return result
}

async function pollForCompletion(taskId) {
  console.log(`[polling] Starting poll for taskId: ${taskId}`)

  for (let i = 0; i < 120; i++) {
    const response = await fetch(`${RENDER_API_URL}/video-status/${taskId}`, {
      method: "GET",
      headers: {
        "Content-Type": "application/json",
      },
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
    await new Promise(resolve => setTimeout(resolve, 10000)) // 10 sec
  }

  throw new Error("Polling timeout (20 minutes)")
}

async function generateOne(imageFile, dancePreset, subjectType, outputName) {
  console.log(`\n━━━ Generating: ${outputName} ━━━`)

  try {
    // Step 1: Load image
    const imagePath = imageFile.startsWith("/") 
      ? imageFile 
      : imageFile.includes("06183b") 
        ? "/Users/blakeyyyclaw/.openclaw/workspace/memory/thumbnails/Blake reference/06183b6c390a4741f1cdfa11a3f06e82.jpg"
        : "/Users/blakeyyyclaw/.openclaw/workspace/groove-ai/Gemini_Generated_Image_1555co1555co1555.png"

    console.log(`[load] Reading: ${imagePath}`)
    const imageBuffer = fs.readFileSync(imagePath)
    console.log(`[load] ✅ Loaded: ${imageBuffer.length} bytes`)

    // Step 2: Process image (Gemini for dog, upload for all)
    const processResult = await processImage(imageBuffer)
    const imageUrl = processResult.image_url

    // Step 3: Generate video
    const genResult = await generateVideo(imageUrl, dancePreset, subjectType)
    const taskId = genResult.task_id

    // Step 4: Poll for completion
    const videoUrl = await pollForCompletion(taskId)

    console.log(`✅ SUCCESS: ${outputName}`)
    console.log(`   URL: ${videoUrl}`)
    return { success: true, videoUrl, outputName }
  } catch (error) {
    console.error(`❌ FAILED: ${outputName}`)
    console.error(`   Error: ${error.message}`)
    return { success: false, error: error.message, outputName }
  }
}

async function main() {
  console.log(`\n🎬 GROOVE AI ONBOARDING VIDEO GENERATION\n`)
  console.log(`Render API URL: ${RENDER_API_URL}`)
  console.log(`Total videos to generate: ${videos.length}\n`)

  const results = []

  for (const video of videos) {
    const result = await generateOne(video.imageFile, video.dancePreset, video.subjectType, video.outputName)
    results.push(result)

    // Wait 5 sec between requests to avoid rate limiting
    if (videos.indexOf(video) < videos.length - 1) {
      console.log(`\n⏳ Waiting 5 seconds before next generation...`)
      await new Promise(resolve => setTimeout(resolve, 5000))
    }
  }

  console.log(`\n\n━━━ FINAL RESULTS ━━━\n`)
  let successCount = 0
  results.forEach((r) => {
    if (r.success) {
      console.log(`✅ ${r.outputName}`)
      console.log(`   ${r.videoUrl}`)
      successCount++
    } else {
      console.log(`❌ ${r.outputName}`)
      console.log(`   ${r.error}`)
    }
  })

  console.log(`\n${successCount}/${results.length} videos generated successfully\n`)
  
  if (successCount === results.length) {
    console.log(`🎉 All videos ready for onboarding!\n`)
  }
}

main().catch(console.error)
