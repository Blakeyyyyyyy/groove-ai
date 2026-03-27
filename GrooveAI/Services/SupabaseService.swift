import Foundation

/// Supabase client for Edge Function calls and auth
/// All API keys stay server-side. This only talks to Edge Functions.
final class SupabaseService {
    static let shared = SupabaseService()

    private let baseURL: String
    private let anonKey: String

    private init() {
        // These are safe to include in the app — they're public anon keys
        // All sensitive operations go through Edge Functions with service role
        self.baseURL = "https://tfbcdcrlhsxvlufmnzdr.supabase.co"
        self.anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
            ?? ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"]
            ?? ""
    }

    // MARK: - Auth Token

    /// Get the current auth token. In production, use Supabase Auth SDK.
    /// For now, returns the session token from secure storage.
    private var authToken: String? {
        get { KeychainHelper.get(key: "supabase_auth_token") }
        set {
            if let value = newValue {
                KeychainHelper.set(key: "supabase_auth_token", value: value)
            } else {
                KeychainHelper.delete(key: "supabase_auth_token")
            }
        }
    }

    var isAuthenticated: Bool { authToken != nil }

    func setAuthToken(_ token: String) {
        authToken = token
    }

    func clearAuth() {
        authToken = nil
    }

    // MARK: - Edge Function Calls

    func callFunction<T: Decodable>(
        _ name: String,
        body: [String: Any]? = nil
    ) async throws -> T {
        let url = URL(string: "\(baseURL)/functions/v1/\(name)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "apikey")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.networkError
        }

        if httpResponse.statusCode == 429 {
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw SupabaseError.rateLimited(errorResponse?.error ?? "Rate limited")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw SupabaseError.serverError(
                httpResponse.statusCode,
                errorResponse?.error ?? "Unknown error"
            )
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - User

    func getUser() async throws -> UserProfile {
        let response: GetUserResponse = try await callFunction("get-user")
        return response.user
    }

    // MARK: - Credits

    func deductCredits(amount: Int, videoId: String? = nil) async throws -> DeductCreditsResponse {
        var body: [String: Any] = ["amount": amount]
        if let videoId = videoId {
            body["video_id"] = videoId
        }
        return try await callFunction("deduct-credits", body: body)
    }

    // MARK: - Video Generation

    func generateVideo(imageURL: String, danceStyle: String, dancePrompt: String?) async throws -> GenerateVideoResponse {
        var body: [String: Any] = [
            "image_url": imageURL,
            "dance_style": danceStyle,
        ]
        if let prompt = dancePrompt {
            body["dance_prompt"] = prompt
        }
        return try await callFunction("generate-video", body: body)
    }

    func checkVideoStatus(videoId: String) async throws -> VideoStatusResponse {
        return try await callFunction("video-status", body: ["video_id": videoId])
    }
}

// MARK: - Response Types

struct GetUserResponse: Decodable {
    let user: UserProfile
}

struct UserProfile: Decodable {
    let id: String
    let coins: Int
    let subscriptionStatus: String
    let subscriptionExpiresAt: String?
    let r2UserFolder: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, coins
        case subscriptionStatus = "subscription_status"
        case subscriptionExpiresAt = "subscription_expires_at"
        case r2UserFolder = "r2_user_folder"
        case createdAt = "created_at"
    }
}

struct DeductCreditsResponse: Decodable {
    let success: Bool
    let coinsRemaining: Int?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success
        case coinsRemaining = "coins_remaining"
        case error
    }
}

struct GenerateVideoResponse: Decodable {
    let success: Bool
    let videoId: String?
    let subjectType: String?
    let coinsRemaining: Int?
    let message: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success
        case videoId = "video_id"
        case subjectType = "subject_type"
        case coinsRemaining = "coins_remaining"
        case message, error
    }
}

struct VideoStatusResponse: Decodable {
    let videoId: String
    let status: String
    let videoUrl: String?
    let thumbnailUrl: String?
    let danceStyle: String?
    let subjectType: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case videoId = "video_id"
        case status
        case videoUrl = "video_url"
        case thumbnailUrl = "thumbnail_url"
        case danceStyle = "dance_style"
        case subjectType = "subject_type"
        case createdAt = "created_at"
    }
}

struct ErrorResponse: Decodable {
    let error: String
}

// MARK: - Errors

enum SupabaseError: LocalizedError {
    case networkError
    case rateLimited(String)
    case serverError(Int, String)
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network error. Check your connection."
        case .rateLimited(let msg):
            return msg
        case .serverError(_, let msg):
            return msg
        case .notAuthenticated:
            return "Please sign in to continue."
        }
    }
}

// MARK: - Keychain Helper

enum KeychainHelper {
    static func set(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
