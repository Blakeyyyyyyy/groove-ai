import Foundation
import SwiftData
import UserNotifications

@Observable
final class GenerationService {
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

        // BUG-004 fix: state-driven generation flow
        appState.startGeneration(jobId: video.id)

        // TODO: Real backend flow:
        // 1. Upload photo to R2 (presigned URL)
        // 2. POST to /api/generate with photo_url + dance_preset_id
        // 3. Start polling /api/status/{video_id}

        // Simulated completion after 10 minutes (replace with real polling)
        startPolling(appState: appState, videoID: video.id, modelContext: modelContext)
    }

    /// Poll for completion (replace with real Supabase polling)
    private func startPolling(appState: AppState, videoID: String, modelContext: ModelContext) {
        Task { @MainActor in
            // In production: poll /api/status/{videoID} every 30s
            // For demo: wait 10 minutes then complete
            try? await Task.sleep(for: .seconds(600))

            guard appState.isGenerating else { return }
            completeGeneration(appState: appState, videoID: videoID, modelContext: modelContext)
        }
    }

    @MainActor
    func completeGeneration(appState: AppState, videoID: String, modelContext: ModelContext) {
        appState.completeGeneration(videoID: videoID)

        // Update video record
        let descriptor = FetchDescriptor<GeneratedVideo>(
            predicate: #Predicate { $0.id == videoID }
        )
        if let video = try? modelContext.fetch(descriptor).first {
            video.status = "completed"
            video.completedAt = .now
            try? modelContext.save()
        }

        // Send local notification
        sendCompletionNotification()

        // Auto-reset to idle after a brief delay (so UI can show success)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            appState.resetGeneration()
        }
    }

    @MainActor
    func handleGenerationFailure(appState: AppState) {
        appState.failGeneration(message: "Something went wrong — coins refunded. Tap to retry.")
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
