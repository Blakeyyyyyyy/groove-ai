import Foundation

/// Kling AI video generation service — client-side polling wrapper
/// Actual generation is triggered via the backend.
/// This service handles polling the video-status endpoint from the client.
final class KlingService {
    static let shared = KlingService()

    private let pollInterval: TimeInterval = 15 // seconds
    private let maxPollDuration: TimeInterval = 2100 // 35 minutes

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
        var consecutiveFailures = 0
        let maxConsecutiveFailures = 3

        #if DEBUG
        print("[Kling] ⏳ Starting poll for taskId: \(taskId) (interval: \(pollInterval)s, max: \(maxPollDuration)s)")
        #endif

        while true {
            // Check timeout
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > maxPollDuration {
                #if DEBUG
                print("[Kling] ❌ Polling timed out after \(Int(elapsed))s (\(pollCount) polls)")
                #endif
                throw KlingError.timeout
            }

            // Wait between polls
            try await Task.sleep(for: .seconds(pollInterval))
            pollCount += 1

            // Check status via backend — retry up to maxConsecutiveFailures for transient errors
            #if DEBUG
            print("[Kling] 📊 Poll #\(pollCount) (elapsed: \(Int(elapsed))s)...")
            #endif
            let statusDict: [String: Any]
            do {
                statusDict = try await SupabaseService.shared.checkVideoStatus(taskId: taskId)
                consecutiveFailures = 0
            } catch {
                consecutiveFailures += 1
                #if DEBUG
                print("[Kling] ⚠️ Poll #\(pollCount) error (\(consecutiveFailures)/\(maxConsecutiveFailures)): \(error.localizedDescription)")
                #endif
                if consecutiveFailures >= maxConsecutiveFailures {
                    throw error
                }
                continue
            }

            let status = statusDict["status"] as? String ?? "unknown"
            let videoUrl = statusDict["video_url"] as? String

            onStatusUpdate?(status)

            // Check for completion — Kling uses "succeed" not "completed"
            switch status {
            case "succeed", "completed", "success":
                guard let url = videoUrl, !url.isEmpty else {
                    #if DEBUG
                    print("[Kling] ❌ Status is \(status) but no video URL in response")
                    #endif
                    throw KlingError.noVideoURL
                }
                #if DEBUG
                print("[Kling] ✅ Generation complete after \(pollCount) polls (\(Int(elapsed))s). URL: \(url)")
                #endif
                return url

            case "failed", "error":
                #if DEBUG
                print("[Kling] ❌ Generation failed (server reported failure)")
                #endif
                throw KlingError.generationFailed

            case "processing", "pending", "submitted":
                #if DEBUG
                print("[Kling] ⏳ Status: \(status) — continuing to poll...")
                #endif
                continue

            default:
                #if DEBUG
                print("[Kling] ⚠️ Unknown status: \(status) — continuing to poll...")
                #endif
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
            return "There was an error processing your video. Please wait 5 minutes and try again."
        case .generationFailed:
            return "Video generation failed. Your coins have been refunded."
        case .noVideoURL:
            return "Video completed but no URL was returned."
        }
    }
}
