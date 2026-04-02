// GrooveOnboardingState.swift
// Shared state object passed through the onboarding flow.

import SwiftUI

class GrooveOnboardingState: ObservableObject {
    @Published var selectedSubjectId: String = ""   // "dog" | "person"
    @Published var selectedDanceId:   String = ""   // preset ID

    func subjectEmoji() -> String {
        switch selectedSubjectId {
        case "dog":   return "🐕"
        case "person": return "👩"
        default:      return "🐕"
        }
    }
}
