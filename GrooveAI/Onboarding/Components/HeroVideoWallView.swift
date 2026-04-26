// HeroVideoWallView.swift
import SwiftUI

struct HeroVideoWallView: View {
    @State private var sharedPool: HeroVideoPlayerPool?

    let column1URLs: [String]
    let column2URLs: [String]
    let column3URLs: [String]

    var body: some View {
        ZStack {
            GrooveOnboardingTheme.background.ignoresSafeArea()

            HStack(spacing: 6) {
                HeroVideoColumnView(
                    videoURLs: column1URLs,
                    scrollDirection: .down,
                    sharedPool: sharedPool ?? HeroVideoPlayerPool(maxPlayers: 12)
                )
                HeroVideoColumnView(
                    videoURLs: column2URLs,
                    scrollDirection: .up,
                    sharedPool: sharedPool ?? HeroVideoPlayerPool(maxPlayers: 12)
                )
                HeroVideoColumnView(
                    videoURLs: column3URLs,
                    scrollDirection: .down,
                    sharedPool: sharedPool ?? HeroVideoPlayerPool(maxPlayers: 12)
                )
            }
            .padding(.horizontal, 0)
            .clipped()
        }
        .onAppear {
            if sharedPool == nil {
                sharedPool = HeroVideoPlayerPool(maxPlayers: 12)
            }
        }
    }
}

#Preview {
    HeroVideoWallView(
        column1URLs: [
            "https://videos.trygrooveai.com/presets/big-guy-V5-AI.mp4",
            "https://videos.trygrooveai.com/presets/c-walk-V5-AI.mp4",
            "https://videos.trygrooveai.com/presets/trag-V5-AI.mp4",
            "https://videos.trygrooveai.com/presets/baby-boombastic.mp4",
        ],
        column2URLs: [
            "https://videos.trygrooveai.com/presets/milkshake-V5-AI.mp4",
            "https://videos.trygrooveai.com/presets/ophelia-ai.mp4",
            "https://videos.trygrooveai.com/presets/coco-channel-75fcae6c.mp4",
            "https://videos.trygrooveai.com/woman-coco-channel.mp4",
        ],
        column3URLs: [
            "https://videos.trygrooveai.com/woman-big-guy.mp4",
            "https://videos.trygrooveai.com/demos/golden-retriever-big-guy.mp4",
            "https://videos.trygrooveai.com/demos/golden-retriever-coco-channel.mp4",
            "https://videos.trygrooveai.com/demos/golden-retriever-c-walk.mp4",
        ]
    )
    .background(Color.black)
}
