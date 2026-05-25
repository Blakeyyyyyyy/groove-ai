import SwiftUI

struct DancePreset: Identifiable, Hashable {
    let id: String
    let name: String
    let shortDescription: String
    let category: String
    let badge: DanceBadge?
    let coinCost: Int
    let pillTags: [String]
    let placeholderGradientTop: Color
    let placeholderGradientBottom: Color
    let videoURL: String?
    let thumbnailURL: String?
    let posterURL: String?

    /// True when this preset uses Kling's face-tracking model.
    /// Pet photos are rejected by Kling for these presets.
    var isFaceDance: Bool { category == "Face Dance" }

    enum DanceBadge: String {
        case trending = "🔥 Trending"
        case hot = "🔥 Hot"
        case fanFave = "😂 Fan Fave"
        case newDance = "✨ New"
    }

    // MARK: - R2 Base URL
    private static let r2Base = "https://videos.trygrooveai.com/presets"

    // MARK: - All Presets (matches backend IDs)

    private static let r2Output = "https://videos.trygrooveai.com/preset-tests/output"

    static let allPresets: [DancePreset] = [
        // MICHAEL JACKSON DANCES (3)
        DancePreset(
            id: "moonwalk",
            name: "Moonwalk",
            shortDescription: "Michael Jackson's most iconic move",
            category: "Michael Jackson Dances",
            badge: .trending,
            coinCost: 60,
            pillTags: ["🎤 MJ Classic", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.04, green: 0.04, blue: 0.20),
            videoURL: "\(r2Output)/moonwalk-mj-1779680815653.mp4",
            thumbnailURL: nil,
            posterURL: "\(r2Base)/posters/moonwalk-poster.jpg"
        ),
        DancePreset(
            id: "mj-thriller",
            name: "PYT Dance",
            shortDescription: "The King of Pop's most iconic dance",
            category: "Michael Jackson Dances",
            badge: .hot,
            coinCost: 60,
            pillTags: ["🎤 MJ Classic", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.20, green: 0.04, blue: 0.04),
            videoURL: "\(r2Output)/mj-klingtest-1777888999457.mp4",
            thumbnailURL: nil,
            posterURL: "\(r2Base)/posters/mj-thriller-poster.jpg"
        ),
        DancePreset(
            id: "beat-it",
            name: "Beat It",
            shortDescription: "Michael Jackson's legendary street style moves",
            category: "Michael Jackson Dances",
            badge: .hot,
            coinCost: 60,
            pillTags: ["🎤 MJ Classic", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.18, green: 0.08, blue: 0.02),
            videoURL: "\(r2Output)/gemini-michael-trimmed-1778546590784.mp4",
            thumbnailURL: nil,
            posterURL: "\(r2Base)/posters/beat-it-poster.jpg"
        ),

        // TRENDING (7 — includes new presets)
        DancePreset(
            id: "pop-lock",
            name: "Pop Lock",
            shortDescription: "The classic street style pop & lock",
            category: "Trending Now",
            badge: .trending,
            coinCost: 60,
            pillTags: ["🔥 Trending", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.04, green: 0.10, blue: 0.20),
            videoURL: "\(r2Output)/snaptik-v3-test-1777873850368.mp4",
            thumbnailURL: nil,
            posterURL: "\(r2Base)/posters/pop-lock-poster.jpg"
        ),
        DancePreset(
            id: "sahur-dance",
            name: "Sahur Dance",
            shortDescription: "The viral TikTok Tung Tung Tung trend",
            category: "Trending Now",
            badge: .newDance,
            coinCost: 60,
            pillTags: ["✨ New", "🐾 Pets Welcome"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.12, green: 0.06, blue: 0.18),
            videoURL: "\(r2Output)/dog-snaptik-dance-1778549183486.mp4",
            thumbnailURL: nil,
            posterURL: "\(r2Base)/posters/sahur-dance-poster.jpg"
        ),
        DancePreset(
            id: "buttons",
            name: "Buttons",
            shortDescription: "The viral PCD TikTok dance",
            category: "Trending Now",
            badge: .trending,
            coinCost: 60,
            pillTags: ["🔥 Trending", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.18, green: 0.04, blue: 0.12),
            videoURL: "https://videos.trygrooveai.com/preset-tests/output/buttons-p3-blonde-1779678155466.mp4",
            thumbnailURL: nil,
            posterURL: "\(r2Base)/posters/buttons-poster.jpg"
        ),
        DancePreset(
            id: "rasputin",
            name: "Rasputin",
            shortDescription: "The legendary Boney M dance",
            category: "Trending Now",
            badge: .trending,
            coinCost: 60,
            pillTags: ["🔥 Trending", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.14, green: 0.04, blue: 0.18),
            videoURL: "https://videos.trygrooveai.com/preset-tests/output/rasputin-p4-muscular-1779678155470.mp4",
            thumbnailURL: nil,
            posterURL: "\(r2Base)/posters/rasputin-poster.jpg"
        ),
        DancePreset(
            id: "bangara",
            name: "Bangaranga",
            shortDescription: "Eurovision 2026's biggest hit",
            category: "Trending Now",
            badge: .newDance,
            coinCost: 60,
            pillTags: ["✨ New", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.18, green: 0.10, blue: 0.04),
            videoURL: "https://videos.trygrooveai.com/preset-tests/output/bangara-p5-latina-1779678155471.mp4",
            thumbnailURL: nil,
            posterURL: "\(r2Base)/posters/bangara-poster.jpg"
        ),
        DancePreset(
            id: "beauty-and-a-beat",
            name: "Beauty And A Beat",
            shortDescription: "Justin Bieber's iconic body roll",
            category: "Trending Now",
            badge: .hot,
            coinCost: 60,
            pillTags: ["🔥 Trending", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.04, green: 0.12, blue: 0.20),
            videoURL: "https://videos.trygrooveai.com/preset-tests/output/beauty-beat-p1-olderman-1779678155472.mp4",
            thumbnailURL: nil,
            posterURL: "\(r2Base)/posters/beauty-beat-poster.jpg"
        ),
        DancePreset(
            id: "big-guy",
            name: "Big Guy",
            shortDescription: "The big guy dance",
            category: "Fan Favorites",
            badge: .trending,
            coinCost: 60,
            pillTags: ["🔥 Trending", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.10, green: 0.10, blue: 0.18),
            videoURL: "\(r2Base)/big-guy-V5-AI.mp4",
            thumbnailURL: nil,
            posterURL: "\(r2Base)/posters/big-guy-V5-AI-poster.jpg"
        ),
        DancePreset(
            id: "coco-channel",
            name: "Coco Channel",
            shortDescription: "Iconic moves",
            category: "Fan Favorites",
            badge: .trending,
            coinCost: 60,
            pillTags: ["🔥 Trending", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.18, green: 0.04, blue: 0.18),
            videoURL: "\(r2Base)/coco-channel-75fcae6c.mp4",
            thumbnailURL: "\(r2Base)/coco-channel-75fcae6c.mp4",
            posterURL: "\(r2Base)/posters/coco-channel-75fcae6c-poster.jpg"
        ),
        DancePreset(
            id: "trag",
            name: "Trag",
            shortDescription: "Trag dance vibes",
            category: "Fan Favorites",
            badge: .hot,
            coinCost: 60,
            pillTags: ["🔥 Trending", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.10, green: 0.10, blue: 0.04),
            videoURL: "\(r2Base)/trag-V5-AI.mp4",
            thumbnailURL: nil,
            posterURL: "\(r2Base)/posters/trag-V5-AI-poster.jpg"
        ),
        DancePreset(
            id: "ophelia",
            name: "Ophelia",
            shortDescription: "Ophelia dance",
            category: "Fan Favorites",
            badge: .trending,
            coinCost: 60,
            pillTags: ["🔥 Trending", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.18, green: 0.04, blue: 0.04),
            videoURL: "\(r2Base)/ophelia-ai.mp4",
            thumbnailURL: "\(r2Base)/ophelia-ai.mp4",
            posterURL: "\(r2Base)/posters/ophelia-ai-poster.jpg"
        ),
        DancePreset(
            id: "jenny",
            name: "Jenny",
            shortDescription: "Jenny dance groove",
            category: "Fan Favorites",
            badge: .hot,
            coinCost: 60,
            pillTags: ["🔥 Trending", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.10, green: 0.18, blue: 0.10),
            videoURL: "\(r2Base)/jenny-ai.mp4",
            thumbnailURL: "\(r2Base)/jenny-ai.mp4",
            posterURL: "\(r2Base)/posters/jenny-ai-poster.jpg"
        ),

        // CLASSIC (3)
        DancePreset(
            id: "macarena",
            name: "Macarena",
            shortDescription: "The classic everyone knows",
            category: "Classics",
            badge: .fanFave,
            coinCost: 60,
            pillTags: ["🎵 Classic", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.10, green: 0.10, blue: 0.18),
            videoURL: "\(r2Base)/macarena-V5-AI.mp4",
            thumbnailURL: nil,
            posterURL: "\(r2Base)/posters/macarena-V5-AI-poster.jpg"
        ),
        DancePreset(
            id: "milkshake",
            name: "Milkshake",
            shortDescription: "Smooth moves only",
            category: "Classics",
            badge: nil,
            coinCost: 60,
            pillTags: ["🎵 Classic", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.18, green: 0.04, blue: 0.18),
            videoURL: "\(r2Base)/milkshake-V5-AI.mp4",
            thumbnailURL: nil,
            posterURL: "\(r2Base)/posters/milkshake-V5-AI-poster.jpg"
        ),
        DancePreset(
            id: "c-walk",
            name: "C Walk",
            shortDescription: "West Coast classic",
            category: "Classics",
            badge: nil,
            coinCost: 60,
            pillTags: ["🎵 Classic", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.10, green: 0.10, blue: 0.04),
            videoURL: "\(r2Base)/c-walk-V5-AI.mp4",
            thumbnailURL: nil,
            posterURL: "\(r2Base)/posters/c-walk-V5-AI-poster.jpg"
        ),

        // FACE DANCE (3)
        DancePreset(
            id: "boombastic",
            name: "Boombastic",
            shortDescription: "Face dance magic",
            category: "Face Dance",
            badge: .hot,
            coinCost: 60,
            pillTags: ["🎭 Face Dance", "👤 Humans Only"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.18, green: 0.10, blue: 0.04),
            videoURL: "\(r2Base)/baby-boombastic.mp4",
            thumbnailURL: nil,
            posterURL: "\(r2Base)/posters/baby-boombastic-poster.jpg"
        ),
        DancePreset(
            id: "witch-doctor",
            name: "Witch Doctor",
            shortDescription: "Face dance chaos",
            category: "Face Dance",
            badge: .fanFave,
            coinCost: 60,
            pillTags: ["🎭 Face Dance", "👤 Humans Only"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.18, green: 0.04, blue: 0.04),
            videoURL: "\(r2Base)/witch-doctor-v3.mp4",
            thumbnailURL: nil,
            posterURL: "\(r2Base)/posters/witch-doctor-v3-poster.jpg"
        ),
        DancePreset(
            id: "cotton-eye-joe",
            name: "Cotton Eye Joe",
            shortDescription: "The one everyone knows",
            category: "Face Dance",
            badge: .fanFave,
            coinCost: 60,
            pillTags: ["🎭 Face Dance", "👤 Humans Only"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.10, green: 0.04, blue: 0.10),
            videoURL: "\(r2Base)/cotton-eye-joe.mp4",
            thumbnailURL: nil,
            posterURL: "\(r2Base)/posters/cotton-eye-joe-poster.jpg"
        ),
    ]

