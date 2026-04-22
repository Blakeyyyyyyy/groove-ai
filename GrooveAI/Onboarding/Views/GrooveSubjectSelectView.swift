import SwiftUI

private enum SubjectImageLoader {
    private static let workspaceRoot = "/Users/blakeyyyclaw/.openclaw/workspace/groove-ai"

    static func load(_ name: String, fallbackPaths: [String]) -> UIImage? {
        if let image = UIImage(named: name) {
            return image
        }

        for path in ([name] + fallbackPaths) {
            let absolutePath = path.hasPrefix("/") ? path : "\(workspaceRoot)/\(path)"
            if let image = UIImage(contentsOfFile: absolutePath) {
                return image
            }
        }

        return nil
    }
}

private struct SubjectOption: Identifiable {
    let id: String
    let displayName: String
    let fallbackPaths: [String]
}

private let subjectOptions: [SubjectOption] = [
    SubjectOption(
        id: "person",
        displayName: "06183b6c390a4741f1cdfa11a3f06e82.jpg",
        fallbackPaths: [
            "GrooveAI/Assets.xcassets/subject-person.imageset/subject-person.jpg"
        ]
    ),
    SubjectOption(
        id: "dog",
        displayName: "Gemini_Generated_Image_1555co1555co1555.png",
        fallbackPaths: [
            "GrooveAI/Assets.xcassets/subject-pet.imageset/subject-pet.png"
        ]
    )
]

struct GrooveSubjectSelectView: View {
    @ObservedObject var state: GrooveOnboardingState
    let onNext: () -> Void

    @State private var cardsAppeared = false

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
                                image: SubjectImageLoader.load(option.displayName, fallbackPaths: option.fallbackPaths),
                                isSelected: state.selectedSubjectId == option.id
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

                Spacer()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                cardsAppeared = true
            }
        }
    }

    private func handleSelect(_ option: SubjectOption) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            state.selectedSubjectId = option.id
            state.selectedPreviewImage = SubjectImageLoader.load(option.displayName, fallbackPaths: option.fallbackPaths)
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onNext()
        }
    }
}

private struct SubjectCard: View {
    let image: UIImage?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(GrooveOnboardingTheme.surfaceL1)
                .overlay {
                    Group {
                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            GrooveOnboardingTheme.surfaceL1
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .frame(maxWidth: .infinity)
                .frame(height: 332)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            isSelected ? GrooveOnboardingTheme.blueAccent : Color.white.opacity(0.08),
                            lineWidth: isSelected ? 2 : 1
                        )
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
