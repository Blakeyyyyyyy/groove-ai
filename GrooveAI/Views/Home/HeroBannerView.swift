import SwiftUI

private let heroFrameURLs: [String] = [
    "https://videos.trygrooveai.com/presets/hero-frames/moonwalk.jpg",
    "https://videos.trygrooveai.com/presets/hero-frames/buttons.jpg",
    "https://videos.trygrooveai.com/presets/hero-frames/rasputin.jpg",
    "https://videos.trygrooveai.com/presets/hero-frames/bangara.jpg",
    "https://videos.trygrooveai.com/presets/hero-frames/beauty-beat.jpg",
]

// MARK: - Hero Banner (Home screen, above presets)
struct HeroBannerView: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                ZStack(alignment: .bottomLeading) {
                    // 5-frame mosaic grid
                    HeroFrameMosaicView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 20))

                    // Dark gradient overlay for text legibility
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.65)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    // "9 new presets added" + "Try Now"
                    VStack(alignment: .leading, spacing: 4) {
                        Text("9 new presets added")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)

                        HStack(spacing: 4) {
                            Text("Try now")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Mosaic Layout (2 rows: 3 top, 2 bottom)

private struct HeroFrameMosaicView: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let gap: CGFloat = 3
            let topH = h * 0.55
            let botH = h - topH - gap
            let topW = (w - gap * 2) / 3
            let botW = (w - gap) / 2

            VStack(spacing: gap) {
                // Top row — 3 equal tiles
                HStack(spacing: gap) {
                    ForEach(0..<3, id: \.self) { i in
                        FrameTile(url: heroFrameURLs[i])
                            .frame(width: topW, height: topH)
                    }
                }
                // Bottom row — 2 wider tiles
                HStack(spacing: gap) {
                    ForEach(3..<5, id: \.self) { i in
                        FrameTile(url: heroFrameURLs[i])
                            .frame(width: botW, height: botH)
                    }
                }
            }
        }
    }
}

private struct FrameTile: View {
    let url: String

    var body: some View {
        AsyncImage(url: URL(string: url)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure, .empty:
                Rectangle()
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.16))
            @unknown default:
                Rectangle()
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.16))
            }
        }
        .clipped()
    }
}

#Preview {
    HeroBannerView(onTap: {})
        .padding()
        .background(Color.black)
}
