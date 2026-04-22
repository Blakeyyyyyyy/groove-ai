import SwiftUI

struct GroovePremiumMagicResultFlowViewV2: View {
    @ObservedObject var state: GrooveOnboardingState
    let onNext: () -> Void

    var body: some View {
        ZStack {
            GrooveOnboardingTheme.background.ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.4)
                Text("Creating your video")
                    .foregroundStyle(Color.white)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            onNext()
        }
    }
}
