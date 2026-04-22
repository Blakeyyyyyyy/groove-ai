import SwiftUI
import AVFoundation

// MARK: - Screen 2: Subject Picker (Redesigned)
// Two hero cards side-by-side. Tap → spring → auto-advance after 350ms. No Next button.
struct SubjectPickerView: View {
    @Binding var selectedSubject: OnboardingSubject?
    let onContinue: () -> Void

    @State private var showCards = false
    @State private var isAdvancing = false

    private let subjects = OnboardingSubject.pickerSubjects // [.pet, .myself]

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 72)

            // Progress dots
            PageIndicatorDots(count: 4, current: 1)
                .padding(.bottom, Spacing.xl)

            // Headline
            Text("Who's the star?")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .padding(.bottom, Spacing.xxxl)

            // Side-by-side cards
            HStack(spacing: 12) {
                ForEach(Array(subjects.enumerated()), id: \.element.id) { index, subject in
                    SubjectHeroCard(
                        subject: subject,
                        isSelected: selectedSubject == subject,
                        isDisabled: isAdvancing,
                        onTap: {
                            guard !isAdvancing else { return }
                            isAdvancing = true
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                                selectedSubject = subject
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                onContinue()
                            }
                        }
                    )
                    .frame(width: 167, height: 240)
                    .offset(y: showCards ? 0 : 30)
                    .opacity(showCards ? 1 : 0)
                    .animation(
                        AppAnimation.cardTransition.delay(Double(index) * 0.1),
                        value: showCards
                    )
                }
            }

            Spacer()
        }
        .background(Color.bgPrimary)
        .onAppear {
            isAdvancing = false
            withAnimation(AppAnimation.cardTransition.delay(0.15)) {
                showCards = true
            }
        }
    }
}

// MARK: - Subject Hero Card
private struct SubjectHeroCard: View {
    let subject: OnboardingSubject
    let isSelected: Bool
    let isDisabled: Bool
    let onTap: () -> Void

    @State private var videoURL: URL?
    @State private var pressed = false

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottom) {
                // Background — video loop or gradient fallback
                Group {
                    if let url = videoURL {
                        LoopingVideoView(url: url, gravity: .resizeAspectFill)
                    } else {
                        subjectGradientBackground
                    }
                }
                .clipped()

                // Bottom gradient scrim
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.15),
                        Color.black.opacity(0.72)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Label
                Text(subject.displayName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.bottom, 16)
                    .padding(.horizontal, 8)
            }
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl)
                .stroke(
                    isSelected ? Color.white : Color.white.opacity(0.08),
                    lineWidth: isSelected ? 2.5 : 1
                )
        )
        .shadow(
            color: isSelected ? Color.accentStart.opacity(0.4) : Color.black.opacity(0.3),
            radius: isSelected ? 16 : 8,
            y: isSelected ? 6 : 3
        )
        .scaleEffect(scaleValue)
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: isSelected)
        .onAppear {
            videoURL = Bundle.main.url(forResource: subject.tileVideoName, withExtension: "mp4")
        }
        // Pressed state
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.08)) { pressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.15)) { pressed = false }
                }
        )
    }

    private var scaleValue: CGFloat {
        if pressed { return 0.96 }
        if isSelected { return 1.05 }
        return 1.0
    }

    /// Fallback gradient background when video isn't in bundle yet
    @ViewBuilder
    private var subjectGradientBackground: some View {
        ZStack {
            // Base color per subject
            Rectangle()
                .fill(subjectGradient)

            // Placeholder icon, centered
            Image(systemName: subject.icon)
                .font(.system(size: 52))
                .foregroundStyle(.white.opacity(0.25))
        }
    }

    private var subjectGradient: LinearGradient {
        switch subject {
        case .pet:
            return LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.22, blue: 0.38),
                    Color(red: 0.08, green: 0.14, blue: 0.26)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .myself:
            return LinearGradient(
                colors: [
                    Color(red: 0.22, green: 0.12, blue: 0.38),
                    Color(red: 0.15, green: 0.08, blue: 0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [Color.bgElevated, Color.bgSecondary],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

#Preview {
    SubjectPickerView(selectedSubject: .constant(nil), onContinue: {})
}
