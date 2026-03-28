import Foundation

/// Kling AI video generation service — client-side polling wrapper
/// Actual generation is triggered via the backend.
/// This service handles polling the video-status endpoint from the client.
final class KlingService {
    static let shared = KlingService()

    private let pollInterval: TimeInterval = 15 // seconds
    private let maxPollDuration: TimeInterval = 660 // 11 minutes (buffer over 10min generation)

    private init() {}

    // MARK: - Poll for Completion

    /// Poll video status until completed, failed, or timeout
    /// Returns the final video URL on success
    func pollForCompletion(
        taskId: String,
        onStatusUpdate: ((String) -> Void)? = nil
    ) async throws -> String {
        let startTime = Date()
        var pollCount = 0

        print("[Kling] ⏳ Starting poll for taskId: \(taskId) (interval: \(pollInterval)s, max: \(maxPollDuration)s)")

        while true {
            // Check timeout
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > maxPollDuration {
                print("[Kling] ❌ Polling timed out after \(Int(elapsed))s (\(pollCount) polls)")
                throw KlingError.timeout
            }

            // Wait between polls
            try await Task.sleep(for: .seconds(pollInterval))
            pollCount += 1

            // Check status via backend
            print("[Kling] 📊 Poll #\(pollCount) (elapsed: \(Int(elapsed))s)...")
            let statusDict = try await SupabaseService.shared.checkVideoStatus(taskId: taskId)
            let status = statusDict["status"] as? String ?? "unknown"
            let videoUrl = statusDict["video_url"] as? String

            onStatusUpdate?(status)

            switch status {
            case "completed":
                guard let url = videoUrl, !url.isEmpty else {
                    print("[Kling] ❌ Status is completed but no video URL in response")
                    throw KlingError.noVideoURL
                }
                print("[Kling] ✅ Generation complete after \(pollCount) polls (\(Int(elapsed))s). URL: \(url)")
                return url

            case "failed":
                print("[Kling] ❌ Generation failed (server reported failure)")
                throw KlingError.generationFailed

            case "processing", "pending":
                print("[Kling] ⏳ Status: \(status) — continuing to poll...")
                continue

            default:
                print("[Kling] ⚠️ Unknown status: \(status) — continuing to poll...")
                continue
            }
        }
    }
}

// MARK: - Errors

enum KlingError: LocalizedError {
    case timeout
    case generationFailed
    case noVideoURL

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Video generation timed out. Your coins have been refunded."
        case .generationFailed:
            return "Video generation failed. Your coins have been refunded."
        case .noVideoURL:
            return "Video completed but no URL was returned."
        }
    }
}
