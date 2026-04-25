import Foundation

class SupabaseService {
    static let shared = SupabaseService()

    private let baseURL: String

    private init() {
        // Read SUPABASE_URL from Info.plist
        if let url = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String {
            self.baseURL = url
        } else {
            // Fallback to default URL if not found in plist
            self.baseURL = "https://groove-ai-backend-1.onrender.com/api"
            print("[SupabaseService] ⚠️ SUPABASE_URL not found in Info.plist, using default URL")
        }
    }
    
    // MARK: - User
    
    func getUser(id: String) async throws -> [String: Any] {
        print("[Supabase] 📡 GET /user/\(id)")
        let url = URL(string: "\(baseURL)/user/\(id)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        try checkHTTPResponse(response, data: data, context: "getUser")
        let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        print("[Supabase] ✅ getUser response: \(result)")
        return result
    }
    
    func deductCoins(userId: String, amount: Int) async throws -> [String: Any] {
        print("[Supabase] 📡 POST /deduct-credits userId=\(userId) amount=\(amount)")
        var request = URLRequest(url: URL(string: "\(baseURL)/deduct-credits")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["user_id": userId, "amount": amount])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTPResponse(response, data: data, context: "deductCoins")
        let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        print("[Supabase] ✅ deductCoins response: \(result)")
        return result
    }
    
    /// Refund coins for a failed video generation. video_id is the idempotency key.
    ///
    /// Returns:
    ///   (refunded: true,  coinsRemaining: Int?)   — first refund, coins credited
    ///   (refunded: false, coinsRemaining: nil)    — server responded 409 already_refunded
    /// Throws on any other error (network, 500, 404) — caller MUST NOT claim a refund happened.
    func refundCoins(userId: String, videoId: String, amount: Int = 60) async throws -> (refunded: Bool, coinsRemaining: Int?) {
        print("[Supabase] 📡 POST /refund-coins userId=\(userId) videoId=\(videoId) amount=\(amount)")
        var request = URLRequest(url: URL(string: "\(baseURL)/refund-coins")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "user_id": userId,
            "video_id": videoId,
            "amount": amount
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "SupabaseService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "refundCoins: Invalid response"])
        }

        let result = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        print("[Supabase] 📨 refundCoins HTTP \(httpResponse.statusCode) — \(result)")

        switch httpResponse.statusCode {
        case 200:
            let coins = result["coins_remaining"] as? Int
            return (refunded: true, coinsRemaining: coins)
        case 409:
            // Already refunded — the user's balance was credited on a previous
            // attempt. We treat this as "not a new refund" so the caller does
            // not show a duplicate "refunded" message.
            return (refunded: false, coinsRemaining: nil)
        default:
            let body = String(data: data, encoding: .utf8) ?? "No body"
            throw NSError(
                domain: "SupabaseService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "refundCoins failed (HTTP \(httpResponse.statusCode)): \(body)"]
            )
        }
    }

    func addCoins(userId: String, amount: Int, type: String, appleJWS: String?) async throws -> [String: Any] {
        print("[Supabase] 📡 POST /add-coins userId=\(userId) amount=\(amount) type=\(type) jws=\(appleJWS != nil ? "present" : "MISSING")")
        var request = URLRequest(url: URL(string: "\(baseURL)/add-coins")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["user_id": userId, "amount": amount, "type": type]
        if let jws = appleJWS {
            body["apple_jws"] = jws
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTPResponse(response, data: data, context: "addCoins")
        let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        print("[Supabase] ✅ addCoins response: \(result)")
        return result
    }
    
    // MARK: - Videos
    
    func getVideos(userId: String) async throws -> [[String: Any]] {
        print("[Supabase] 📡 GET /videos/\(userId)")
        let url = URL(string: "\(baseURL)/videos/\(userId)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        try checkHTTPResponse(response, data: data, context: "getVideos")
        return try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
    }
    
    // MARK: - Generation
    
    func getPresets() async throws -> [[String: Any]] {
        print("[Supabase] 📡 GET /presets")
        let url = URL(string: "\(baseURL)/presets")!
        let (data, response) = try await URLSession.shared.data(from: url)
        try checkHTTPResponse(response, data: data, context: "getPresets")
        return try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
    }
    
    /// Request a presigned upload URL from the backend (JSON, not multipart).
    /// Returns dictionary with: uploadUrl, key, publicUrl
    func getPresignedUploadURL(userId: String, filename: String, contentType: String) async throws -> [String: Any] {
        print("[Supabase] 📡 POST /upload-presigned userId=\(userId) filename=\(filename)")
        var request = URLRequest(url: URL(string: "\(baseURL)/upload-presigned")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "user_id": userId,
            "filename": filename,
            "contentType": contentType
        ])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTPResponse(response, data: data, context: "getPresignedUploadURL")
        let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        print("[Supabase] ✅ presigned URL received: \(result.keys.sorted())")
        return result
    }
    
    /// Unified image processing: upload + classify + optional transform in one call.
    /// Returns: { image_url, subject_type, transformed }
    func processImage(userId: String, imageData: Data) async throws -> [String: Any] {
        print("[Supabase] 📡 POST /process-image userId=\(userId) imageSize=\(imageData.count)")
        let url = URL(string: "\(baseURL)/process-image")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        // user_id field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(userId)\r\n".data(using: .utf8)!)
        // image field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTPResponse(response, data: data, context: "processImage")
        let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        print("[Supabase] ✅ processImage response: \(result)")
        return result
    }
    
    func classifyImage(imageURL: String) async throws -> [String: Any] {
        print("[Supabase] 📡 POST /classify-image imageURL=\(imageURL)")
        var request = URLRequest(url: URL(string: "\(baseURL)/classify-image")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["image_url": imageURL])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTPResponse(response, data: data, context: "classifyImage")
        let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        print("[Supabase] ✅ classifyImage response: \(result)")
        return result
    }
    
    func generateVideo(userId: String, imageURL: String, danceStyle: String, subjectType: String) async throws -> [String: Any] {
        print("[Supabase] 📡 POST /generate-video userId=\(userId) danceStyle=\(danceStyle) subjectType=\(subjectType)")
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
        try checkHTTPResponse(response, data: data, context: "generateVideo")
        let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        print("[Supabase] ✅ generateVideo response: \(result)")
        return result
    }
    
    func checkVideoStatus(taskId: String) async throws -> [String: Any] {
        print("[Supabase] 📡 GET /video-status/\(taskId)")
        let url = URL(string: "\(baseURL)/video-status/\(taskId)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        try checkHTTPResponse(response, data: data, context: "checkVideoStatus")
        let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        print("[Supabase] ✅ videoStatus: \(result)")
        return result
    }
    
    func saveVideo(userId: String, videoId: String, videoURL: String) async throws -> [String: Any] {
        print("[Supabase] 📡 POST /save-video userId=\(userId) videoId=\(videoId)")
        var request = URLRequest(url: URL(string: "\(baseURL)/save-video")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["user_id": userId, "video_id": videoId, "video_url": videoURL])

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTPResponse(response, data: data, context: "saveVideo")
        let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        print("[Supabase] ✅ saveVideo response: \(result)")
        return result
    }
    
    // MARK: - HTTP Response Validation
    
    private func checkHTTPResponse(_ response: URLResponse, data: Data, context: String) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            print("[Supabase] ❌ \(context): Non-HTTP response")
            throw NSError(domain: "SupabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "\(context): Invalid response"])
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "No body"
            print("[Supabase] ❌ \(context): HTTP \(httpResponse.statusCode) — \(body)")
            throw NSError(
                domain: "SupabaseService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "\(context) failed (HTTP \(httpResponse.statusCode)): \(body)"]
            )
        }
    }
}
