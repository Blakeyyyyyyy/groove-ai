import SwiftUI

// MARK: - Onboarding Subject
enum OnboardingSubject: String, CaseIterable, Identifiable {
    case pet = "My Pet"
    case baby = "My Baby"
    case friend = "My Friend"
    case myself = "Myself"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .pet: return "dog.fill"
        case .baby: return "face.smiling.inverse"
        case .friend: return "person.2.fill"
        case .myself: return "person.fill"
        }
    }

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
    let badge: String?
    let videoName: String // reference video filename (no extension)

    static func styles(for subject: OnboardingSubject) -> [OnboardingDanceStyle] {
        switch subject {
        case .pet:
            return [
                OnboardingDanceStyle(id: "hip-hop-shuffle", name: "Hip Hop Shuffle", badge: "🔥 Trending", videoName: "Face Dance - She Call Me Mr. Boombastic(new)"),
                OnboardingDanceStyle(id: "viral-spin", name: "Viral TikTok Spin", badge: nil, videoName: "Milkshake Dance"),
                OnboardingDanceStyle(id: "happy-wiggle", name: "Happy Wiggle", badge: nil, videoName: "cotten eye joe (face dance)"),
                OnboardingDanceStyle(id: "silly-samba", name: "Silly Samba", badge: nil, videoName: "Trag dance"),
                OnboardingDanceStyle(id: "moonwalk", name: "Moonwalk", badge: nil, videoName: "C walk (dance)")
            ]
        case .baby:
            return [
                OnboardingDanceStyle(id: "adorable-bounce", name: "Adorable Bounce", badge: "🔥 Trending", videoName: "Face Dance - Witch Doctor (2)"),
                OnboardingDanceStyle(id: "tiktok-trend", name: "TikTok Trend", badge: nil, videoName: "Milkshake Dance"),
                OnboardingDanceStyle(id: "head-bop", name: "Head Bop", badge: nil, videoName: "Face Dance - She Call Me Mr. Boombastic(new)"),
                OnboardingDanceStyle(id: "roly-poly", name: "Roly Poly Shuffle", badge: nil, videoName: "cotten eye joe (face dance)"),
                OnboardingDanceStyle(id: "party-time", name: "Party Time", badge: nil, videoName: "Trag dance")
            ]
        case .friend:
            return [
                OnboardingDanceStyle(id: "current-trend", name: "Current Trend", badge: "🔥 Trending", videoName: "cotten eye joe (face dance)"),
                OnboardingDanceStyle(id: "old-school", name: "Old School Hip Hop", badge: nil, videoName: "C walk (dance)"),
                OnboardingDanceStyle(id: "group-sync", name: "Group Sync", badge: nil, videoName: "Face Dance - She Call Me Mr. Boombastic(new)"),
                OnboardingDanceStyle(id: "throwback", name: "Throwback", badge: nil, videoName: "Trag dance"),
                OnboardingDanceStyle(id: "chaos-mode", name: "Chaos Mode", badge: nil, videoName: "Milkshake Dance")
            ]
        case .myself:
            return [
                OnboardingDanceStyle(id: "viral-tiktok", name: "Viral TikTok", badge: "🔥 Trending", videoName: "Milkshake Dance"),
                OnboardingDanceStyle(id: "smooth-rnb", name: "Smooth R&B", badge: nil, videoName: "Face Dance - She Call Me Mr. Boombastic(new)"),
                OnboardingDanceStyle(id: "hip-hop-flex", name: "Hip Hop Flex", badge: nil, videoName: "C walk (dance)"),
                OnboardingDanceStyle(id: "dance-challenge", name: "Dance Challenge", badge: nil, videoName: "cotten eye joe (face dance)"),
                OnboardingDanceStyle(id: "silly-mode", name: "Silly Mode", badge: nil, videoName: "Trag dance")
            ]
        }
    }
}

// MARK: - Result Video Mapping
enum OnboardingVideoMapper {
    /// Maps subject + style to a reference video for Screen 4
    static func resultVideoName(subject: OnboardingSubject, style: OnboardingDanceStyle) -> String {
        // Return the style's video — it already maps to a reference video
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
