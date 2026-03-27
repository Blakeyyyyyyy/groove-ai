import Foundation

/// Kling AI video generation service — client-side polling wrapper
/// Actual generation is triggered by the generate-video Edge Function.
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
        videoId: String,
        onStatusUpdate: ((String) -> Void)? = nil
    ) async throws -> String {
        let startTime = Date()

        while true {
            // Check timeout
            if Date().timeIntervalSince(startTime) > maxPollDuration {
                throw KlingError.timeout
            }

            // Wait between polls
            try await Task.sleep(for: .seconds(pollInterval))

            // Check status
            let status = try await SupabaseService.shared.checkVideoStatus(videoId: videoId)
            onStatusUpdate?(status.status)

            switch status.status {
            case "completed":
                guard let videoUrl = status.videoUrl, !videoUrl.isEmpty else {
                    throw KlingError.noVideoURL
                }
                return videoUrl

            case "failed":
                throw KlingError.generationFailed

            case "processing", "pending":
                continue

            default:
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
