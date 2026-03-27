import Foundation
import SwiftData
import UserNotifications

@Observable
final class GenerationService {

    /// Start a generation: upload photo to R2, trigger backend, poll for completion
    func startGeneration(
        preset: DancePreset,
        photoData: Data,
        appState: AppState,
        modelContext: ModelContext
    ) async {
        // Create local video record for UI
        let video = GeneratedVideo(
            dancePresetID: preset.id,
            danceName: preset.name,
            photoData: photoData,
            status: "generating"
        )
        modelContext.insert(video)
        try? modelContext.save()

        // State-driven generation flow
        appState.startGeneration(jobId: video.id)

        do {
            // 1. Upload photo to R2
            let imageURL = try await R2Service.shared.uploadPhoto(
                data: photoData,
                userId: appState.userId ?? "anonymous"
            )

            // 2. Trigger generation via Edge Function
            // Server handles: credit deduction, Gemini classification, Kling generation
            let response = try await SupabaseService.shared.generateVideo(
                imageURL: imageURL,
                danceStyle: preset.id,
                dancePrompt: preset.name
            )

            guard response.success, let serverVideoId = response.videoId else {
                throw GenerationError.serverError(response.error ?? "Unknown error")
            }

            // Update coins from server response
            if let remaining = response.coinsRemaining {
                await MainActor.run {
                    appState.serverCoins = remaining
                }
            }

            // 3. Poll for completion via Kling service
            let videoUrl = try await KlingService.shared.pollForCompletion(
                videoId: serverVideoId,
                onStatusUpdate: { status in
                    // Could update UI with status text
                }
            )

            // 4. Complete — update local record
            await MainActor.run {
                video.status = "completed"
                video.completedAt = .now
                video.videoURL = videoUrl
                try? modelContext.save()
                appState.completeGeneration(videoID: video.id)
            }

            sendCompletionNotification()

            // Auto-reset after brief delay
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run {
                appState.resetGeneration()
            }

        } catch is CancellationError {
            // Task cancelled — no action needed
        } catch {
            await MainActor.run {
                video.status = "failed"
                try? modelContext.save()
                appState.failGeneration(message: error.localizedDescription)
            }
        }
    }

    /// Fallback: simulated generation for development/testing
    func startSimulatedGeneration(
        preset: DancePreset,
        photoData: Data,
        appState: AppState,
        modelContext: ModelContext
    ) async {
        let video = GeneratedVideo(
            dancePresetID: preset.id,
            danceName: preset.name,
            photoData: photoData,
            status: "generating"
        )
        modelContext.insert(video)
        try? modelContext.save()

        appState.startGeneration(jobId: video.id)

        // Simulated 10-minute wait
        try? await Task.sleep(for: .seconds(600))

        guard appState.isGenerating else { return }

        await MainActor.run {
            video.status = "completed"
            video.completedAt = .now
            try? modelContext.save()
            appState.completeGeneration(videoID: video.id)
        }

        sendCompletionNotification()

        try? await Task.sleep(for: .seconds(3))
        await MainActor.run {
            appState.resetGeneration()
        }
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
