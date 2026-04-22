// GrooveOnboardingState.swift
// Shared state object passed through the onboarding flow.

import SwiftUI

class GrooveOnboardingState: ObservableObject {
    @Published var selectedSubjectId: String = ""   // "dog" | "person"
    @Published var selectedDanceId:   String = ""   // preset ID
    @Published var selectedPreviewImage: UIImage?   // future-proofed for real user photo flows

    private let r2Base = "https://videos.trygrooveai.com/presets"

    func subjectEmoji() -> String {
        switch selectedSubjectId {
        case "dog":   return "🐕"
        case "person": return "👩"
        default:      return "🐕"
        }
    }

    var selectedPreset: DancePreset? {
        DancePreset.allPresets.first(where: { $0.id == selectedDanceId })
    }

    var selectedPreviewURL: String? {
        if let preset = selectedPreset {
            return preset.thumbnailURL ?? preset.videoURL
        }
        return subjectPreviewURL
    }

    var selectedSubjectPreviewURL: String? {
        subjectPreviewURL
    }

    var selectedVideoURL: String? {
        selectedPreset?.videoURL ?? subjectPreviewURL
    }

    private var subjectPreviewURL: String? {
        switch selectedSubjectId {
        case "dog":
            return "\(r2Base)/big-guy-V5-AI.mp4"
        case "person":
            return "\(r2Base)/baby-boombastic.mp4"
        default:
            return "\(r2Base)/big-guy-V5-AI.mp4"
        }
    }
}
