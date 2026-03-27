import Foundation
import CryptoKit

/// Cloudflare R2 storage service for uploading photos and serving videos
/// Uses S3-compatible API with presigned URLs
/// API keys are in Edge Functions — this service uses presigned URLs from backend
final class R2Service {
    static let shared = R2Service()

    // R2 public URLs (configured via Cloudflare dashboard)
    private let imagesBaseURL = "https://groove-ai-images.r2.dev"
    private let videosBaseURL = "https://groove-ai-videos.r2.dev"

    private init() {}

    // MARK: - Upload Photo via Supabase Edge Function

    /// Upload photo data to R2 via backend (keys stay server-side)
    func uploadPhoto(data: Data, userId: String, filename: String? = nil) async throws -> String {
        let name = filename ?? "\(UUID().uuidString).jpg"
        let path = "uploads/\(userId)/\(name)"

        // Upload via Supabase Edge Function that handles R2 auth
        let url = URL(string: "https://tfbcdcrlhsxvlufmnzdr.supabase.co/functions/v1/upload-image")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = KeychainHelper.get(key: "supabase_auth_token") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()

        // Path field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"path\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(path)\r\n".data(using: .utf8)!)

        // File field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(name)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw R2Error.uploadFailed
        }

        // Parse response for the public URL
        if let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
           let publicURL = json["url"] as? String {
            return publicURL
        }

        // Fallback: construct URL from path
        return "\(imagesBaseURL)/\(path)"
    }

    // MARK: - Public URLs

    func imageURL(path: String) -> URL? {
        URL(string: "\(imagesBaseURL)/\(path)")
    }

    func videoURL(path: String) -> URL? {
        URL(string: "\(videosBaseURL)/\(path)")
    }
}

// MARK: - Errors

enum R2Error: LocalizedError {
    case uploadFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .uploadFailed: return "Failed to upload image. Try again."
        case .invalidResponse: return "Invalid response from storage."
        }
    }
}
