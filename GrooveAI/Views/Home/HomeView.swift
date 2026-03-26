import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var showCards = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: Spacing.lg) {
                    ForEach(Array(DancePreset.allPresets.enumerated()), id: \.element.id) { index, preset in
                        if preset.id == "coming-soon" {
                            DancePresetCard(preset: preset)
                                .opacity(0.5)
                                .offset(y: showCards ? 0 : 30)
                                .opacity(showCards ? 1 : 0)
                                .animation(
                                    AppAnimation.cardTransition.delay(Double(index) * 0.05),
                                    value: showCards
                                )
                        } else {
                            NavigationLink(value: preset) {
                                DancePresetCard(preset: preset)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .offset(y: showCards ? 0 : 30)
                            .opacity(showCards ? 1 : 0)
                            .animation(
                                AppAnimation.cardTransition.delay(Double(index) * 0.05),
                                value: showCards
                            )
                        }
                    }

                    // Bottom padding for tab bar + generating pill
                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
            }
            .background(Color.bgPrimary)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Groove AI")
                        .font(.title2.bold())
                        .foregroundStyle(Color.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    creditsBadge
                }
            }
            .toolbarBackground(Color.bgPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(for: DancePreset.self) { preset in
                DancePreviewView(preset: preset)
            }
            .navigationDestination(for: String.self) { value in
                if value.hasPrefix("upload-") {
                    let presetID = String(value.dropFirst(7))
                    if let preset = DancePreset.allPresets.first(where: { $0.id == presetID }) {
                        UploadView(preset: preset)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(AppAnimation.cardTransition.delay(0.1)) {
                showCards = true
            }
        }
    }

    private var creditsBadge: some View {
        Text("\(appState.creditsRemaining) credits")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.textSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: Radius.full))
    }
}

#Preview {
    HomeView()
        .environment(AppState())
}
