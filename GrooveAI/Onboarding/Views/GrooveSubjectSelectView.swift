import SwiftUI

private struct SubjectOption: Identifiable {
    let id: String
}

private let subjectOptions: [SubjectOption] = [
    SubjectOption(id: "person"),
    SubjectOption(id: "dog")
]

struct GrooveSubjectSelectView: View {
    @ObservedObject var state: GrooveOnboardingState
    let onNext: () -> Void

    @State private var cardsAppeared = false
    @State private var tapped = false
    @State private var showTapHint = false
    @State private var borderPulse = false

    var body: some View {
        ZStack {
            GrooveOnboardingTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 96)

                VStack(spacing: 8) {
                    Text("Who's dancing?")
                        .font(.system(size: 34, weight: .bold))
                        .tracking(-0.5)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .opacity(cardsAppeared ? 1 : 0)

                    Text("Choose your subject")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(GrooveOnboardingTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .opacity(cardsAppeared ? 1 : 0)
                }
                .padding(.horizontal, 30)

                Spacer().frame(height: 28)

                GeometryReader { geometry in
                    let cardSpacing: CGFloat = 16
                    let cardWidth = floor((geometry.size.width - cardSpacing) / 2)

                    HStack(spacing: cardSpacing) {
                        ForEach(Array(subjectOptions.enumerated()), id: \.element.id) { index, option in
                            SubjectCard(
                                subjectId: option.id,
                                isSelected: state.selectedSubjectId == option.id,
                                borderPulse: borderPulse
                            ) {
                                handleSelect(option)
                            }
                            .frame(width: cardWidth)
                            .offset(y: cardsAppeared ? 0 : 24)
                            .opacity(cardsAppeared ? 1 : 0)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.8)
                                    .delay(Double(index) * 0.07),
                                value: cardsAppeared
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .frame(height: 352)
                .padding(.horizontal, 20)

                // Tap hint — appears after 1.5s, disappears on tap
                TapHintView()
                    .opacity(showTapHint && !tapped ? 1 : 0)
                    .animation(.easeInOut(duration: 0.35), value: tapped)
                    .padding(.top, 20)

                Spacer()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                cardsAppeared = true
            }
            withAnimation(.easeIn(duration: 0.3)) {
                showTapHint = true
            }
            // Start border pulse loop immediately
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                startBorderPulseLoop()
            }
        }
    }

    private func startBorderPulseLoop() {
        guard !tapped else { return }
        withAnimation(.easeInOut(duration: 0.6)) {
            borderPulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeInOut(duration: 0.6)) {
                borderPulse = false
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            startBorderPulseLoop()
        }
    }

    private func handleSelect(_ option: SubjectOption) {
        tapped = true
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            state.selectedSubjectId = option.id

            // Capture the preview image when subject is selected
            let imageName = option.id == "person" ? "subject-person-1" : "subject-pet"
            state.selectedPreviewImage = UIImage(named: imageName)
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onNext()
        }
    }
}

// MARK: - Tap Hint

private struct TapHintView: View {
    @State private var pulseOpacity: Double = 0.4

    var body: some View {
        HStack(spacing: 6) {
            Text("👆")
                .font(.system(size: 18))
            Text("Tap a photo to begin")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .opacity(pulseOpacity)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.9)
                    .repeatForever(autoreverses: true)
            ) {
                pulseOpacity = 1.0
            }
        }
    }
}

// MARK: - Subject Card

private struct SubjectCard: View {
    let subjectId: String
    let isSelected: Bool
    let borderPulse: Bool
    let onTap: () -> Void

    var body: some View {
        let imageName = subjectId == "person" ? "subject-person-1" : "subject-pet"

        return Button(action: onTap) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(GrooveOnboardingTheme.surfaceL1)
                .overlay {
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .frame(maxWidth: .infinity)
                .frame(height: 332)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            isSelected
                                ? GrooveOnboardingTheme.blueAccent
                                : Color.white.opacity(borderPulse ? 0.55 : 0.08),
                            lineWidth: isSelected ? 2 : (borderPulse ? 1.5 : 1)
                        )
                        .animation(.easeInOut(duration: 0.3), value: borderPulse)
                )
                .shadow(
                    color: isSelected ? GrooveOnboardingTheme.blueAccent.opacity(0.18) : .clear,
                    radius: 14
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.01 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isSelected)
    }
}
