import SwiftUI

struct GradientCTAButton: View {
    let label: String
    let isEnabled: Bool
    let action: () -> Void

    @State private var isPressed = false

    init(_ label: String, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.label = label
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button {
            if isEnabled {
                action()
            }
        } label: {
            Text(label)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Group {
                        if isEnabled {
                            LinearGradient.accent
                        } else {
                            Color.bgElevated
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                .opacity(isEnabled ? 1.0 : 0.4)
        }
        .buttonStyle(ScaleButtonStyle())
        .sensoryFeedback(.success, trigger: isPressed)
        .padding(.horizontal, Spacing.lg)
        .allowsHitTesting(isEnabled)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(AppAnimation.snappy, value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: Spacing.xl) {
        GradientCTAButton("Start Dancing") {}
        GradientCTAButton("Select a Photo First", isEnabled: false) {}
    }
    .padding()
    .background(Color.bgPrimary)
}
