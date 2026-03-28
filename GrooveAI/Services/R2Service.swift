import Foundation

/// Cloudflare R2 storage service
/// Uses Render backend for presigned URLs — keys stay server-side
final class R2Service {
    static let shared = R2Service()

    private init() {}

    // MARK: - Upload via Backend Presigned URL

    /// Upload photo to R2 — backend provides presigned URL, we PUT the data directly
    func uploadPhoto(data: Data, userId: String, filename: String? = nil) async throws -> String {
        let name = filename ?? "\(UUID().uuidString).jpg"
        print("[R2] ☁️ Starting upload: \(name) (\(data.count) bytes) for user: \(userId)")
        
        // 1. Get presigned URL from backend (JSON request)
        print("[R2] 📡 Requesting presigned URL...")
        let presignedResponse = try await SupabaseService.shared.getPresignedUploadURL(
            userId: userId,
            filename: name,
            contentType: "image/jpeg"
        )
        
        guard let uploadUrl = presignedResponse["uploadUrl"] as? String,
              let publicUrl = presignedResponse["publicUrl"] as? String else {
            print("[R2] ❌ Missing uploadUrl or publicUrl in response: \(presignedResponse)")
            throw NSError(domain: "R2Service", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to get presigned URL from backend"])
        }
        print("[R2] ✅ Got presigned URL, uploading to R2...")
        
        // 2. Upload directly to R2 using presigned URL
        var request = URLRequest(url: URL(string: uploadUrl)!)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("[R2] ❌ Upload failed with HTTP \(statusCode)")
            throw NSError(domain: "R2Service", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to upload to R2 (HTTP \(statusCode))"])
        }
        
        print("[R2] ✅ Upload complete! Public URL: \(publicUrl)")
        return publicUrl
    }
}
