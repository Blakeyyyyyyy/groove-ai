// GrooveDancePreset.swift
// Preset dance styles shown in the onboarding demo flow.

import Foundation

struct GrooveDancePreset: Identifiable {
    let id:           String
    let pillTitle:    String     // label on the pill button
    let promptText:   String     // full prompt sent to the AI model
    let emoji:        String     // decorative icon
}

extension GrooveDancePreset {
    static let allPresets: [GrooveDancePreset] = [
        GrooveDancePreset(
            id:        "hiphop",
            pillTitle: "🎤 Hip Hop",
            promptText: "Transform into a hip hop dancer, full-body breakdance moves, energetic street style",
            emoji:     "🎤"
        ),
        GrooveDancePreset(
            id:        "ballet",
            pillTitle: "🩰 Ballet",
            promptText: "Transform into a graceful ballet dancer, en pointe, elegant classical pose",
            emoji:     "🩰"
        ),
    ]
}
