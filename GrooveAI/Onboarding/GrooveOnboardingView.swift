// GrooveOnboardingView.swift
// Root coordinator for the Groove AI onboarding flow.
// 7-screen flow: Hero → Subject → Dance → Magic → Result → Trial → Paywall
// Progress dots shown for pages 1–3 only (hidden on magic, result, trial, paywall)

import SwiftUI

struct GrooveOnboardingView: View {
    let onComplete: () -> Void

    @StateObject private var state = GrooveOnboardingState()
    @State private var currentPage: Int = 1

    var body: some View {
        ZStack {
            GrooveOnboardingTheme.background.ignoresSafeArea()

            // Progress dots — pages 1-3 only
            if currentPage >= 1 && currentPage <= 3 {
                VStack {
                    ProgressDots(current: currentPage, total: 3)
                        .padding(.top, 72) // 16pt below Dynamic Island area
                    Spacer()
                }
                .zIndex(10)
            }

            // Pages
            switch currentPage {
            case 1:
                GrooveHeroScrollView(onNext: { advance() })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal:   .move(edge: .leading)
                    ))

            case 2:
                GrooveSubjectSelectView(state: state, onNext: { advance() })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal:   .move(edge: .leading)
                    ))

            case 3:
                GrooveDanceSelectView(state: state, onNext: { advance() })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal:   .opacity  // crossfade to magic moment
                    ))

            case 4:
                GrooveMagicMomentView(state: state, onNext: { advance() })
                    .transition(.asymmetric(
                        insertion: .opacity,  // crossfade in from dance select
                        removal:   .move(edge: .bottom)  // push up to reveal result
                    ))

            case 5:
                GrooveResultCTAView(state: state, onNext: { advance() })
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal:   .move(edge: .leading)
                    ))

            case 6:
                TrialEnabledScreen(onNext: { advance() })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal:   .opacity
                    ))

            case 7:
                GroovePaywallScreen(
                    onPurchaseSuccess: onComplete,
                    onDismiss: onComplete
                )
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal:   .move(edge: .leading)
                    ))

            default:
                EmptyView()
            }
        }
    }

    private func advance() {
        withAnimation(.interpolatingSpring(
            mass: 1.0, stiffness: 200, damping: 22, initialVelocity: 0
        )) {
            currentPage += 1
        }
    }
}

// ─── Progress dots ────────────────────────────────────────────────────────────

private struct ProgressDots: View {
    let current: Int
    let total:   Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...total, id: \.self) { i in
                Circle()
                    .fill(
                        i == current
                            ? GrooveOnboardingTheme.blueAccent
                            : Color.white.opacity(0.25)
                    )
                    .frame(
                        width:  i == current ? 8 : 6,
                        height: i == current ? 8 : 6
                    )
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: current)
            }
        }
    }
}
