// GrooveOnboardingView.swift
// Root coordinator for the Groove AI onboarding flow.

import SwiftUI

struct GrooveOnboardingView: View {
    let onComplete: () -> Void

    @StateObject private var state = GrooveOnboardingState()
    @State private var currentPage: Int = 1

    private var progressStep: Int? {
        switch currentPage {
        case 2: return 1
        case 3: return 2
        default: return nil
        }
    }

    var body: some View {
        ZStack {
            GrooveOnboardingTheme.background.ignoresSafeArea()

            if let progressStep {
                VStack {
                    ProgressDots(current: progressStep, total: 3)
                        .padding(.top, 72)
                    Spacer()
                }
                .zIndex(10)
            }

            switch currentPage {
            case 1:
                GrooveHeroScrollView(onNext: { advance() })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))

            case 2:
                GrooveSubjectSelectView(state: state, onNext: { advance() })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))

            case 3:
                GrooveDanceSelectView(state: state, onNext: { advance() })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .opacity
                    ))

            case 4:
                if GrooveOnboardingFeatureFlags.usePremiumMagicResultFlow {
                    GroovePremiumMagicResultFlowView(state: state, onNext: { advance(by: 2) })
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    GrooveMagicMomentView(state: state, onNext: { advance() })
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .move(edge: .bottom)
                        ))
                }

            case 5:
                if GrooveOnboardingFeatureFlags.usePremiumMagicResultFlow {
                    EmptyView()
                } else {
                    GrooveResultCTAView(state: state, onNext: { advance() })
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .leading)
                        ))
                }

            case 6:
                TrialEnabledScreen(onNext: { advance() })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .opacity
                    ))

            case 7:
                GroovePaywallScreen(
                    onPurchaseSuccess: onComplete,
                    onDismiss: onComplete
                )
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .move(edge: .leading)
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

private struct ProgressDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...total, id: \.self) { index in
                Capsule()
                    .fill(index == current ? GrooveOnboardingTheme.blueAccent : Color.white.opacity(0.25))
                    .frame(width: index == current ? 20 : 6, height: 6)
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: current)
            }
        }
    }
}
