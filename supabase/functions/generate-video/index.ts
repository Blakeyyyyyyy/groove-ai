// Supabase Edge Function: generate-video
// Full generation flow: classify image, generate video, poll, save
// Deploy: supabase functions deploy generate-video --project-ref tfbcdcrlhsxvlufmnzdr

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { encode as base64Encode } from "https://deno.land/std@0.177.0/encoding/base64.ts";
import { HmacSha256 } from "https://deno.land/std@0.177.0/hash/sha256.ts";
import { S3Client, PutObjectCommand } from "https://esm.sh/@aws-sdk/client-s3@3.529.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// --- R2 Client ---
function getR2Client(): S3Client {
  const accountId = Deno.env.get("R2_ACCOUNT_ID")!;
  return new S3Client({
    region: "auto",
    endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
    credentials: {
      accessKeyId: Deno.env.get("R2_ACCESS_KEY_ID")!,
      secretAccessKey: Deno.env.get("R2_SECRET_ACCESS_KEY")!,
    },
  });
}

// --- Download video and upload to R2 ---
async function downloadAndUploadToR2(videoUrl: string, videoId: string): Promise<string> {
  console.log("[R2 Upload] Downloading video from:", videoUrl);
  
  // Download video from Kling
  const videoResponse = await fetch(videoUrl);
  if (!videoResponse.ok) {
    throw new Error(`Failed to download video: ${videoResponse.status}`);
  }
  const videoBuffer = await videoResponse.arrayBuffer();
  const videoBytes = new Uint8Array(videoBuffer);
  
  console.log("[R2 Upload] Video downloaded, size:", videoBytes.length, "bytes");
  
  const outputKey = `videos/${videoId}.mp4`;
  const r2 = getR2Client();
  const bucketName = Deno.env.get("R2_BUCKET_NAME_VIDEOS") || "groove-ai-videos";
  
  // Upload to R2 with proper caching headers
  await r2.send(new PutObjectCommand({
    Bucket: bucketName,
    Key: outputKey,
    Body: videoBytes,
    ContentType: "video/mp4",
    CacheControl: "public, max-age=31536000",
  }));
  
  const r2BaseUrl = `https://${Deno.env.get("R2_ACCOUNT_ID")}.r2.dev`;
  const finalUrl = `${r2BaseUrl}/${outputKey}`;
  
  console.log("[R2 Upload] Uploaded to R2:", finalUrl);
  return finalUrl;
}

// --- Kling JWT ---
function generateKlingJWT(): string {
  const ak = Deno.env.get("KLING_ACCESS_KEY")!;
  const sk = Deno.env.get("KLING_SECRET_KEY")!;

  const header = { alg: "HS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: ak,
    exp: now + 1800, // 30 min
    nbf: now - 5,
  };

  const encode = (obj: object) =>
    btoa(JSON.stringify(obj)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

  const headerB64 = encode(header);
  const payloadB64 = encode(payload);
  const signingInput = `${headerB64}.${payloadB64}`;

  // HMAC-SHA256
  const encoder = new TextEncoder();
  const keyData = encoder.encode(sk);
  const msgData = encoder.encode(signingInput);

  // Use Web Crypto for HMAC
  // Fallback: use a sync approach for Deno
  const hmac = new HmacSha256(sk);
  hmac.update(signingInput);
  const sig = hmac.hex();

  // Convert hex to base64url
  const sigBytes = new Uint8Array(sig.match(/.{2}/g)!.map((b: string) => parseInt(b, 16)));
  const sigB64 = btoa(String.fromCharCode(...sigBytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

  return `${headerB64}.${payloadB64}.${sigB64}`;
}

// --- Gemini Classification ---
async function classifyImage(imageUrl: string): Promise<string> {
  const apiKey = Deno.env.get("GEMINI_API_KEY")!;

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              {
                text: `Classify the main subject of this image. Respond with EXACTLY one word: HUMAN, PET, or BABY. 
                - HUMAN: adult or teenager
                - BABY: infant or toddler (under ~3 years old)
                - PET: any animal (dog, cat, etc.)
                Only respond with the single word classification.`,
              },
              {
                inline_data: {
                  mime_type: "image/jpeg",
                  data: await fetchImageAsBase64(imageUrl),
                },
              },
            ],
          },
        ],
      }),
    }
  );

  const data = await response.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text?.trim().toUpperCase() || "HUMAN";

  if (["HUMAN", "PET", "BABY"].includes(text)) return text;
  return "HUMAN"; // Default fallback
}

async function fetchImageAsBase64(url: string): Promise<string> {
  const response = await fetch(url);
  const buffer = await response.arrayBuffer();
  return btoa(String.fromCharCode(...new Uint8Array(buffer)));
}

