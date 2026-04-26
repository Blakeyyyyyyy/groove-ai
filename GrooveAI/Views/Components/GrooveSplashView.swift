// GrooveSplashView.swift
// Groove AI — Trio Trail Splash Screen
//
// Pixel-perfect animated splash: three dancer silhouettes fly in as a
// motion-trail trio, followed by a letter-by-letter wordmark build.
//
// Total runtime: 3.4s then onDismiss() is called.
//
// DROP-IN USAGE (unchanged from previous version):
//   GrooveSplashView { showSplash = false }
//
// REQUIRES: iOS 16+, DancerSilhouette image asset (template rendering)

import SwiftUI

// MARK: - Dancer Layer Config

private struct DancerConfig {
    /// Width as fraction of screen width
    let widthFraction: CGFloat
    /// White tint opacity (applied via foregroundColor)
    let tintOpacity: Double
    /// Final center-X as fraction of screen width
    let finalXFraction: CGFloat
    /// Entry animation delay (seconds from splash start)
    let entryDelay: Double
    /// Breath bob delay = entryDelay + 0.5 (entry duration)
    let breathDelay: Double
}

private let kDancers: [DancerConfig] = [
    DancerConfig(widthFraction: 0.66, tintOpacity: 0.22, finalXFraction: 0.28, entryDelay: 0.30, breathDelay: 0.80),
    DancerConfig(widthFraction: 0.74, tintOpacity: 0.48, finalXFraction: 0.42, entryDelay: 0.45, breathDelay: 0.95),
    DancerConfig(widthFraction: 0.82, tintOpacity: 1.00, finalXFraction: 0.56, entryDelay: 0.60, breathDelay: 1.10),
]

// Dancer image aspect ratio: 961 wide : 725 tall
private let kDancerAspect: CGFloat = 961.0 / 725.0

// MARK: - Single Dancer

private struct DancerView: View {
    let config: DancerConfig
    let screenSize: CGSize

    @State private var arrived = false
    @State private var breathOffset: CGFloat = 0
    @State private var visible = false

    private var width: CGFloat { screenSize.width * config.widthFraction }
    private var finalX: CGFloat { screenSize.width * config.finalXFraction }
    // Start fully off-screen left; we slide from there to finalX
    private var startXOffset: CGFloat { -(screenSize.width * config.finalXFraction + width / 2) }
    private var centerY: CGFloat { screenSize.height * 0.42 }

    var body: some View {
        Image("DancerSilhouette")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(kDancerAspect, contentMode: .fit)
            .frame(width: width)
            .foregroundColor(Color.white.opacity(config.tintOpacity))
            .offset(x: arrived ? 0 : startXOffset, y: breathOffset)
            .opacity(visible ? 1 : 0)
            .position(x: finalX, y: centerY)
            .onAppear { scheduleEntry() }
    }

    private func scheduleEntry() {
        // Kick off entry slide after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + config.entryDelay) {
            visible = true
            withAnimation(.timingCurve(0.0, 0.0, 0.2, 1.0, duration: 0.5)) {
                arrived = true
            }
        }
        // Start breath bob after entry finishes
        DispatchQueue.main.asyncAfter(deadline: .now() + config.breathDelay) {
            withAnimation(.easeInOut(duration: 1.745).repeatForever(autoreverses: true)) {
                breathOffset = -4
            }
        }
    }
}

// MARK: - Main Splash View

struct GrooveSplashView: View {
    var onDismiss: () -> Void

    // Wordmark characters including space
    private let wordmarkChars: [String] = Array("Groove AI").map { String($0) }

    // ── Wordmark letter animation (0→1 drives all chars)
    @State private var wordmarkProgress: Double = 0

    // ── Tagline
    @State private var taglineOpacity: Double = 0
    @State private var taglineOffsetY: CGFloat = 8

    // ── Global fade-out
    @State private var globalOpacity: Double = 1.0

