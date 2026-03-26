import Foundation

struct DancePreset: Identifiable, Hashable {
    let id: String
    let name: String
    let shortDescription: String
    let badge: DanceBadge?
    let creditCost: Int
    let pillTags: [String]

    enum DanceBadge: String {
        case trending = "🔥 Trending"
        case hot = "🔥 Hot"
        case fanFave = "😂 Fan Fave"
        case newDance = "🆕 New"
    }

    static let allPresets: [DancePreset] = [
        DancePreset(
            id: "hip-hop",
            name: "Hip Hop",
            shortDescription: "Feel the beat",
            badge: .trending,
            creditCost: 60,
            pillTags: ["🎵 Hip Hop", "👤 All Faces"]
        ),
        DancePreset(
            id: "viral-tiktok",
            name: "Viral TikTok",
            shortDescription: "Everyone's doing this one",
            badge: .trending,
            creditCost: 60,
            pillTags: ["🎵 Viral", "👤 All Faces"]
        ),
        DancePreset(
            id: "c-walk",
            name: "C Walk",
            shortDescription: "West Coast classic",
            badge: nil,
            creditCost: 60,
            pillTags: ["🎵 C Walk", "👤 All Faces"]
        ),
        DancePreset(
            id: "cotton-eye-joe",
            name: "Cotton Eye Joe",
            shortDescription: "The one everyone knows",
            badge: .fanFave,
            creditCost: 60,
            pillTags: ["🎵 Country", "👤 All Faces"]
        ),
        DancePreset(
            id: "milkshake-dance",
            name: "Milkshake Dance",
            shortDescription: "Smooth moves only",
            badge: nil,
            creditCost: 60,
            pillTags: ["🎵 Pop", "👤 All Faces"]
        ),
        DancePreset(
            id: "boombastic",
            name: "Boombastic",
            shortDescription: "Face dance magic",
            badge: .hot,
            creditCost: 60,
            pillTags: ["🎭 Face Dance", "👤 All Faces"]
        ),
        DancePreset(
            id: "witch-doctor",
            name: "Witch Doctor",
            shortDescription: "Face dance chaos",
            badge: .fanFave,
            creditCost: 60,
            pillTags: ["🎭 Face Dance", "👤 All Faces"]
        ),
        DancePreset(
            id: "salsa",
            name: "Salsa",
            shortDescription: "Latin heat",
            badge: nil,
            creditCost: 60,
            pillTags: ["🎵 Salsa", "👤 All Faces"]
        ),
        DancePreset(
            id: "coming-soon",
            name: "More Coming...",
            shortDescription: "Stay tuned",
            badge: .newDance,
            creditCost: 60,
            pillTags: ["🆕 Coming Soon"]
        )
    ]
}