// --- Kling Video Generation ---
async function createKlingVideo(
  imageUrl: string,
  prompt: string,
  subjectType: string
): Promise<string> {
  const jwt = generateKlingJWT();

  // Build prompt based on subject type
  let fullPrompt = prompt;
  if (subjectType === "PET") {
    fullPrompt = `Transform the animal in the image to stand upright on two legs like a human, then ${prompt}. The animal should move bipedally with human-like dance movements while retaining its animal appearance.`;
  } else if (subjectType === "BABY") {
    fullPrompt = `The baby/toddler in the image performs ${prompt}. Keep movements safe, cute, and playful. Gentle and adorable dance movements.`;
  }

  const response = await fetch("https://api.klingai.com/v1/videos/image2video", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${jwt}`,
    },
    body: JSON.stringify({
      model_name: "kling-v2",
      image: imageUrl,
      prompt: fullPrompt,
      duration: "5",
      cfg_scale: 0.5,
      mode: "std",
    }),
  });

  const data = await response.json();

  if (data.code !== 0) {
    throw new Error(`Kling API error: ${data.message || JSON.stringify(data)}`);
  }

  return data.data.task_id;
}

async function pollKlingStatus(taskId: string): Promise<{ status: string; videoUrl?: string }> {
  const jwt = generateKlingJWT();

  const response = await fetch(
    `https://api.klingai.com/v1/videos/image2video/${taskId}`,
    {
      headers: { Authorization: `Bearer ${jwt}` },
    }
  );

  const data = await response.json();
  const task = data.data;

  if (task.task_status === "succeed") {
    return {
      status: "completed",
      videoUrl: task.task_result?.videos?.[0]?.url,
    };
  } else if (task.task_status === "failed") {
    return { status: "failed" };
  }

  return { status: "processing" };
}

// --- Main Handler ---
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  try {
    // Auth
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Invalid token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { image_url, dance_style, dance_prompt } = await req.json();

    if (!image_url || !dance_style) {
      return new Response(JSON.stringify({ error: "Missing image_url or dance_style" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 1. Check rate limits
    const { data: rateResult, error: rateError } = await supabase.rpc("check_rate_limit", {
      p_user_id: user.id,
    });

    if (rateError) throw rateError;
    if (!rateResult.allowed) {
      return new Response(JSON.stringify({ error: rateResult.reason }), {
        status: 429,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Deduct credits (60 coins)
    const { data: deductResult, error: deductError } = await supabase.rpc("deduct_coins", {
      p_user_id: user.id,
      p_amount: 60,
    });

    if (deductError) throw deductError;
    if (!deductResult.success) {
      return new Response(JSON.stringify({ error: deductResult.error }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 3. Classify image with Gemini
    let subjectType = "HUMAN";
    try {
      subjectType = await classifyImage(image_url);
    } catch (e) {
      console.error("Gemini classification failed, defaulting to HUMAN:", e);
    }

    // 4. Create video record
    const { data: video, error: videoError } = await supabase
      .from("videos")
      .insert({
        user_id: user.id,
        video_url: "", // Will be updated on completion
        dance_style,
        subject_type: subjectType,
        status: "processing",
      })
      .select()
      .single();

    if (videoError) throw videoError;

    // 5. Start Kling generation
    let taskId: string;
    try {
      taskId = await createKlingVideo(image_url, dance_prompt || dance_style, subjectType);
    } catch (e) {
      // Refund on failure
      await supabase.rpc("refund_coins", { p_user_id: user.id, p_amount: 60, p_video_id: video.id });
      await supabase.from("videos").update({ status: "failed" }).eq("id", video.id);
      throw e;
    }

    // 6. Return immediately — client will poll for status
    // Store task_id in video record for polling
    await supabase
      .from("videos")
      .update({ video_url: `kling:${taskId}` }) // Temporary: store task ID
      .eq("id", video.id);

    // 7. Start background polling (Edge Function will poll and update)
    // Use Deno.spawn or EdgeRuntime.waitUntil for background work
    const pollAndComplete = async () => {
      const maxPolls = 40; // 40 * 15s = 10 minutes
      for (let i = 0; i < maxPolls; i++) {
        await new Promise((r) => setTimeout(r, 15000)); // 15s intervals

        try {
          const result = await pollKlingStatus(taskId);

          if (result.status === "completed" && result.videoUrl) {
            // Download video and upload to R2 for better streaming
            let finalVideoUrl = result.videoUrl;
            try {
              finalVideoUrl = await downloadAndUploadToR2(result.videoUrl, video.id);
            } catch (e) {
              console.error("[R2 Upload] Failed to upload to R2, using original URL:", e);
              // Fall back to original Kling URL
            }
            
            // Update video record with R2 URL
            await supabase
              .from("videos")
              .update({
                video_url: finalVideoUrl,
                status: "completed",
              })
              .eq("id", video.id);
            return;
          }

          if (result.status === "failed") {
            // Refund coins
            await supabase.rpc("refund_coins", {
              p_user_id: user.id,
              p_amount: 60,
              p_video_id: video.id,
            });
            await supabase.from("videos").update({ status: "failed" }).eq("id", video.id);
            return;
          }
        } catch (e) {
          console.error(`Poll attempt ${i + 1} failed:`, e);
        }
      }

      // Timeout — refund
      await supabase.rpc("refund_coins", {
        p_user_id: user.id,
        p_amount: 60,
        p_video_id: video.id,
      });
      await supabase.from("videos").update({ status: "failed" }).eq("id", video.id);
    };

    // Run polling in background (won't block response)
    // @ts-ignore — EdgeRuntime available in Supabase Edge Functions
    if (typeof EdgeRuntime !== "undefined" && EdgeRuntime.waitUntil) {
      EdgeRuntime.waitUntil(pollAndComplete());
    } else {
      // Fallback: fire and forget
      pollAndComplete().catch(console.error);
    }

    return new Response(
      JSON.stringify({
        success: true,
        video_id: video.id,
        subject_type: subjectType,
        coins_remaining: deductResult.coins_remaining,
        message: "Generation started. Poll /video-status for updates.",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    console.error("generate-video error:", err);
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
