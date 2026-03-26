import SwiftUI

struct PaywallView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showExitPopup = false

    var body: some View {
        ZStack {
            // Subtle gradient mesh background — never flat void
            Color.bgPrimary
                .ignoresSafeArea()

            // Subtle radial glow at top
            RadialGradient(
                colors: [Color.accentStart.opacity(0.08), Color.clear],
                center: .top,
                startRadius: 50,
                endRadius: 400
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.xl) {
                    // Close button
                    HStack {
                        Button {
                            showExitPopup = true
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title3)
                                .foregroundStyle(Color.textSecondary)
                                .frame(width: 44, height: 44)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.lg)

                    // Headline
                    VStack(spacing: Spacing.sm) {
                        Text("Start Dancing — $9.99")
                            .font(.title2.bold())
                            .foregroundStyle(Color.textPrimary)

                        Text("Join millions already making their pets, babies, and friends dance. Instant access — your video starts generating the moment you subscribe.")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, Spacing.lg)

                    // 3 Video thumbnails
                    HStack(spacing: Spacing.md) {
                        demoCard(emoji: "🐱", label: "Cat")
                        demoCard(emoji: "👶", label: "Baby")
                        demoCard(emoji: "🐶", label: "Dog")
                    }
                    .padding(.horizontal, Spacing.lg)

                    // Review card
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("\"2M views on my first dog video\"")
                            .font(.body.italic())
                            .foregroundStyle(Color.textPrimary)

                        Text("— Jamie, Texas")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.lg)
                    .background(Color.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    .padding(.horizontal, Spacing.lg)

                    // Social proof line
                    Text("Millions of videos generated")
                        .font(.caption)
                        .foregroundStyle(Color.textTertiary)

                    // Divider
                    Rectangle()
                        .fill(Color.bgElevated)
                        .frame(height: 1)
                        .padding(.horizontal, Spacing.lg)

                    // Pricing
                    VStack(spacing: Spacing.xs) {
                        Text("$9.99 first week")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.textPrimary)

                        Text("$14.99/week ongoing")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)

                        Text("Annual plan available")
                            .font(.footnote)
                            .foregroundStyle(Color.textTertiary)
                    }

                    // Divider
                    Rectangle()
                        .fill(Color.bgElevated)
                        .frame(height: 1)
                        .padding(.horizontal, Spacing.lg)

                    // CTA
                    GradientCTAButton("Start Dancing — $9.99") {
                        handleSubscribe()
                    }

                    // Legal
                    VStack(spacing: Spacing.xs) {
                        Text("Billed weekly. Cancel any time in Settings.")
                            .font(.footnote)
                            .foregroundStyle(Color.textTertiary)

                        Button("Restore Purchases") {
                            // RevenueCat restore
                        }
                        .font(.footnote)
                        .foregroundStyle(Color.textTertiary)
                        .frame(minHeight: 44)
                    }
                    .multilineTextAlignment(.center)

                    Spacer().frame(height: Spacing.lg)
                }
            }
        }
        .sheet(isPresented: $showExitPopup) {
            ExitPopupView(
                onSubscribe: {
                    showExitPopup = false
                    handleSubscribe()
                },
                onDismiss: {
                    showExitPopup = false
                    dismiss()
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
            .presentationBackground(Color.bgSecondary)
        }
    }

    @ViewBuilder
    private func demoCard(emoji: String, label: String) -> some View {
        VStack(spacing: Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.lg)
                    .fill(Color.bgSecondary)

                VStack(spacing: Spacing.sm) {
                    Text(emoji)
                        .font(.system(size: 36))
                    Image(systemName: "play.circle.fill")
                        .font(.title3)
                        .foregroundStyle(LinearGradient.accent)
                }

                // Bottom gradient overlay
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [Color.clear, Color.bgSecondary.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 40)
                }
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            }
            .aspectRatio(9/16, contentMode: .fit)
        }
    }

    private func handleSubscribe() {
        // TODO: RevenueCat purchase flow
        // For now, simulate success
        appState.isSubscribed = true
        appState.hasCompletedOnboarding = true
        appState.showPaywall = false
    }
}

#Preview {
    PaywallView()
        .environment(AppState())
}
