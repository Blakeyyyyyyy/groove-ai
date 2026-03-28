import Foundation
import SwiftData
import UserNotifications

@Observable
final class GenerationService {

    /// Active generation task — retained to prevent premature cancellation
    private var activeTask: Task<Void, Never>?

    /// Start a generation from the UI layer.
    /// Creates the local record on MainActor, then kicks off background work.
    /// The modelContext work is done on MainActor to avoid SwiftData threading issues.
    @MainActor
    func startGeneration(
        preset: DancePreset,
        photoData: Data,
        appState: AppState,
        modelContext: ModelContext
    ) {
        print("[Generation] ▶️ startGeneration called for preset: \(preset.id) (\(preset.name))")
        print("[Generation] 📸 Photo data size: \(photoData.count) bytes")

        // Create local video record ON MAIN ACTOR (SwiftData requirement)
        let video = GeneratedVideo(
            dancePresetID: preset.id,
            danceName: preset.name,
            photoData: photoData,
            status: "generating"
        )
        modelContext.insert(video)
        do {
            try modelContext.save()
            print("[Generation] 💾 Local video record saved: \(video.id)")
        } catch {
            print("[Generation] ❌ Failed to save local record: \(error)")
        }

        // Update generation state
        appState.startGeneration(jobId: video.id)
        print("[Generation] 🔄 Generation phase set to .generating")

        let videoId = video.id
        let userId = appState.userId ?? "anonymous"
        print("[Generation] 👤 Using userId: \(userId)")

        // Launch background generation task — retained so it survives view dismissal
        activeTask = Task.detached { [weak self] in
            await self?.runGenerationPipeline(
                videoId: videoId,
                preset: preset,
                photoData: photoData,
                userId: userId,
                appState: appState,
                modelContext: modelContext
            )
        }
    }

    /// The actual generation pipeline — runs in background.
    /// All ModelContext writes go through MainActor.
    private func runGenerationPipeline(
        videoId: String,
        preset: DancePreset,
        photoData: Data,
        userId: String,
        appState: AppState,
        modelContext: ModelContext
    ) async {
        do {
            // ── Step 1: Upload photo to R2 ──
            print("[Generation] ☁️ Step 1: Uploading photo to R2...")
            let imageURL = try await R2Service.shared.uploadPhoto(
                data: photoData,
                userId: userId
            )
            print("[Generation] ✅ Photo uploaded to R2: \(imageURL)")

            // ── Step 2: Classify image ──
            print("[Generation] 🔍 Step 2: Classifying image...")
            let classification = try await SupabaseService.shared.classifyImage(imageURL: imageURL)
            let subjectType = classification["subject_type"] as? String ?? "HUMAN"
            print("[Generation] ✅ Image classified as: \(subjectType) (raw: \(classification))")

            // ── Step 3: Generate video via backend ──
            print("[Generation] 🎬 Step 3: Requesting video generation...")
            print("[Generation]    → userId: \(userId)")
            print("[Generation]    → imageURL: \(imageURL)")
            print("[Generation]    → danceStyle: \(preset.id)")
            print("[Generation]    → subjectType: \(subjectType)")

            let response = try await SupabaseService.shared.generateVideo(
                userId: userId,
                imageURL: imageURL,
                danceStyle: preset.id,
                subjectType: subjectType
            )
            print("[Generation] ✅ Backend response: \(response)")

            guard let taskId = response["task_id"] as? String ?? response["taskId"] as? String else {
                let errorMsg = response["error"] as? String ?? "No task_id in response"
                print("[Generation] ❌ No task_id found. Full response: \(response)")
                throw GenerationError.serverError(errorMsg)
            }
            print("[Generation] 🎫 Task ID received: \(taskId)")

            // Update coins from server response
            if let remaining = response["coins_remaining"] as? Int ?? response["coinsRemaining"] as? Int {
                await MainActor.run {
                    appState.serverCoins = remaining
                    print("[Generation] 🪙 Coins remaining: \(remaining)")
                }
            }

            // ── Step 4: Poll for completion ──
            print("[Generation] ⏳ Step 4: Starting polling for taskId: \(taskId)...")
            let videoUrl = try await KlingService.shared.pollForCompletion(
                taskId: taskId,
                onStatusUpdate: { status in
                    print("[Generation] 📊 Poll status update: \(status)")
                }
            )
            print("[Generation] ✅ Video generation complete! URL: \(videoUrl)")

            // ── Step 5: Save to backend ──
            print("[Generation] 💾 Step 5: Saving video to backend...")
            _ = try? await SupabaseService.shared.saveVideo(videoId: taskId, videoURL: videoUrl)

            // ── Step 6: Update local record on MainActor ──
            await MainActor.run {
                // Fetch the video from context to update it
                let descriptor = FetchDescriptor<GeneratedVideo>(
                    predicate: #Predicate { $0.id == videoId }
                )
                if let video = try? modelContext.fetch(descriptor).first {
                    video.status = "completed"
                    video.completedAt = .now
                    video.videoURL = videoUrl
                    try? modelContext.save()
                    print("[Generation] ✅ Local record updated to completed")
                } else {
                    print("[Generation] ⚠️ Could not find local video record to update")
                }
                appState.completeGeneration(videoID: videoId)
                print("[Generation] 🎉 Generation complete! Phase set to .complete")
            }

            sendCompletionNotification()

            // Auto-reset after brief delay
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run {
                appState.resetGeneration()
                print("[Generation] 🔄 Generation phase reset to .idle")
            }

        } catch is CancellationError {
            print("[Generation] ⚠️ Generation task was cancelled")
        } catch {
            print("[Generation] ❌ GENERATION FAILED: \(error)")
            print("[Generation] ❌ Error type: \(type(of: error))")
            print("[Generation] ❌ Localized: \(error.localizedDescription)")

            await MainActor.run {
                let descriptor = FetchDescriptor<GeneratedVideo>(
                    predicate: #Predicate { $0.id == videoId }
                )
                if let video = try? modelContext.fetch(descriptor).first {
                    video.status = "failed"
                    try? modelContext.save()
                }
                appState.failGeneration(message: error.localizedDescription)
                print("[Generation] 🔴 Generation phase set to .failed")
            }
        }
    }

    /// Cancel any active generation
    func cancelGeneration() {
        activeTask?.cancel()
        activeTask = nil
        print("[Generation] 🛑 Active generation task cancelled")
    }

    @MainActor
    func handleGenerationFailure(appState: AppState) {
        appState.failGeneration(message: "Something went wrong. Coins refunded. Tap to retry.")
    }

    private func sendCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Your video is ready 🔥"
        content.body = "Your video is ready and it's wild. Tap to watch."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "video-complete-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
        print("[Generation] 🔔 Completion notification scheduled")
    }
}

// MARK: - Errors

enum GenerationError: LocalizedError {
    case serverError(String)
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .serverError(let msg): return msg
        case .uploadFailed: return "Failed to upload your photo. Try again."
        }
    }
}
