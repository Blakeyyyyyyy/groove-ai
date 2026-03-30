// GrooveDanceSelectView.swift
// PAGE 3 — Hero preview of selected subject + dance preset pills.
// Mirrors DemoFlowStep2View from Glow AI: typewriter → "Generating…" → crossfade result.

import SwiftUI

struct GrooveDanceSelectView: View {
    @ObservedObject var state: GrooveOnboardingState
    let onNext: () -> Void

    // ── UI state ──────────────────────────────────────────────────────────────
    @State private var selectedPreset:    GrooveDancePreset? = nil
    @State private var displayedPrompt:   String             = ""
    @State private var isGenerating:      Bool               = false
    @State private var didRevealResult:   Bool               = false

    @State private var showPromptOptions: Bool = true
    @State private var showPromptBox:     Bool = false
    @State private var showGeneratingLabel: Bool = false

    // Hero image animation
    @State private var heroAssetName:  String  = ""   // swapped on reveal
    @State private var imagePulse:     Bool     = false
    @State private var imageOpacity:   Double   = 1.0
    @State private var imageScale:     CGFloat  = 1.0

    // Typewriter
    @State private var cursorVisible:   Bool    = true
    @State private var typewriterTimer: Timer?
    @State private var cursorTimer:     Timer?

    var body: some View {
        ZStack {
            GrooveOnboardingTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Hero image ────────────────────────────────────────────────
                VStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 32)
                            .fill(Color.gray.opacity(0.15))
                            .frame(
                                width:  GrooveOnboardingTheme.heroImageSize.width  + 20,
                                height: GrooveOnboardingTheme.heroImageSize.height + 20
                            )
                            .blur(radius: 20)

                        heroContent
                            .frame(
                                width:  GrooveOnboardingTheme.heroImageSize.width,
                                height: GrooveOnboardingTheme.heroImageSize.height
                            )
                            .clipShape(RoundedRectangle(cornerRadius: GrooveOnboardingTheme.heroCornerRadius))
                            .shadow(
                                color: imagePulse
                                    ? GrooveOnboardingTheme.blueAccent.opacity(0.5)
                                    : .clear,
                                radius: 20
                            )
                            .scaleEffect(imagePulse ? 1.015 : imageScale)
                            .opacity(imageOpacity)
                            .animation(.easeInOut(duration: 0.8), value: imagePulse)
                    }
                    .frame(
                        width:  GrooveOnboardingTheme.heroImageSize.width,
                        height: GrooveOnboardingTheme.heroImageSize.height
                    )

                    if showGeneratingLabel {
                        Text("Generating…")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .transition(.opacity)
                    }
                }
                .padding(.top, GrooveOnboardingTheme.heroImageTopPadding)

                Spacer()

                // ── Bottom content ─────────────────────────────────────────────
                if !didRevealResult {
                    // State A / B — pre-selection & generating
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pick a dance")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                            Text("Tap to see it generate live.")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.6))
                        }

                        if showPromptOptions {
                            // Preset pills
                            HStack(spacing: 12) {
                                ForEach(GrooveDancePreset.allPresets) { preset in
                                    Button(action: { handlePresetTap(preset) }) {
                                        Text(preset.pillTitle)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.vertical, 14)
                                            .padding(.horizontal, 20)
                                            .frame(maxWidth: .infinity)
                                            .background(Color.white.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                            )
                                    }
                                    .disabled(selectedPreset != nil)
                                }
                            }
                            .transition(.opacity.combined(with: .scale))
                        } else if showPromptBox {
                            // Typewriter prompt box
                            HStack(alignment: .top, spacing: 0) {
                                (Text(displayedPrompt)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white)
                                + Text(cursorVisible && isGenerating ? "|" : "")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(GrooveOnboardingTheme.blueAccent))
                                .lineLimit(nil)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)

                                Spacer(minLength: 8)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 50)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(GrooveOnboardingTheme.blueAccent.opacity(0.5), lineWidth: 1)
                            )
                            .transition(.opacity.combined(with: .scale))
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, GrooveOnboardingTheme.ctaBottomPadding)

                } else {
                    // State C — done
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Text("Done ✨")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                            Text("Now try it on your own photo.")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }

                        Button(action: onNext) {
                            Text("Continue")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: GrooveOnboardingTheme.ctaButtonHeight)
                                .background(GrooveOnboardingTheme.blueAccent)
                                .clipShape(Capsule())
                                .shadow(
                                    color: GrooveOnboardingTheme.blueAccent.opacity(0.4),
                                    radius: 10, y: 5
                                )
                        }
                        .padding(.horizontal, GrooveOnboardingTheme.ctaHorizontalPadding)
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, GrooveOnboardingTheme.ctaBottomPadding)
                    .transition(.opacity)
                }
            }
        }
        .onAppear {
            heroAssetName = ""   // no asset yet — shows emoji placeholder
            startCursorBlink()
        }
        .onDisappear {
            typewriterTimer?.invalidate()
            cursorTimer?.invalidate()
        }
    }

    // ─── Hero content ─────────────────────────────────────────────────────────
    // Shows the subject emoji placeholder. Once you have real assets, swap to Image(heroAssetName).
    @ViewBuilder
    private var heroContent: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x1C1C2C), Color(hex: 0x0F0F18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if heroAssetName.isEmpty {
                // Placeholder — subject emoji
                Text(state.subjectEmoji())
                    .font(.system(size: 120))
            } else {
                Image(heroAssetName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
        }
    }

    // ─── Handlers ─────────────────────────────────────────────────────────────

    private func handlePresetTap(_ preset: GrooveDancePreset) {
        guard selectedPreset == nil else { return }
        selectedPreset = preset
        state.selectedDanceId = preset.id

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showPromptOptions = false
            showPromptBox     = true
            imagePulse        = true
        }

        startTypewriter(preset.promptText)

        let typewriterDuration = Double(preset.promptText.count) * 0.025
        DispatchQueue.main.asyncAfter(deadline: .now() + typewriterDuration) {
            startGenerating(preset)
        }
    }

    private func startTypewriter(_ text: String) {
        typewriterTimer?.invalidate()
        displayedPrompt = ""
        let chars = Array(text)
        var idx = 0
        typewriterTimer = Timer.scheduledTimer(withTimeInterval: 0.025, repeats: true) { t in
            if idx < chars.count {
                displayedPrompt.append(chars[idx])
                idx += 1
            } else {
                t.invalidate()
            }
        }
    }

    private func startGenerating(_ preset: GrooveDancePreset) {
        isGenerating = true
        withAnimation(.easeIn(duration: 0.2)) { showGeneratingLabel = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            revealResult(preset)
        }
    }

    private func revealResult(_ preset: GrooveDancePreset) {
        withAnimation(.easeOut(duration: 0.15)) { showGeneratingLabel = false }
        withAnimation(.easeOut(duration: 0.2))  { imagePulse = false }
        withAnimation(.easeInOut(duration: 0.2)) { imageOpacity = 0 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            // TODO: swap heroAssetName to the real generated video thumbnail
            imageScale = 1.01
            withAnimation(.easeOut(duration: 0.25))               { imageOpacity = 1 }
            withAnimation(.easeOut(duration: 0.18).delay(0.05))   { imageScale   = 1 }

            isGenerating    = false
            didRevealResult = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            withAnimation(.easeInOut(duration: 0.25).delay(0.1)) {
                showPromptBox = false
            }
        }
    }

    private func startCursorBlink() {
        cursorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            cursorVisible.toggle()
        }
    }
}
