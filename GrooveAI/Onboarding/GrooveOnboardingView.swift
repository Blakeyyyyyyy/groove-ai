// GrooveOnboardingView.swift
// Root coordinator for the Groove AI onboarding flow.
// 4-screen flow: Hero → Subject → Dance + Magic → Paywall
//
// Progress dots shown for pages 1–3 (hidden on paywall)

import SwiftUI

struct GrooveOnboardingView: View {
    let onComplete: () -> Void   // called when user finishes onboarding (→ main app)

    @StateObject private var state = GrooveOnboardingState()
    @State private var currentPage: Int = 1

    var body: some View {
        ZStack {
            GrooveOnboardingTheme.background.ignoresSafeArea()

            // Progress dots — rendered above all pages (hidden on paywall)
            if currentPage <= 3 {
                VStack {
                    ProgressDots(current: currentPage, total: 3)
                        .padding(.top, 54)
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
                        removal:   .move(edge: .leading)
                    ))

            case 4:
                GroovePaywallScreen(onComplete: onComplete)
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
