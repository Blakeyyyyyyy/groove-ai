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

    enum DanceBadge: String {
        case trending = "🔥 Trending"
        case hot = "🔥 Hot"
        case fanFave = "😂 Fan Fave"
        case newDance = "✨ New"
    }

    // MARK: - All Presets

    static let allPresets: [DancePreset] = [
        DancePreset(
            id: "hip-hop",
            name: "Hip Hop",
            shortDescription: "Feel the beat",
            category: "Trending Now",
            badge: .trending,
            coinCost: 60,
            pillTags: ["🎵 Hip Hop", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.10, green: 0.10, blue: 0.18)
        ),
        DancePreset(
            id: "viral-tiktok",
            name: "Viral TikTok",
            shortDescription: "Everyone's doing this one",
            category: "Trending Now",
            badge: .trending,
            coinCost: 60,
            pillTags: ["🎵 Viral", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.18, green: 0.04, blue: 0.18)
        ),
        DancePreset(
            id: "boombastic",
            name: "Boombastic",
            shortDescription: "Face dance magic",
            category: "Trending Now",
            badge: .hot,
            coinCost: 60,
            pillTags: ["🎭 Face Dance", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.10, green: 0.10, blue: 0.04)
        ),
        DancePreset(
            id: "c-walk",
            name: "C Walk",
            shortDescription: "West Coast classic",
            category: "Hip Hop",
            badge: nil,
            coinCost: 60,
            pillTags: ["🎵 C Walk", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.10, green: 0.10, blue: 0.18)
        ),
        DancePreset(
            id: "milkshake-dance",
            name: "Milkshake Dance",
            shortDescription: "Smooth moves only",
            category: "Hip Hop",
            badge: nil,
            coinCost: 60,
            pillTags: ["🎵 Pop", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.18, green: 0.04, blue: 0.18)
        ),
        DancePreset(
            id: "cotton-eye-joe",
            name: "Cotton Eye Joe",
            shortDescription: "The one everyone knows",
            category: "Fun & Viral",
            badge: .fanFave,
            coinCost: 60,
            pillTags: ["🎵 Country", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.10, green: 0.10, blue: 0.04)
        ),
        DancePreset(
            id: "witch-doctor",
            name: "Witch Doctor",
            shortDescription: "Face dance chaos",
            category: "Fun & Viral",
            badge: .fanFave,
            coinCost: 60,
            pillTags: ["🎭 Face Dance", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.18, green: 0.04, blue: 0.04)
        ),
        DancePreset(
            id: "salsa",
            name: "Salsa",
            shortDescription: "Latin heat",
            category: "Latin",
            badge: nil,
            coinCost: 60,
            pillTags: ["🎵 Salsa", "👤 All Faces"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.18, green: 0.04, blue: 0.04)
        ),
        DancePreset(
            id: "coming-soon",
            name: "More Coming...",
            shortDescription: "Stay tuned",
            category: "Latin",
            badge: .newDance,
            coinCost: 60,
            pillTags: ["🆕 Coming Soon"],
            placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
            placeholderGradientBottom: Color(red: 0.10, green: 0.10, blue: 0.10)
        )
    ]

    // MARK: - Grouped by Category

    struct CategoryGroup: Identifiable {
        let id: String
        let name: String
        let presets: [DancePreset]
    }

    static var categories: [CategoryGroup] {
        let order = ["Trending Now", "Hip Hop", "Fun & Viral", "Latin"]
        var grouped: [String: [DancePreset]] = [:]
        for preset in allPresets {
            grouped[preset.category, default: []].append(preset)
        }
        return order.compactMap { name in
            guard let presets = grouped[name], !presets.isEmpty else { return nil }
            return CategoryGroup(id: name, name: name, presets: presets)
        }
    }
}
