// HeroVideoWallView.swift
// SwiftUI container for the 3-column hero video wall with parallax effect
// Manages shared AVPlayerPool, layout, and dimensions

import SwiftUI

struct HeroVideoWallView: View {
    @State private var sharedPool: AVPlayerPool?
    
    // Video URLs for each column
    let videoURLs: [String]
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                GrooveOnboardingTheme.background.ignoresSafeArea()
                
                // 3-column video wall
                HStack(spacing: 6) {
                    // Column 1: Scroll DOWN
                    HeroVideoColumnView(
                        videoURLs: videoURLs,
                        scrollDirection: .down,
                        sharedPool: sharedPool ?? AVPlayerPool(maxPlayers: 9)
                    )
                    
                    // Column 2: Scroll UP (parallax)
                    HeroVideoColumnView(
                        videoURLs: videoURLs,
                        scrollDirection: .up,
                        sharedPool: sharedPool ?? AVPlayerPool(maxPlayers: 9)
                    )
                    
                    // Column 3: Scroll DOWN
                    HeroVideoColumnView(
                        videoURLs: videoURLs,
                        scrollDirection: .down,
                        sharedPool: sharedPool ?? AVPlayerPool(maxPlayers: 9)
                    )
                }
                .padding(.horizontal, 0)
                .clipped()
            }
            .frame(height: geo.size.height * 0.55) // 55% of screen
            .onAppear {
                if sharedPool == nil {
                    sharedPool = AVPlayerPool(maxPlayers: 9)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let testURLs = [
        "https://videos.trygrooveai.com/presets/big-guy-V5-AI.mp4",
        "https://videos.trygrooveai.com/presets/trag-V5-AI.mp4",
        "https://videos.trygrooveai.com/presets/c-walk-V5-AI.mp4",
    ]
    
    HeroVideoWallView(videoURLs: testURLs)
        .background(Color.black)
}
