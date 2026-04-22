import SwiftUI

// MARK: - Onboarding Subject
enum OnboardingSubject: String, CaseIterable, Identifiable {
    case pet = "My Pet"
    case baby = "My Baby"
    case friend = "My Friend"
    case myself = "Myself"

    var id: String { rawValue }

    /// Human-readable display name (overrides raw value where needed)
    var displayName: String {
        switch self {
        case .pet: return "My Pet"
        case .baby: return "My Baby"
        case .friend: return "My Friend"
        case .myself: return "A Person"
        }
    }

    var icon: String {
        switch self {
        case .pet: return "dog.fill"
        case .baby: return "face.smiling.inverse"
        case .friend: return "person.2.fill"
        case .myself: return "person.fill"
        }
    }

    /// Subjects shown in the redesigned Page 2 picker (just 2 hero options)
    static let pickerSubjects: [OnboardingSubject] = [.pet, .myself]

    /// Reference video for the tile preview loop
    var tileVideoName: String {
        switch self {
        case .pet: return "Milkshake Dance"
        case .baby: return "Face Dance - Witch Doctor (2)"
        case .friend: return "cotten eye joe (face dance)"
        case .myself: return "C walk (dance)"
        }
    }
}

// MARK: - Dance Style for Onboarding
struct OnboardingDanceStyle: Identifiable {
    let id: String
    let name: String
    /// Short emotional descriptor shown under the name on Page 3 (e.g. "Bold & energetic")
    let descriptor: String
    let badge: String?
    let videoName: String // reference video filename (no extension)

    static func styles(for subject: OnboardingSubject) -> [OnboardingDanceStyle] {
        // Returns exactly 3 styles per subject for the redesigned Page 3
        switch subject {
        case .pet:
            return [
                OnboardingDanceStyle(id: "hip-hop-shuffle", name: "Hip Hop Shuffle",
                                     descriptor: "Bold & energetic",
                                     badge: "🔥 Most popular",
                                     videoName: "Face Dance - She Call Me Mr. Boombastic(new)"),
                OnboardingDanceStyle(id: "viral-spin", name: "Viral TikTok Spin",
                                     descriptor: "Trendy & infectious",
                                     badge: nil,
                                     videoName: "Milkshake Dance"),
                OnboardingDanceStyle(id: "happy-wiggle", name: "Happy Wiggle",
                                     descriptor: "Cute & hilarious",
                                     badge: nil,
                                     videoName: "cotten eye joe (face dance)")
            ]
        case .baby:
            return [
                OnboardingDanceStyle(id: "adorable-bounce", name: "Adorable Bounce",
                                     descriptor: "Sweet & shareable",
                                     badge: "🔥 Most popular",
                                     videoName: "Face Dance - Witch Doctor (2)"),
                OnboardingDanceStyle(id: "tiktok-trend", name: "TikTok Trend",
                                     descriptor: "Viral & fun",
                                     badge: nil,
                                     videoName: "Milkshake Dance"),
                OnboardingDanceStyle(id: "head-bop", name: "Head Bop",
                                     descriptor: "Smooth & silly",
                                     badge: nil,
                                     videoName: "Face Dance - She Call Me Mr. Boombastic(new)")
            ]
        case .friend:
            return [
                OnboardingDanceStyle(id: "current-trend", name: "Current Trend",
                                     descriptor: "Hot right now",
                                     badge: "🔥 Most popular",
                                     videoName: "cotten eye joe (face dance)"),
                OnboardingDanceStyle(id: "old-school", name: "Old School Hip Hop",
                                     descriptor: "Classic & smooth",
                                     badge: nil,
                                     videoName: "C walk (dance)"),
                OnboardingDanceStyle(id: "chaos-mode", name: "Chaos Mode",
                                     descriptor: "Wild & chaotic",
                                     badge: nil,
                                     videoName: "Milkshake Dance")
            ]
        case .myself:
            return [
                OnboardingDanceStyle(id: "viral-tiktok", name: "Viral TikTok",
                                     descriptor: "Bold & energetic",
                                     badge: "🔥 Most popular",
                                     videoName: "Milkshake Dance"),
                OnboardingDanceStyle(id: "smooth-rnb", name: "Smooth R&B",
                                     descriptor: "Slick & confident",
                                     badge: nil,
                                     videoName: "Face Dance - She Call Me Mr. Boombastic(new)"),
                OnboardingDanceStyle(id: "hip-hop-flex", name: "Hip Hop Flex",
                                     descriptor: "Street & raw",
                                     badge: nil,
                                     videoName: "C walk (dance)")
            ]
        }
    }
}

// MARK: - Result Video Mapping
enum OnboardingVideoMapper {
    /// Maps subject + style to a reference video for Screen 4
    static func resultVideoName(subject: OnboardingSubject, style: OnboardingDanceStyle) -> String {
        return style.videoName
    }

    /// All 6 reference videos for the hook screen rotation
    static let hookVideos: [String] = [
        "C walk (dance)",
        "Face Dance - She Call Me Mr. Boombastic(new)",
        "Face Dance - Witch Doctor (2)",
        "Milkshake Dance",
        "Trag dance",
        "cotten eye joe (face dance)"
    ]
}
