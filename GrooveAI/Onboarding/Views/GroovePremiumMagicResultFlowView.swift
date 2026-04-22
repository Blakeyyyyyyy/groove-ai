// GroovePremiumMagicResultFlowView.swift
// PAGE 4 (premium flag) — Combined Loading + Reveal in one view

import SwiftUI
import AVKit

struct GroovePremiumMagicResultFlowView: View {
    @ObservedObject var state: GrooveOnboardingState
    let onNext: () -> Void

    @State private var progress: Double = 0.02
    @State private var displayPercent: Int = 0
    @State private var statusIndex: Int = 0
    @State private var decorationRotation: Double = 0
    @State private var loaderOpacity: Double = 1
    @State private var loaderScale: CGFloat = 1

    @State private var loadingComplete = false
    @State private var headlineVisible = false
    @State private var sublineVisible = false
    @State private var primaryCTAVisible = false

    @State private var player: AVPlayer?
    @State private var playerEndObserver: NSObjectProtocol?
    @State private var hasStarted = false

    private let statusMessages = [
        "Mapping the movement",
        "Adding your style",
        "Finishing touches"
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                backgroundLayer

                if !loadingComplete {
                    loadingLayer(in: geo)
                        .opacity(loaderOpacity)
                        .scaleEffect(loaderScale)
                } else {
                    revealLayer(in: geo)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .ignoresSafeArea()
        }
        .onAppear {
            guard !hasStarted else { return }
            hasStarted = true
            setupPlayer()
            startLoadingSequence()
        }
        .onDisappear {
            player?.pause()
            if let playerEndObserver {
                NotificationCenter.default.removeObserver(playerEndObserver)
                self.playerEndObserver = nil
            }
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if !loadingComplete {
                RadialGradient(
                    colors: [
                        GrooveOnboardingTheme.blueAccent.opacity(0.14),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 20,
                    endRadius: 280
                )
            }
        }
    }

    private func loadingLayer(in geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Spacer()

            progressRing

            Spacer().frame(height: 20)

            Text("\(displayPercent)%")
                .font(.system(size: 62, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
                .contentTransition(.numericText())

            Spacer().frame(height: 40)

            VStack(spacing: 8) {
                Text("Creating your video")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.94))

                Text(statusMessages[statusIndex])
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(GrooveOnboardingTheme.textSecondary)
                    .id(statusIndex)
                    .transition(.opacity)
            }

            Spacer()
        }
        .frame(width: geo.size.width, height: geo.size.height)
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), style: StrokeStyle(lineWidth: 6, lineCap: .round))

            Circle()
                .trim(from: 0, to: max(CGFloat(progress), 0.02))
                .stroke(
                    GrooveOnboardingTheme.blueAccent,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)
                .shadow(color: GrooveOnboardingTheme.blueAccent.opacity(0.5), radius: 8)
                .offset(y: -62)
                .rotationEffect(.degrees(decorationRotation))
        }
        .frame(width: 124, height: 124)
    }

    private func revealLayer(in geo: GeometryProxy) -> some View {
        let containerWidth = min(geo.size.width - 34, 350)
        let containerHeight = min(geo.size.height * 0.62, 560)
        let topPadding = max(geo.safeAreaInsets.top + 4, 16)

        return VStack(spacing: 0) {
            Spacer().frame(height: topPadding)

            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.white.opacity(0.03))

                if let player {
                    ControlledVideoView(player: player, gravity: .resizeAspectFill)
                        .frame(width: containerWidth - 12, height: containerHeight - 12)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
            }
            .frame(width: containerWidth, height: containerHeight)
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.32), radius: 24, y: 14)

            Spacer().frame(height: 28)

            VStack(spacing: 12) {
                Text("🎉 It's alive!")
                    .font(.system(size: 38, weight: .heavy))
                    .tracking(-0.5)
                    .foregroundColor(.white)
                    .opacity(headlineVisible ? 1 : 0)
                    .offset(y: headlineVisible ? 0 : 12)

                (Text("Now make ")
                    .foregroundColor(GrooveOnboardingTheme.textSecondary)
                 + Text("YOUR")
                    .foregroundColor(GrooveOnboardingTheme.textSecondary)
                    .fontWeight(.bold)
                 + Text(" photos dance")
                    .foregroundColor(GrooveOnboardingTheme.textSecondary))
                    .font(.system(size: 19, weight: .regular))
                    .multilineTextAlignment(.center)
                    .opacity(sublineVisible ? 1 : 0)
                    .offset(y: sublineVisible ? 0 : 8)
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 0)

            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onNext()
            }) {
                Text("Try yours →")
                    .font(.system(size: GrooveOnboardingTheme.ctaFontSize, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: GrooveOnboardingTheme.ctaButtonHeight)
                    .background(GrooveOnboardingTheme.blueAccent)
                    .clipShape(Capsule())
                    .shadow(color: GrooveOnboardingTheme.ctaShadow, radius: 12, y: 4)
            }
            .buttonStyle(CTAPressStyle())
            .padding(.horizontal, GrooveOnboardingTheme.ctaHorizontalPadding)
            .opacity(primaryCTAVisible ? 1 : 0)
            .offset(y: primaryCTAVisible ? 0 : 16)

            Spacer().frame(height: GrooveOnboardingTheme.ctaBottomPadding)
        }
    }

    private func startLoadingSequence() {
        withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
            decorationRotation = 360
        }

        let totalDuration: Double = 2.0
        let impactGenerator = UIImpactFeedbackGenerator(style: .rigid)
        impactGenerator.prepare()

        let startTime = CACurrentMediaTime()
        let hapticThresholds = [12, 26, 40, 56, 72, 88]
        var lastHapticIndex = -1

        let progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
            let elapsed = CACurrentMediaTime() - startTime
            let clamped = min(max(elapsed / totalDuration, 0), 1)

            let currentValue: Double
            if clamped < 0.45 {
                let t = clamped / 0.45
                let eased = 1 - pow(1 - t, 1.8)
                currentValue = 62 * eased
            } else if clamped < 0.80 {
                let t = (clamped - 0.45) / 0.35
                let eased = t * t * (3 - 2 * t)
                currentValue = 62 + (24 * eased)
            } else {
                let t = (clamped - 0.80) / 0.20
                let eased = 1 - pow(1 - t, 2.3)
                currentValue = 86 + (14 * eased)
            }

            let wholePercent = min(Int(currentValue.rounded(.down)), 100)
            progress = max(currentValue / 100, 0.02)

            if displayPercent != wholePercent {
                displayPercent = wholePercent
            }

            let newStatusIndex: Int
            switch currentValue {
            case ..<38: newStatusIndex = 0
            case ..<78: newStatusIndex = 1
            default: newStatusIndex = 2
            }
            if newStatusIndex != statusIndex {
                withAnimation(.easeInOut(duration: 0.2)) {
                    statusIndex = newStatusIndex
                }
            }

            if lastHapticIndex + 1 < hapticThresholds.count,
               wholePercent >= hapticThresholds[lastHapticIndex + 1] {
                impactGenerator.impactOccurred(intensity: 0.85)
                impactGenerator.prepare()
                lastHapticIndex += 1
            }

            if elapsed >= totalDuration {
                timer.invalidate()
                progress = 1.0
                displayPercent = 100
                transitionToReveal()
            }
        }
        RunLoop.main.add(progressTimer, forMode: .common)
    }

    private func transitionToReveal() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        withAnimation(.easeInOut(duration: 0.25)) {
            loaderOpacity = 0
            loaderScale = 0.92
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.75)) {
                loadingComplete = true
            }
            revealContent()
        }
    }

    private func revealContent() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        player?.seek(to: .zero)
        player?.play()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.3)) {
                headlineVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeOut(duration: 0.3)) {
                sublineVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.3)) {
                primaryCTAVisible = true
            }
        }
    }

    // MARK: - Demo Video Logic
    
    /// Returns the video URL to show on the reveal page
    /// - If subject is dog and we have a demo video for the preset → show demo video
    /// - If subject is person and we have a woman demo video for the preset → show demo video
    /// - Otherwise → show the generated video (or nil if not ready)
    private func getRevealVideoURL() -> String? {
        print("[REVEAL DEBUG] selectedSubjectId: \(state.selectedSubjectId)")
        print("[REVEAL DEBUG] selectedDanceId: \(state.selectedDanceId)")
        
        // If user selected dog subject and we have a matching demo video
        if state.selectedSubjectId == "dog",
           !state.selectedDanceId.isEmpty,
           let demoURL = DancePreset.dogDemoVideos[state.selectedDanceId] {
            print("[REVEAL DEBUG] Using DOG demo video: \(demoURL)")
            return demoURL
        }
        // If user selected person subject and we have a matching woman demo video
        if state.selectedSubjectId == "person",
           !state.selectedDanceId.isEmpty,
           let demoURL = DancePreset.womanDemoVideos[state.selectedDanceId] {
            print("[REVEAL DEBUG] Using WOMAN demo video: \(demoURL)")
            return demoURL
        }
        // Otherwise use the generated video URL
        print("[REVEAL DEBUG] Falling back to selectedVideoURL: \(state.selectedVideoURL ?? "NIL")")
        return state.selectedVideoURL
    }

    private func setupPlayer() {
        // Determine which video URL to use
        let videoURLString = getRevealVideoURL()
        print("[REVEAL DEBUG] setupPlayer called with URL: \(videoURLString ?? "NIL")")
        
        guard let videoURLString = videoURLString,
              let videoURL = URL(string: videoURLString) else { 
            print("[REVEAL DEBUG] Failed to create URL from string")
            return 
        }
        print("[REVEAL DEBUG] Created URL: \(videoURL)")

        let item = AVPlayerItem(url: videoURL)
        print("[REVEAL DEBUG] AVPlayerItem created: \(item)")
        
        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.isMuted = false
        avPlayer.actionAtItemEnd = .none
        avPlayer.pause()

        playerEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            avPlayer.seek(to: .zero)
            avPlayer.play()
        }

        player = avPlayer
        print("[REVEAL DEBUG] AVPlayer created and assigned")
    }
}
