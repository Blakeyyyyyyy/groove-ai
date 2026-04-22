// GrooveMagicMomentView.swift
// PAGE 4 — Loading screen: simulated AI processing
// Redesigned: dark bg with blurred subject emoji, 124pt circular progress ring (blue #3D7FFF),
// percentage counter (0→100%), rotating decoration dot,
// cycling status messages per spec, auto-advance on completion.

import SwiftUI

struct GrooveMagicMomentView: View {
    @ObservedObject var state: GrooveOnboardingState
    let onNext: () -> Void

    @State private var progress: Double = 0
    @State private var displayPercent: Int = 0
    @State private var statusIndex: Int = 0
    @State private var decorationRotation: Double = 0
    @State private var appeared = false

    private let statusMessages = [
        "Mapping the movement",
        "Adding your style",
        "Finishing touches"
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ── Background: blurred subject photo ──────────────────────────
                backgroundLayer(in: geo)

                VStack(spacing: 0) {
                    Spacer()

                    // ── 124pt circular progress ring ───────────────────────────
                    progressRing
                        .scaleEffect(appeared ? 1.0 : 0.8)
                        .animation(.spring(response: 0.38, dampingFraction: 0.75), value: appeared)

                    Spacer().frame(height: 20)

                    // ── Percentage counter ──────────────────────────────────────
                    Text("\(displayPercent)%")
                        .font(.system(size: 62, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.15), value: displayPercent)

                    Spacer().frame(height: 40)

                    // ── Cycling status messages ────────────────────────────────
                    Text(statusMessages[statusIndex])
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(GrooveOnboardingTheme.textSecondary)
                        .id(statusIndex)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: statusIndex)

                    Spacer()
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            appeared = true
            startSimulation()
            startDecorationRotation()
            startStatusCycle()
        }
    }

    // MARK: - Background

    @ViewBuilder
    private func backgroundLayer(in geo: GeometryProxy) -> some View {
        ZStack {
            GrooveOnboardingTheme.background.ignoresSafeArea()

            // Blurred subject preview
            if let url = state.selectedPreviewURL {
                RemoteVideoThumbnail(urlString: url, cornerRadius: 0)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .blur(radius: 22)
                    .overlay(Color.black.opacity(0.5))
            }

            // Subtle blue radial glow
            RadialGradient(
                colors: [
                    GrooveOnboardingTheme.blueAccent.opacity(0.15),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 300
            )
        }
    }

    // MARK: - Progress Ring (124pt)

    private var progressRing: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.10), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 124, height: 124)

            // Foreground progress ring (solid blue)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    GrooveOnboardingTheme.blueAccent,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 124, height: 124)
                .rotationEffect(.degrees(-90))

            // Rotating decoration dot on ring edge
            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)
                .shadow(color: GrooveOnboardingTheme.blueAccent.opacity(0.5), radius: 8)
                .offset(y: -62) // radius of ring
                .rotationEffect(.degrees(decorationRotation))
        }
        .frame(width: 124, height: 124)
    }

    // MARK: - Simulation

    private func startSimulation() {
        let totalDuration: Double = 2.8

        // Phase 1: 0→30% in 0.6s (fast start)
        let phase1Duration: Double = 0.6
        // Phase 2: 30→75% in 1.3s (slow middle)
        let phase2Duration: Double = 1.3
        // Phase 3: 75→100% in 0.9s (accelerate finish)
        let phase3Duration: Double = 0.9

        let hapticGen = UIImpactFeedbackGenerator(style: .light)
        hapticGen.prepare()

        let startTime = CACurrentMediaTime()
        var lastHapticPercent = 0

        // Animate ring phases
        withAnimation(.easeOut(duration: phase1Duration)) {
            progress = 0.30
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + phase1Duration) {
            withAnimation(.easeInOut(duration: phase2Duration)) {
                progress = 0.75
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + phase1Duration + phase2Duration) {
            withAnimation(.easeIn(duration: phase3Duration)) {
                progress = 1.0
            }
        }

        // Smooth number counter
        let counterTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { timer in
            let elapsed = CACurrentMediaTime() - startTime
            let percent: Int

            if elapsed <= phase1Duration {
                let t = min(elapsed / phase1Duration, 1.0)
                let eased = 1.0 - pow(1.0 - t, 2.0)
                percent = Int(eased * 30.0)
            } else if elapsed <= phase1Duration + phase2Duration {
                let t = min((elapsed - phase1Duration) / phase2Duration, 1.0)
                let eased = t < 0.5 ? 2.0 * t * t : 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0
                percent = 30 + Int(eased * 45.0)
            } else if elapsed <= totalDuration {
                let t = min((elapsed - phase1Duration - phase2Duration) / phase3Duration, 1.0)
                let eased = t * t
                percent = 75 + Int(eased * 25.0)
            } else {
                percent = 100
            }

            let clamped = min(percent, 100)
            if clamped != displayPercent {
                displayPercent = clamped
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

        // Auto-advance on completion
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration + 0.15) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                onNext()
            }
        }
    }

    private func startDecorationRotation() {
        withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
            decorationRotation = 360
        }
    }

    private func startStatusCycle() {
        Timer.scheduledTimer(withTimeInterval: 1.1, repeats: true) { timer in
            withAnimation(.easeInOut(duration: 0.2)) {
                statusIndex = (statusIndex + 1) % statusMessages.count
            }
            if displayPercent >= 100 {
                timer.invalidate()
            }
        }
    }
}