    // MARK: - Grouped by Category

    struct CategoryGroup: Identifiable, Hashable {
        let id: String
        let name: String
        let presets: [DancePreset]
    }

    static var categories: [CategoryGroup] {
        let order = ["Michael Jackson Dances", "Trending Now", "Fan Favorites", "Classics", "Face Dance"]
        var grouped: [String: [DancePreset]] = [:]
        for preset in allPresets {
            grouped[preset.category, default: []].append(preset)
        }
        return order.compactMap { name in
            guard let presets = grouped[name], !presets.isEmpty else { return nil }
            return CategoryGroup(id: name, name: name, presets: presets)
        }
    }

    // MARK: - Dog Demo Videos (mapped to presets for PET subjects)
    static let dogDemoVideos: [String: String] = [
        "big-guy": "https://videos.trygrooveai.com/demos/golden-retriever-big-guy.mp4",
        "coco-channel": "https://videos.trygrooveai.com/demos/golden-retriever-coco-channel.mp4",
        "c-walk": "https://videos.trygrooveai.com/demos/golden-retriever-c-walk.mp4"
    ]

    // MARK: - Woman Demo Videos (mapped to presets for HUMAN subjects)
    static let womanDemoVideos: [String: String] = [
        "big-guy": "https://videos.trygrooveai.com/woman-big-guy.mp4",
        "coco-channel": "https://videos.trygrooveai.com/woman-coco-channel.mp4"
    ]
}
