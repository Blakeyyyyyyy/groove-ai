import SwiftUI
import AVKit

/// Dedicated horizontal swipe page for a preset category.
/// Shows full video preview + Use This Dance button for each preset.
/// Starts on the tapped preset. Swipe left/right through all presets in category.
struct CategorySwipeView: View {
    let category: DancePreset.CategoryGroup
    let initialPreset: DancePreset

    @State private var currentIndex: Int = 0
    @State private var previousIndex: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Page indicator
            HStack(spacing: Spacing.sm) {
                ForEach(Array(category.presets.enumerated()), id: \.element.id) { index, _ in
                    Capsule()
                        .fill(index == currentIndex ? Color.accentStart : Color.bgElevated)
                        .frame(width: index == currentIndex ? 20 : 8, height: 4)
                        .animation(AppAnimation.snappy, value: currentIndex)
                }
            }
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.lg)

            // Swipeable video preview cards — full DancePreviewView style
            TabView(selection: $currentIndex) {
                ForEach(Array(category.presets.enumerated()), id: \.element.id) { index, preset in
                    SwipeablePresetCard(
                        preset: preset,
                        isActive: index == currentIndex
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxHeight: .infinity)
            .padding(.horizontal, Spacing.lg)
            .onChange(of: currentIndex) { oldValue, newValue in
                // Haptic feedback on swipe
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }

            Spacer()
        }
        .background(Color.bgPrimary)
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(category.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
            }
        }
        .onAppear {
            if let idx = category.presets.firstIndex(where: { $0.id == initialPreset.id }) {
                currentIndex = idx
                previousIndex = idx
            }
        }
    }
}

/// Full video preview card with Use This Dance button — matches DancePreviewView layout
struct SwipeablePresetCard: View {
    let preset: DancePreset
    let isActive: Bool
    
    @State private var player: AVPlayer?
    @State private var navigateToUpload = false

    var body: some View {
        VStack(spacing: 0) {
            // Pill tags
            ScrollView(.horizontal, showsIndicators: false) {
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
            .padding(.bottom, Spacing.md)

            // Main video preview — same sizing as DancePreviewView
            ZStack {
                RoundedRectangle(cornerRadius: Radius.xxl)
                    .fill(
                        LinearGradient(
                            colors: [preset.placeholderGradientTop, preset.placeholderGradientBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                if let player {
                    VideoPlayer(player: player)
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

            // Coins cost
            HStack(spacing: Spacing.sm) {
                Image(systemName: "circle.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.coinGold)

                Text("Uses \(preset.coinCost) coins")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.vertical, Spacing.md)

            // CTA — Use This Dance
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
        }
        .onAppear {
            if isActive {
                setupPlayer()
            }
        }
        .onChange(of: isActive) { oldValue, newValue in
            if newValue {
                // Card became active - start video
                setupPlayer()
            } else {
                // Card became inactive - pause video
                player?.pause()
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func setupPlayer() {
        guard player == nil else {
            // Already has player, just play
            player?.play()
            return
        }
        
        guard let urlString = preset.videoURL,
              let url = URL(string: urlString) else { return }
        let avPlayer = AVPlayer(url: url)
        avPlayer.isMuted = false
        self.player = avPlayer
        avPlayer.play()

        // Loop the video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: avPlayer.currentItem,
            queue: .main
        ) { _ in
            avPlayer.seek(to: .zero)
            avPlayer.play()
        }
    }
}

// Safe array subscript
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    NavigationStack {
        CategorySwipeView(
            category: DancePreset.categories[0],
            initialPreset: DancePreset.allPresets[0]
        )
        .environment(AppState())
    }
}
