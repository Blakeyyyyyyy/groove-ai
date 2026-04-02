import SwiftUI

struct DancePreviewView: View {
    let preset: DancePreset
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var navigateToUpload = false

    private var videoURL: URL? {
        guard let urlString = preset.videoURL else { return nil }
        return URL(string: urlString)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Sneak Peek header
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Sneak Peek")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)

                // Pill tags
                HStack(spacing: Spacing.sm) {
                    ForEach(preset.pillTags, id: \.self) { tag in
                        Text(tag)
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(Color.bgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.full))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)

            Spacer().frame(height: Spacing.lg)

            // Main video preview card
            ZStack {
                RoundedRectangle(cornerRadius: Radius.xxl)
                    .fill(
                        LinearGradient(
                            colors: [preset.placeholderGradientTop, preset.placeholderGradientBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                if let videoURL {
                    LoopingVideoView(url: videoURL)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.xxl))
                } else {
                    // Fallback placeholder while loading
                    VStack(spacing: Spacing.md) {
                        ProgressView()
                            .tint(.white)

                        Text(preset.name)
                            .font(.headline)
                            .foregroundStyle(Color.textPrimary)
                    }
                }
            }
            .aspectRatio(9/16, contentMode: .fit)
            .padding(.horizontal, Spacing.lg)

            Spacer()

            // CTA
            NavigationLink(value: "upload-\(preset.id)") {
                Text("Use This Dance")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(LinearGradient.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            }
            .buttonStyle(ScaleButtonStyle())
            .sensoryFeedback(.success, trigger: navigateToUpload)
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Color.bgPrimary)
        .navigationTitle(preset.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(preset.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        DancePreviewView(preset: DancePreset.allPresets[0])
            .environment(AppState())
    }
}