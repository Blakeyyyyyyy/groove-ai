// GrooveMagicMomentView.swift
// PAGE 4 — Live demo generation (The Magic Moment)
// Per spec: blurred content visualization, circular progress ring with gradient,
// large percentage counter, rotating subtext, ghost back button
// This is a SIMULATED loading — auto-advances after ~4 seconds

import SwiftUI

struct GrooveMagicMomentViewV2: View {
    @ObservedObject var state: GrooveOnboardingState
    let onNext: () -> Void

    @State private var progress: Double = 0
    @State private var displayPercent: Int = 0
    @State private var subtextIndex: Int = 0
    @State private var ringRotation: Double = 0
    @State private var appeared = false

    private let subtexts = [
        "AI is learning your moves",
        "Mixing beats + motion",
        "Almost ready..."
    ]

    var body: some View {
        ZStack {
            GrooveOnboardingTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Blurred visualization area (top) ───────────────────────────
                ZStack {
                    // Subject image blurred + tinted
                    RemoteVideoThumbnail(urlString: demoThumbnailURL, cornerRadius: 0)
                        .blur(radius: 20)
                        .overlay(GrooveOnboardingTheme.blueAccent.opacity(0.20))

                    // Animated shimmer sweep
                    ShimmerOverlay()

                    // Bottom gradient fade into background
                    VStack {
                        Spacer()
                        LinearGradient(
                            colors: [Color.clear, GrooveOnboardingTheme.background],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 60)
                    }
                }
                .frame(height: 200)
                .clipped()
                .opacity(appeared ? 1 : 0)
                .animation(.easeIn(duration: 0.2), value: appeared)

                Spacer().frame(height: 40)

                // ── Circular progress ring ─────────────────────────────────────
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 6)
                        .frame(width: 80, height: 80)

                    // Foreground gradient ring
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: 0x3D7FFF),
                                    Color(hex: 0x9B5CF6),
                                    Color(hex: 0x3D7FFF)
                                ]),
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(ringRotation - 90))
                }
                .scaleEffect(appeared ? 1.0 : 0.8)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: appeared)

                Spacer().frame(height: 16)

                // ── Large percentage number ────────────────────────────────────
                Text("\(displayPercent)%")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: displayPercent)

                Spacer().frame(height: 24)

                // ── Label ──────────────────────────────────────────────────────
                Text("Creating your video...")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(GrooveOnboardingTheme.textSecondary)

                Spacer().frame(height: 12)

                // ── Rotating subtext ───────────────────────────────────────────
                Text(subtexts[subtextIndex])
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(GrooveOnboardingTheme.textTertiary)
                    .id(subtextIndex)
                    .transition(.opacity)

                Spacer()
            }
        }
        .onAppear {
            appeared = true
            startSimulation()
            startRingRotation()
            startSubtextCycle()
        }
    }

    private var demoThumbnailURL: String {
        let r2Base = "https://videos.trygrooveai.com/presets"
        if let preset = DancePreset.allPresets.first(where: { $0.id == state.selectedDanceId }),
           let url = preset.videoURL {
            return url
        }
        return "\(r2Base)/big-guy-V5-AI.mp4"
    }

    // ── Simulated progress ─────────────────────────────────────────────────────

    private func startSimulation() {
        // Total duration: 3.2 seconds — sweet spot between snappy and natural.
        // 3-phase easing: fast start (excitement) → slow middle (feels like real work) → accelerate to 100 (satisfying finish)
        let totalDuration: Double = 3.2

        // Phase 1: 0→30% in 0.7s (fast, builds excitement)
        // Phase 2: 30→75% in 1.5s (slow, feels like processing)
        // Phase 3: 75→100% in 1.0s (accelerates to satisfying finish)
        let phase1End: Double = 0.30
        let phase1Duration: Double = 0.7
        let phase2End: Double = 0.75
        let phase2Duration: Double = 1.5
        let phase3Duration: Double = 1.0

        let hapticGen = UIImpactFeedbackGenerator(style: .light)
        hapticGen.prepare()

        // Use a single DisplayLink-style timer for smooth number counting.
        // We map elapsed time → percent using a custom 3-phase curve.
        let startTime = CACurrentMediaTime()
        var lastHapticPercent = 0

        // Animate the ring with matching 3-phase curve via keyframes
        // Phase 1
        withAnimation(.easeOut(duration: phase1Duration)) {
            progress = phase1End
        }
        // Phase 2
        DispatchQueue.main.asyncAfter(deadline: .now() + phase1Duration) {
            withAnimation(.easeInOut(duration: phase2Duration)) {
                progress = phase2End
            }
        }
        // Phase 3
        DispatchQueue.main.asyncAfter(deadline: .now() + phase1Duration + phase2Duration) {
            withAnimation(.easeIn(duration: phase3Duration)) {
                progress = 1.0
            }
        }

        // Smooth number counter driven by elapsed time → custom easing curve
        let counterTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { timer in
            let elapsed = CACurrentMediaTime() - startTime
            let percent: Int

            if elapsed <= phase1Duration {
                // Phase 1: ease-out (fast then slowing) 0→30
                let t = min(elapsed / phase1Duration, 1.0)
                let eased = 1.0 - pow(1.0 - t, 2.0) // ease-out quad
                percent = Int(eased * 30.0)
            } else if elapsed <= phase1Duration + phase2Duration {
                // Phase 2: ease-in-out (slow middle) 30→75
                let t = min((elapsed - phase1Duration) / phase2Duration, 1.0)
                let eased = t < 0.5 ? 2.0 * t * t : 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0 // ease-in-out quad
                percent = 30 + Int(eased * 45.0)
            } else if elapsed <= totalDuration {
                // Phase 3: ease-in (accelerates to finish) 75→100
                let t = min((elapsed - phase1Duration - phase2Duration) / phase3Duration, 1.0)
                let eased = t * t // ease-in quad
                percent = 75 + Int(eased * 25.0)
            } else {
                percent = 100
            }

            let clamped = min(percent, 100)
            if clamped != displayPercent {
                displayPercent = clamped
                // Haptic ratchet tick every 4% — natural rhythm without buzzing
                if displayPercent - lastHapticPercent >= 4 {
                    hapticGen.impactOccurred()
                    lastHapticPercent = displayPercent
                }
            }

            if clamped >= 100 {
                timer.invalidate()
            }
        }
        RunLoop.main.add(counterTimer, forMode: .common)

        // Complete: success haptic + advance
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration + 0.15) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                onNext()
            }
        }
    }

    private func startRingRotation() {
        // Continuous rotation — smooth spin over 3.2s duration
        withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }
    }

    private func startSubtextCycle() {
        // Cycle through subtexts every 1.0s to fit 3.2s window
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            withAnimation(.easeInOut(duration: 0.4)) {
                subtextIndex = (subtextIndex + 1) % subtexts.count
            }
            if displayPercent >= 100 {
                timer.invalidate()
            }
        }
    }
}

// ─── Shimmer overlay ─────────────────────────────────────────────────────────

private struct ShimmerOverlay: View {
    @State private var offset: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [
                    Color.white.opacity(0),
                    Color.white.opacity(0.06),
                    Color.white.opacity(0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.5)
            .offset(x: offset * geo.size.width)
        }
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                offset = 1.5
            }
        }
    }
}
