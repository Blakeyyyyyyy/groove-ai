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

        // Update generation state (pass photoData for generating pill thumbnail)
        appState.startGeneration(jobId: video.id, photoData: photoData)
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
            // ── Step 1: Process image (classify + upload in one call) ──
            print("[Generation] 🔄 Step 1: Processing image (classify + upload)...")
            let processResult = try await SupabaseService.shared.processImage(userId: userId, imageData: photoData)
            guard let imageURL = processResult["image_url"] as? String,
                  let subjectType = processResult["subject_type"] as? String else {
                throw GenerationError.serverError("processImage returned invalid data: \(processResult)")
            }
            let wasTransformed = Self.parseTransformedFlag(processResult["transformed"])
            print("[Generation] ✅ Image processed — URL: \(imageURL), type: \(subjectType), transformed: \(wasTransformed)")

            if subjectType != "HUMAN" && !wasTransformed {
                print("[Generation] ❌ Preprocessing incomplete for subjectType=\(subjectType). Refusing to call generate-video.")
                throw GenerationError.preprocessingRequired(subjectType: subjectType)
            }

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

            guard let taskId = Self.parseIdentifier(response["task_id"] ?? response["taskId"]) else {
                let errorMsg = response["error"] as? String ?? "No task_id in response"
                print("[Generation] ❌ No task_id found. Full response: \(response)")

                // Check if this is a pose/image recognition error
                let lowerError = errorMsg.lowercased()
                let isPoseError = lowerError.contains("upper body") ||
                                  lowerError.contains("image recognition") ||
                                  lowerError.contains("pose detect") ||
                                  lowerError.contains("no complete")
                await handleGenerationError(
                    errorMsg: errorMsg,
                    isPoseError: isPoseError,
                    appState: appState,
                    modelContext: modelContext,
                    videoId: videoId
                )
                return
            }
            guard let backendVideoId = Self.parseIdentifier(response["video_id"] ?? response["videoId"]) else {
                let errorMsg = response["error"] as? String ?? "No video_id in response"
                print("[Generation] ❌ No video_id found. Full response: \(response)")
                await handleGenerationError(
                    errorMsg: errorMsg,
                    isPoseError: false,
                    appState: appState,
                    modelContext: modelContext,
                    videoId: videoId
                )
                return
            }
            print("[Generation] 🎫 Task ID received: \(taskId)")
            print("[Generation] 🧾 Backend video ID received: \(backendVideoId)")

            // Update coins from server response
            if let remaining = response["coins_remaining"] as? Int ?? response["coinsRemaining"] as? Int {
                await MainActor.run {
                    appState.serverCoins = remaining
                    print("[Generation] 🪙 Coins remaining: \(remaining)")
                }
            }

            // ── Step 4: Poll for completion ──
            print("[Generation] ⏳ Step 4: Starting polling for taskId: \(taskId)...")
            do {
                let videoUrl = try await KlingService.shared.pollForCompletion(
                    taskId: taskId,
                    onStatusUpdate: { status in
                        print("[Generation] 📊 Poll status update: \(status)")
                    }
                )
                print("[Generation] ✅ Video generation complete! URL: \(videoUrl)")

                // ── Step 5: Save to backend ──
                print("[Generation] 💾 Step 5: Saving video to backend...")
                _ = try await SupabaseService.shared.saveVideo(videoId: backendVideoId, videoURL: videoUrl)

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

                    // Trigger rating prompt after 1st and 2nd generations
                    RatingPromptService.shared.didCompleteGeneration()
                }

                sendCompletionNotification()

                // Auto-reset after popup display time
                // (VideoReadyPopup auto-dismisses after 8s, so wait 10s)
                try? await Task.sleep(for: .seconds(10))
                await MainActor.run {
                    if appState.showVideoReadyPopup {
                        // Popup was not tapped — reset now
                        appState.resetGeneration()
                        print("[Generation] 🔄 Generation phase reset to .idle (auto)")
                    }
                }

            } catch {
                // Check if Kling returned a pose-related failure during polling
                let errorStr = error.localizedDescription.lowercased()
                let isPoseError = errorStr.contains("upper body") ||
                                  errorStr.contains("image recognition") ||
                                  errorStr.contains("pose detect") ||
                                  errorStr.contains("no complete") ||
                                  errorStr.contains("face-dance") ||
                                  errorStr.contains("no face")
                await handleGenerationError(
                    errorMsg: error.localizedDescription,
                    isPoseError: isPoseError,
                    appState: appState,
                    modelContext: modelContext,
                    videoId: videoId
                )
            }

        } catch is CancellationError {
            print("[Generation] ⚠️ Generation task was cancelled")
        } catch {
            print("[Generation] ❌ GENERATION FAILED: \(error)")
            print("[Generation] ❌ Error type: \(type(of: error))")
            print("[Generation] ❌ Localized: \(error.localizedDescription)")

            // Check if this is a pose detection error from process-image
            let errorStr = error.localizedDescription.lowercased()
            let isPoseError = errorStr.contains("upper body") ||
                              errorStr.contains("image recognition") ||
                              errorStr.contains("pose detect") ||
                              errorStr.contains("no complete") ||
                              errorStr.contains("transformation failed")

            await handleGenerationError(
                errorMsg: error.localizedDescription,
                isPoseError: isPoseError,
                appState: appState,
                modelContext: modelContext,
                videoId: videoId
            )
        }
    }

    /// Centralized error handler: shows in-app alert, sends local notification if backgrounded
    private func handleGenerationError(
        errorMsg: String,
        isPoseError: Bool,
        appState: AppState,
        modelContext: ModelContext,
        videoId: String
    ) async {
        print("[Generation] 🚨 Handling generation error: \(errorMsg) (poseError: \(isPoseError))")

        // Determine user-friendly message
        let userMessage: String
        let showRetryButton: Bool

        if isPoseError {
            userMessage = "Couldn't detect a pose in this image. Try a photo where your pet is standing clearly facing the camera."
            showRetryButton = true
        } else {
            userMessage = "Video generation failed: \(errorMsg). Your coins have been refunded."
            showRetryButton = false
        }

        // Update local video record
        await MainActor.run {
            let descriptor = FetchDescriptor<GeneratedVideo>(
                predicate: #Predicate { $0.id == videoId }
            )
            if let video = try? modelContext.fetch(descriptor).first {
                video.status = "failed"
                try? modelContext.save()
            }
            appState.errorAlertMessage = userMessage
            appState.errorAlertIsPoseIssue = showRetryButton
            appState.generationPhase = .failed(message: userMessage)
            print("[Generation] 🔴 Error alert shown, phase set to .failed")
        }

        // Send local notification if app is backgrounded
        if !appState.hasRequestedNotificationPermission {
            // Request permission first (non-blocking), then send notification
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                if granted {
                    self.sendErrorNotification(title: "Dance Generation Failed", body: "Try a clearer photo with your pet standing up")
                }
            }
            await MainActor.run {
                appState.hasRequestedNotificationPermission = true
            }
        } else {
            // Permission already granted
            sendErrorNotification(title: "Dance Generation Failed", body: "Try a clearer photo with your pet standing up")
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

    private func sendErrorNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "video-error-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
        print("[Generation] 🔔 Error notification scheduled: \(title)")
    }

    private static func parseIdentifier(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            return string
        case let int as Int:
            return String(int)
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    private static func parseTransformedFlag(_ value: Any?) -> Bool {
        switch value {
        case let bool as Bool:
            return bool
        case let int as Int:
            return int != 0
        case let number as NSNumber:
            return number.boolValue
        case let string as String:
            let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return normalized == "true" || normalized == "1" || normalized == "yes"
        default:
            return false
        }
    }
}

// MARK: - Errors

enum GenerationError: LocalizedError {
    case serverError(String)
    case uploadFailed
    case preprocessingRequired(subjectType: String)

    var errorDescription: String? {
        switch self {
        case .serverError(let msg): return msg
        case .uploadFailed: return "Failed to upload your photo. Try again."
        case .preprocessingRequired(let subjectType):
            return "The \(subjectType.lowercased()) photo could not be prepared for animation. Try a clearer, full-body image or retry in a moment."
        }
    }
}
