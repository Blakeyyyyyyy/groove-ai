import Foundation

/// Gemini AI service — image classification
/// NOTE: Actual classification happens server-side in the generate-video Edge Function.
/// This client-side service is for optional pre-classification UX hints only.
/// The server ALWAYS re-classifies to prevent manipulation.
enum GeminiService {

    enum SubjectType: String, Codable {
        case human = "HUMAN"
        case pet = "PET"
        case baby = "BABY"

        var displayName: String {
            switch self {
            case .human: return "Person"
            case .pet: return "Pet"
            case .baby: return "Baby"
            }
        }

        var emoji: String {
            switch self {
            case .human: return "🕺"
            case .pet: return "🐕"
            case .baby: return "👶"
            }
        }
    }

    /// Quick client-side heuristic for UX hints (e.g., show "Pet detected!" badge)
    /// Server always re-validates — this is purely cosmetic
    static func classifyLocally(imageData: Data) -> SubjectType {
        // In v1, we skip client-side classification and let the server handle it
        // This could later use CoreML for instant UX feedback
        return .human
    }

    /// Parse subject type from server response
    static func parseSubjectType(_ string: String?) -> SubjectType {
        guard let string = string?.uppercased() else { return .human }
        return SubjectType(rawValue: string) ?? .human
    }
}
