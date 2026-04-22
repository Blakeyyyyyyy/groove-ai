// GrooveOnboardingView-v2.swift
// Root coordinator for the Groove AI onboarding flow — v2
// Uses Views-v2/ screens. Same logic as GrooveOnboardingView.swift.
// Wire this in ContentView.swift to activate the v2 onboarding flow.
// 7-screen flow: Hero → Subject → Dance → Magic → Result → Trial → Paywall
// Progress dots shown for pages 1–3 only

import SwiftUI

struct GrooveOnboardingViewV2: View {
    let onComplete: () -> Void

    @StateObject private var state = GrooveOnboardingState()
    @State private var currentPage: Int = 1

    var body: some View {
        ZStack {
            GrooveOnboardingTheme.background.ignoresSafeArea()

            // Progress dots — pages 1-3 only
            if currentPage >= 1 && currentPage <= 3 {
                VStack {
                    ProgressDotsV2(current: currentPage, total: 3)
                        .padding(.top, 72)
                    Spacer()
                }
                .zIndex(10)
            }

            // Pages — v2 screens
            switch currentPage {
            case 1:
                // GrooveHeroScrollViewV2 (v2 — no text overlays in carousel)
                GrooveHeroScrollViewV2(onNext: { advance() })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal:   .move(edge: .leading)
                    ))

            case 2:
                // GrooveSubjectSelectViewV2 (v2 — VStack landscape cards, auto-advance)
                GrooveSubjectSelectViewV2(state: state, onNext: { advance() })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal:   .move(edge: .leading)
                    ))

            case 3:
                // GrooveDanceSelectViewV2 (v2 — 3 horizontal cards, CTA slides up)
                GrooveDanceSelectViewV2(state: state, onNext: { advance() })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal:   .opacity
                    ))

            case 4:
                if GrooveOnboardingFeatureFlags.usePremiumMagicResultFlow {
                    GroovePremiumMagicResultFlowViewV2(state: state, onNext: { advance(by: 2) })
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal:   .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    GrooveMagicMomentViewV2(state: state, onNext: { advance() })
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal:   .move(edge: .bottom)
                        ))
                }

            case 5:
                if GrooveOnboardingFeatureFlags.usePremiumMagicResultFlow {
                    EmptyView()
                } else {
                    GrooveResultCTAViewV2(state: state, onNext: { advance() })
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal:   .move(edge: .leading)
                        ))
                }

            case 6:
                // TrialEnabledScreenV2 (v2 — 2.5s staged animation)
                TrialEnabledScreenV2(onNext: { advance() })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal:   .opacity
                    ))

            case 7:
                GroovePaywallScreenV2(
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

    private func advance(by step: Int = 1) {
        withAnimation(.interpolatingSpring(
            mass: 1.0, stiffness: 200, damping: 22, initialVelocity: 0
        )) {
            currentPage += step
        }
    }
}

// ─── Progress dots ────────────────────────────────────────────────────────────

private struct ProgressDotsV2: View {
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
