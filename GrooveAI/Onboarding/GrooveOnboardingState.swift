// GrooveOnboardingState.swift
// Shared state object passed through the onboarding flow.

import SwiftUI

class GrooveOnboardingState: ObservableObject {
    @Published var selectedSubjectId: String = ""   // "dog" | "woman"
    @Published var selectedDanceId:   String = ""   // "hiphop" | "ballet"

    func subjectEmoji() -> String {
        switch selectedSubjectId {
        case "dog":   return "🐕"
        case "woman": return "👩"
        default:      return "🐕"
        }
    }
}
