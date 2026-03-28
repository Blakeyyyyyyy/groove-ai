import Foundation

class SupabaseService {
    static let shared = SupabaseService()
    
    private let baseURL = "https://groove-ai-backend-1.onrender.com/api"
    
    private init() {}
    
    // MARK: - User
    
    func getUser(id: String) async throws -> [String: Any] {
        let url = URL(string: "\(baseURL)/user/\(id)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
    
    func deductCoins(userId: String, amount: Int) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: "\(baseURL)/deduct-credits")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["user_id": userId, "amount": amount])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "SupabaseService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to deduct coins"])
        }
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
    
    func addCoins(userId: String, amount: Int, type: String) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: "\(baseURL)/add-coins")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["user_id": userId, "amount": amount, "type": type])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "SupabaseService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to add coins"])
        }
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
    
    // MARK: - Videos
    
    func getVideos(userId: String) async throws -> [[String: Any]] {
        let url = URL(string: "\(baseURL)/videos/\(userId)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
    }
    
    // MARK: - Generation
    
    func getPresets() async throws -> [[String: Any]] {
        let url = URL(string: "\(baseURL)/presets")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
    }
    
    /// Request a presigned upload URL from the backend (JSON, not multipart).
    /// Returns dictionary with: uploadUrl, key, publicUrl
    func getPresignedUploadURL(userId: String, filename: String, contentType: String) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: "\(baseURL)/upload-presigned")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "user_id": userId,
            "filename": filename,
            "contentType": contentType
        ])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "SupabaseService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to get presigned URL"])
        }
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
    
    func classifyImage(imageURL: String) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: "\(baseURL)/classify-image")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["image_url": imageURL])
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
    
    func generateVideo(userId: String, imageURL: String, danceStyle: String, subjectType: String) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: "\(baseURL)/generate-video")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "user_id": userId,
            "image_url": imageURL,
            "dance_style": danceStyle,
            "subject_type": subjectType
        ])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "SupabaseService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Generation failed: \(errorBody)"])
        }
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
    
    func checkVideoStatus(taskId: String) async throws -> [String: Any] {
        let url = URL(string: "\(baseURL)/video-status/\(taskId)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
    
    func saveVideo(videoId: String, videoURL: String) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: "\(baseURL)/save-video")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["video_id": videoId, "video_url": videoURL])
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}
