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

    enum DanceBadge: String {
        case trending = "🔥 Trending"
        case hot = "🔥 Hot"
        case fanFave = "😂 Fan Fave"
        case newDance = "✨ New"
    }

    // MARK: - R2 Base URL
    private static let r2Base = "https://videos.trygrooveai.com/presets"

    // MARK: - All Presets (matches backend IDs)

    static let allPresets: [DancePreset] = [
        // TRENDING (5)
        DancePreset(
            id: "big-guy",
            name: "Big Guy",
            shortDescription: "The big guy dance",
            category: "Trending",
            badge: .trending,
            coinCost: 60,
            pillTags: ["🔥 Trending", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.10, green: 0.10, blue: 0.18),
            videoURL: "\(r2Base)/big-guy-V5-AI.mp4",
            thumbnailURL: nil
        ),
        DancePreset(
            id: "coco-channel",
            name: "Coco Channel",
            shortDescription: "Iconic moves",
            category: "Trending",
            badge: .trending,
            coinCost: 60,
            pillTags: ["🔥 Trending", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.18, green: 0.04, blue: 0.18),
            videoURL: "\(r2Base)/coco-channel-75fcae6c.mp4",
            thumbnailURL: "\(r2Base)/coco-channel-75fcae6c.mp4"
        ),
        DancePreset(
            id: "trag",
            name: "Trag",
            shortDescription: "Trag dance vibes",
            category: "Trending",
            badge: .hot,
            coinCost: 60,
            pillTags: ["🔥 Trending", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.10, green: 0.10, blue: 0.04),
            videoURL: "\(r2Base)/trag-V5-AI.mp4",
            thumbnailURL: nil
        ),
        DancePreset(
            id: "ophelia",
            name: "Ophelia",
            shortDescription: "Ophelia dance",
            category: "Trending",
            badge: .trending,
            coinCost: 60,
            pillTags: ["🔥 Trending", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.18, green: 0.04, blue: 0.04),
            videoURL: "\(r2Base)/ophelia-ai.mp4",
            thumbnailURL: "\(r2Base)/ophelia-ai.mp4"
        ),
        DancePreset(
            id: "jenny",
            name: "Jenny",
            shortDescription: "Jenny dance groove",
            category: "Trending",
            badge: .hot,
            coinCost: 60,
            pillTags: ["🔥 Trending", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.10, green: 0.18, blue: 0.10),
            videoURL: "\(r2Base)/jenny-ai.mp4",
            thumbnailURL: "\(r2Base)/jenny-ai.mp4"
        ),

        // CLASSIC (3)
        DancePreset(
            id: "macarena",
            name: "Macarena",
            shortDescription: "The classic everyone knows",
            category: "Classic",
            badge: .fanFave,
            coinCost: 60,
            pillTags: ["🎵 Classic", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.10, green: 0.10, blue: 0.18),
            videoURL: "\(r2Base)/macarena-V5-AI.mp4",
            thumbnailURL: nil
        ),
        DancePreset(
            id: "milkshake",
            name: "Milkshake",
            shortDescription: "Smooth moves only",
            category: "Classic",
            badge: nil,
            coinCost: 60,
            pillTags: ["🎵 Classic", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.18, green: 0.04, blue: 0.18),
            videoURL: "\(r2Base)/milkshake-V5-AI.mp4",
            thumbnailURL: nil
        ),
        DancePreset(
            id: "c-walk",
            name: "C Walk",
            shortDescription: "West Coast classic",
            category: "Classic",
            badge: nil,
            coinCost: 60,
            pillTags: ["🎵 Classic", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.10, green: 0.10, blue: 0.04),
            videoURL: "\(r2Base)/c-walk-V5-AI.mp4",
            thumbnailURL: nil
        ),

        // FACE DANCE (3)
        DancePreset(
            id: "boombastic",
            name: "Boombastic",
            shortDescription: "Face dance magic",
            category: "Face Dance",
            badge: .hot,
            coinCost: 60,
            pillTags: ["🎭 Face Dance", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.18, green: 0.10, blue: 0.04),
            videoURL: "\(r2Base)/baby-boombastic.mp4",
            thumbnailURL: nil
        ),
        DancePreset(
            id: "witch-doctor",
            name: "Witch Doctor",
            shortDescription: "Face dance chaos",
            category: "Face Dance",
            badge: .fanFave,
            coinCost: 60,
            pillTags: ["🎭 Face Dance", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.18, green: 0.04, blue: 0.04),
            videoURL: "\(r2Base)/witch-doctor-v3.mp4",
            thumbnailURL: nil
        ),
        DancePreset(
            id: "cotton-eye-joe",
            name: "Cotton Eye Joe",
            shortDescription: "The one everyone knows",
            category: "Face Dance",
            badge: .fanFave,
            coinCost: 60,
            pillTags: ["🎭 Face Dance", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.10, green: 0.04, blue: 0.10),
            videoURL: "\(r2Base)/cotton-eye-joe.mp4",
            thumbnailURL: nil
        ),
    ]

    // MARK: - Grouped by Category

    struct CategoryGroup: Identifiable, Hashable {
        let id: String
        let name: String
        let presets: [DancePreset]
    }

    static var categories: [CategoryGroup] {
        let order = ["Trending", "Classic", "Face Dance"]
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
        "big-guy": "https://videos.trygrooveai.com/demos/woman-big-guy.mp4",
        "coco-channel": "https://v16-kling-fdl.klingai.com/bs2/upload-ylab-stunt-sgp/muse/864196381107044352/VIDEO/20260422/d85913e2512ac59a58f17a6068c5e2ea-9727ee72-ae52-4825-90fd-82ccbf283115.mp4"
    ]
}
