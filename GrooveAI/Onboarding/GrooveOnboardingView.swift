// GrooveOnboardingView.swift
// Root coordinator for the Groove AI onboarding flow.
// Drop this in as the onboarding entry point (replacing OnboardingView.swift).
//
// Flow:
//   1. GrooveHeroScrollView  — dual scroll rows + CTA
//   2. GrooveSubjectSelectView — Dog / Person cards
//   3. GrooveDanceSelectView   — pick dance, typewriter, generation
//   4. GrooveResultView        — share / create another
//
// Progress dots (matching Glow AI style) are rendered inside each page.

import SwiftUI

struct GrooveOnboardingView: View {
    let onComplete: () -> Void   // called when user finishes onboarding (→ main app)

    @StateObject private var state = GrooveOnboardingState()
    @State private var currentPage: Int = 1

    var body: some View {
        ZStack {
            GrooveOnboardingTheme.background.ignoresSafeArea()

            // Progress dots — rendered above all pages
            VStack {
                ProgressDots(current: currentPage, total: 4)
                    .padding(.top, 54)
                Spacer()
            }
            .zIndex(10)

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
                        removal:   .move(edge: .leading)
                    ))

            case 4:
                GrooveResultView(
                    state: state,
                    onComplete: onComplete,
                    onCreateAnother: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            currentPage = 2
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal:   .move(edge: .leading)
                ))

            default:
                EmptyView()
            }
        }
    }

    private func advance() {
        withAnimation(.easeInOut(duration: 0.35)) {
            currentPage += 1
        }
    }
}

// ─── Progress dots ────────────────────────────────────────────────────────────

private struct ProgressDots: View {
    let current: Int
    let total:   Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...total, id: \.self) { i in
                Capsule()
                    .fill(
                        i == current
                            ? GrooveOnboardingTheme.blueAccent
                            : Color.white.opacity(0.25)
                    )
                    .frame(width: i == current ? 20 : 6, height: 6)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: current)
            }
        }
    }
}
