import Foundation
import SwiftData
import UserNotifications

@Observable
final class GenerationService {
    private var pollingTimer: Timer?

    /// Start a generation: upload photo, trigger backend, start polling
    func startGeneration(
        preset: DancePreset,
        photoData: Data,
        appState: AppState,
        modelContext: ModelContext
    ) async {
        // Create video record
        let video = GeneratedVideo(
            dancePresetID: preset.id,
            danceName: preset.name,
            photoData: photoData,
            status: "generating"
        )
        modelContext.insert(video)
        try? modelContext.save()

        appState.generatingVideoID = video.id
        appState.isGenerating = true
        appState.generationFailed = false
        appState.minutesRemaining = 10

        // TODO: Real backend flow:
        // 1. Upload photo to R2 (presigned URL)
        // 2. POST to /api/generate with photo_url + dance_preset_id
        // 3. Start polling /api/status/{video_id}

        // Simulated countdown
        startCountdown(appState: appState, videoID: video.id, modelContext: modelContext)
    }

    /// Simulate countdown for demo (replace with real polling)
    private func startCountdown(appState: AppState, videoID: String, modelContext: ModelContext) {
        Task { @MainActor in
            for minute in stride(from: 9, through: 0, by: -1) {
                try? await Task.sleep(for: .seconds(60)) // Real: poll every 60s
                if !appState.isGenerating { return }
                appState.minutesRemaining = minute
            }

            // Complete
            completeGeneration(appState: appState, videoID: videoID, modelContext: modelContext)
        }
    }

    @MainActor
    func completeGeneration(appState: AppState, videoID: String, modelContext: ModelContext) {
        appState.isGenerating = false
        appState.generatingVideoID = nil

        // Update video record
        let descriptor = FetchDescriptor<GeneratedVideo>(
            predicate: #Predicate { $0.id == videoID }
        )
        if let video = try? modelContext.fetch(descriptor).first {
            video.status = "completed"
            video.completedAt = .now
            // video.videoURL = response.video_url // from backend
            try? modelContext.save()
        }

        // Send local notification
        sendCompletionNotification()
    }

    @MainActor
    func handleGenerationFailure(appState: AppState) {
        appState.generationFailed = true
        appState.refundCredits()
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
