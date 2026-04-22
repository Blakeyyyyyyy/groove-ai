import SwiftUI

private struct GrooveOnboardingStatePreviewHost<Content: View>: View {
    @StateObject private var state: GrooveOnboardingState
    private let content: (GrooveOnboardingState) -> Content

    init(
        subjectId: String = "person",
        danceId: String = "big-guy",
        @ViewBuilder content: @escaping (GrooveOnboardingState) -> Content
    ) {
        let previewState = GrooveOnboardingState()
        previewState.selectedSubjectId = subjectId
        previewState.selectedDanceId = danceId
        _state = StateObject(wrappedValue: previewState)
        self.content = content
    }

    var body: some View {
        content(state)
    }
}

#Preview("V2 Hero") {
    GrooveHeroScrollViewV2(onNext: {})
}

#Preview("V2 Subject") {
    GrooveOnboardingStatePreviewHost(subjectId: "person") { state in
        GrooveSubjectSelectViewV2(state: state, onNext: {})
    }
}

#Preview("V2 Dance") {
    GrooveOnboardingStatePreviewHost(subjectId: "person", danceId: "big-guy") { state in
        GrooveDanceSelectViewV2(state: state, onNext: {})
    }
}

#Preview("V2 Trial") {
    TrialEnabledScreenV2(onNext: {})
}
