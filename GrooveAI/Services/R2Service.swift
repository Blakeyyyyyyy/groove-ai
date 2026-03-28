import Foundation
import CryptoKit

/// Cloudflare R2 storage service
/// Now uses Render backend for presigned URLs - keys stay server-side
final class R2Service {
    static let shared = R2Service()

    // R2 public URLs (via R2's native public URL format)
    private let baseURL = "https://groove-ai-backend-1.onrender.com/api"

    private init() {}

    // MARK: - Upload via Backend Presigned URL

    /// Upload photo to R2 - backend provides presigned URL
    func uploadPhoto(data: Data, userId: String, filename: String? = nil) async throws -> String {
        let name = filename ?? "\(UUID().uuidString).jpg"
        
        // Get presigned URL from backend
        let presignedResponse = try await SupabaseService.shared.uploadImage(userId: userId, filename: name, imageData: data)
        
        guard let uploadUrl = presignedResponse["uploadUrl"] as? String,
              let publicUrl = presignedResponse["publicUrl"] as? String else {
            throw NSError(domain: "R2Service", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to get presigned URL"])
        }
        
        // Upload directly to R2 using presigned URL
        var request = URLRequest(url: URL(string: uploadUrl)!)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "R2Service", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to upload to R2"])
        }
        
        return publicUrl
    }

    // MARK: - Get Presigned Upload URL Only

    /// Get just the presigned URL (for direct upload from iOS)
    func getPresignedUploadURL(userId: String, filename: String) async throws -> (uploadUrl: String, publicUrl: String) {
        // Use backend to generate presigned URL
        // This would require adding a new endpoint, for now use uploadPhoto
        throw NSError(domain: "R2Service", code: 501, userInfo: [NSLocalizedDescriptionKey: "Use uploadPhoto for now"])
    }

    // MARK: - Generate Public URL

    /// Generate public URL for a stored file
    func getPublicURL(for key: String, type: MediaType) -> String {
        let bucket = type == .image ? 
            "\(process.env.R2_BUCKET_NAME_IMAGES ?? "groove-ai-images").\(process.env.R2_ACCOUNT_ID ?? "").r2.cloudflarestorage.com" :
            "\(process.env.R2_BUCKET_NAME_VIDEOS ?? "groove-ai-videos").\(process.env.R2_ACCOUNT_ID ?? "").r2.cloudflarestorage.com"
        return "https://\(bucket)/\(key)"
    }
    
    enum MediaType {
        case image
        case video
    }
}