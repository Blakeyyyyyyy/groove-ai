// GrooveSplashView.swift
// Groove AI — Launch / Splash Screen
//
// Choreographed 1.5-second brand motion sequence.
// Not a loop — a signature moment.
//
// DROP-IN USAGE:
//   @State private var showSplash = true
//
//   if showSplash {
//       GrooveSplashView { showSplash = false }
//           .transition(.opacity)
//   } else {
//       GrooveOnboardingView()
//   }
//
// REQUIRES: iOS 16+

import SwiftUI

// MARK: - Splash View

struct GrooveSplashView: View {

    var onDismiss: () -> Void

    // ── Dancer states ─────────────────────────────────────────────────────
    @State private var dancerOpacity: Double  = 0
    @State private var dancerScale: Double    = 0.88
    @State private var dancerOffsetX: CGFloat = 0
    @State private var dancerOffsetY: CGFloat = 14   // starts slightly below centre
    @State private var dancerRotation: Double = 0

    // ── Wordmark states ───────────────────────────────────────────────────
    @State private var wordmarkOpacity: Double  = 0
    @State private var wordmarkOffsetY: CGFloat = 7
    @State private var wordmarkScale: Double    = 0.94

    // ── Dismiss state ─────────────────────────────────────────────────────
    @State private var isDismissing: Bool = false

    // ── Design tokens ─────────────────────────────────────────────────────
    private let bgColor          = Color(red: 0.929, green: 0.910, blue: 1.0)   // #EDE8FF
    private let gradientTop      = Color(red: 0.608, green: 0.427, blue: 1.0)   // #9B6DFF
    private let gradientBottom   = Color(red: 0.776, green: 0.557, blue: 1.0)   // #C68EFF
    private let wordmarkColor    = Color(red: 0.478, green: 0.365, blue: 0.690) // #7A5DB0

    // MARK: - Body

    var body: some View {
        ZStack {

            // Background
            bgColor.ignoresSafeArea()

            VStack(spacing: 18) {

                // ── Dancer icon ───────────────────────────────────────────
                Image(systemName: "figure.dance")
                    .font(.system(size: 72, weight: .thin))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [gradientTop, gradientBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(dancerScale)
                    .rotationEffect(.degrees(dancerRotation))
                    .offset(x: dancerOffsetX, y: dancerOffsetY)
                    .opacity(dancerOpacity)

                // ── Wordmark ──────────────────────────────────────────────
                // Confident entrance: medium weight, full opacity, tight spring
                Text("groove")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(wordmarkColor)
                    .tracking(5)
                    .opacity(wordmarkOpacity)
                    .offset(y: wordmarkOffsetY)
                    .scaleEffect(wordmarkScale)
            }
        }
        // Global fade-out for dismiss
        .opacity(isDismissing ? 0 : 1)
        .animation(.easeOut(duration: 0.25), value: isDismissing)
        .onAppear { runChoreography() }
    }

    // MARK: - Choreography

    /// One clean motion sequence. No loops. Total visible runtime: ~1.6s.
    ///
    /// Timeline:
    ///   0.00–0.30s  Phase 1 — Dancer enters: fade in, scale up, drift up, sway right
    ///   0.30–0.55s  Phase 2 — Sway left + lean left (-2°)
    ///   0.55–0.80s  Phase 3 — Tiny bounce up + lean right (+2°), settle back to centre X
    ///   0.80–1.05s  Phase 4 — Settle neutral + wordmark slides up into place
    ///   1.05–1.35s  Hold final pose
    ///   1.35–1.60s  Whole view fades out → onDismiss
    private func runChoreography() {

        // ── Phase 1 (0.00s): Enter with upward drift + sway right ─────────
        withAnimation(.spring(response: 0.38, dampingFraction: 0.70)) {
            dancerOpacity  = 1.0
            dancerScale    = 1.0
            dancerOffsetY  = 0
            dancerOffsetX  = 5       // nudge right — opening sway
        }

        // ── Phase 2 (0.30s): Sway left + lean left ────────────────────────
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            withAnimation(.easeInOut(duration: 0.25)) {
                dancerOffsetX  = -5
                dancerRotation = -2.5
            }
        }

        // ── Phase 3 (0.55s): Bounce up + lean right + return to centre X ──
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeInOut(duration: 0.25)) {
                dancerOffsetX  = 2
                dancerOffsetY  = -3  // subtle bounce
                dancerRotation = 2.0
            }
        }

        // ── Phase 4 (0.80s): Settle neutral + wordmark enters ─────────────
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.80) {

            // Dancer settles with a slight overshoot (springy feel)
            withAnimation(.spring(response: 0.32, dampingFraction: 0.62)) {
                dancerOffsetX  = 0
                dancerOffsetY  = 0
                dancerRotation = 0
            }

            // Wordmark slides up and snaps into confidence
            withAnimation(.spring(response: 0.36, dampingFraction: 0.72)) {
                wordmarkOpacity  = 1.0
                wordmarkOffsetY  = 0
                wordmarkScale    = 1.0
            }
        }

        // ── Phase 5 (1.35s): Fade out whole view ─────────────────────────
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
            isDismissing = true
        }

        // ── Dismiss callback (after fade completes) ────────────────────────
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.65) {
            onDismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    GrooveSplashView {
        print("Splash dismissed")
    }
}


// MARK: - Integration Example
//
// struct ContentView: View {
//     @State private var splashDone = false
//
//     var body: some View {
//         ZStack {
//             if !splashDone {
//                 GrooveSplashView {
//                     withAnimation(.easeInOut(duration: 0.4)) {
//                         splashDone = true
//                     }
//                 }
//                 .zIndex(1)
//                 .transition(.opacity)
//             } else {
//                 GrooveOnboardingView()
//                     .transition(.opacity)
//             }
//         }
//     }
// }
