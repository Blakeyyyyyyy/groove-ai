import SwiftUI
import AVFoundation

struct DancePreviewView: View {
    let preset: DancePreset
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var navigateToUpload = false
    @State private var player: AVQueuePlayer? = nil
    @State private var playerLooper: AVPlayerLooper? = nil

    private var videoURL: URL? {
        guard let urlString = preset.videoURL else { return nil }
        return URL(string: urlString)
    }

    private func setupPlayer(url: URL) {
        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(playerItem: item)
        queuePlayer.isMuted = false
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        self.player = queuePlayer
        self.playerLooper = looper
        queuePlayer.play()
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

                // ControlledVideoView with view-owned AVQueuePlayer so we can pause
                // directly in .onDisappear (no SwiftUI render cycle dependency).
                if let videoURL {
                    ControlledVideoView(player: player)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.xxl))
                        .onAppear {
                            if player == nil {
                                setupPlayer(url: videoURL)
                            }
                        }
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

            // Bottom spacing — extra room so button doesn't touch video
            Spacer().frame(height: Spacing.xl)

            // CTA
            NavigationLink(value: "upload-\(preset.id)") {
                Text("Use This Dance")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(red: 0.545, green: 0.361, blue: 0.957)) // #8B5CF6
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
        .onAppear {
            if let videoURL, player == nil {
                setupPlayer(url: videoURL)
            }
            player?.play()
        }
        .onDisappear {
            player?.pause()
        }
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