    // ── Gradient stops
    private let gradTop    = Color(red: 0.494, green: 0.333, blue: 0.627) // #7E55A0
    private let gradMid    = Color(red: 0.431, green: 0.275, blue: 0.541) // #6E468A
    private let gradBottom = Color(red: 0.353, green: 0.212, blue: 0.455) // #5A3674

    var body: some View {
        GeometryReader { geo in
            let sz = geo.size
            ZStack {
                // ── Solid fallback so nothing is ever transparent ──────────
                gradTop.ignoresSafeArea()

                // ── Purple gradient background (always visible) ───────────
                LinearGradient(
                    stops: [
                        .init(color: gradTop,    location: 0.00),
                        .init(color: gradMid,    location: 0.60),
                        .init(color: gradBottom, location: 1.00),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // ── Dancer trio (back → front) ────────────────────────────
                // Only rendered when we have real dimensions
                if sz.width > 0 && sz.height > 0 {
                    ForEach(kDancers.indices, id: \.self) { i in
                        DancerView(config: kDancers[i], screenSize: sz)
                    }
                }

                // ── Wordmark + tagline ────────────────────────────────────
                VStack(spacing: 12) {
                    // Letter-by-letter wordmark
                    HStack(spacing: 0) {
                        ForEach(Array(wordmarkChars.enumerated()), id: \.offset) { idx, ch in
                            let p = sliceProgress(idx: idx, total: wordmarkChars.count, overall: wordmarkProgress)
                            Text(ch)
                                .font(.system(size: 48, weight: .heavy, design: .default))
                                .kerning(-1.44)          // 48pt * -0.03
                                .foregroundColor(.white)
                                .opacity(p)
                                .offset(y: (1.0 - p) * 26)
                                .scaleEffect(
                                    x: 0.7 + 0.3 * p,
                                    y: 0.7 + 0.3 * p,
                                    anchor: .bottom
                                )
                                // easeOutBack curve per character
                                .animation(
                                    .timingCurve(0.34, 1.56, 0.64, 1.0,
                                                 duration: 0.8 / Double(wordmarkChars.count)),
                                    value: p
                                )
                        }
                    }

                    // Tagline
                    Text("FIND YOUR RHYTHM")
                        .font(.system(size: 15, weight: .semibold, design: .default))
                        .kerning(0.9)                   // 15pt * 0.06
                        .foregroundColor(Color.white.opacity(0.78))
                        .opacity(taglineOpacity)
                        .offset(y: taglineOffsetY)
                }
                // Bottom of group sits 14% from bottom edge
                .position(x: sz.width * 0.5,
                          y: sz.height - sz.height * 0.14 - 44)
            }
            .clipped()
        }
        .opacity(globalOpacity)
        .ignoresSafeArea()
        .onAppear { runTimeline() }
    }

    // MARK: - Helpers

    /// Returns 0→1 progress for a single character's slice of the total window
    private func sliceProgress(idx: Int, total: Int, overall: Double) -> Double {
        guard total > 1 else { return overall }
        let slice = 1.0 / Double(total)
        let start = Double(idx) * slice
        return max(0, min(1, (overall - start) / slice))
    }

    // MARK: - Timeline (total 3.4s)

    private func runTimeline() {
        // Dancers are handled by DancerView.onAppear internally.

        // 1.20s — start wordmark letter-by-letter (animates over 0.80s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.20) {
            withAnimation(.linear(duration: 0.80)) {
                wordmarkProgress = 1.0
            }
        }

        // 1.60s — tagline fade in (over 0.60s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.60) {
            withAnimation(.easeOut(duration: 0.60)) {
                taglineOpacity  = 1.0
                taglineOffsetY  = 0
            }
        }

        // 3.20s — fade out entire view (over 0.20s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.20) {
            withAnimation(.linear(duration: 0.20)) {
                globalOpacity = 0
            }
        }

        // 3.40s — dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.40) {
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
