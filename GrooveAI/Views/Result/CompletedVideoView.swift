import SwiftUI

struct CompletedVideoView: View {
    let video: GeneratedVideo
    let onMakeAnother: () -> Void

    @State private var headlineVisible = true
    @State private var isPlaying = true

    var body: some View {
        ZStack {
            // Full-screen video player background
            Color.bgPrimary
                .ignoresSafeArea()

            // Video placeholder (until R2 hosting)
            ZStack {
                if let photoData = video.photoData, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .ignoresSafeArea()
                } else {
                    Color.bgSecondary
                        .ignoresSafeArea()
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(LinearGradient.accent)
                }
            }
            .onTapGesture {
                isPlaying.toggle()
            }

            // Overlay headline (fades after 3s)
            VStack {
                Text("Here they are. 🎉")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                    .opacity(headlineVisible ? 1 : 0)
                    .animation(AppAnimation.gentle, value: headlineVisible)
                    .padding(.top, 60)

                Spacer()
            }

            // Bottom gradient + actions
            VStack {
                Spacer()

                // Gradient overlay
                LinearGradient(
                    colors: [Color.clear, Color.bgPrimary.opacity(0.8), Color.bgPrimary],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 250)
                .allowsHitTesting(false)

                VStack(spacing: Spacing.md) {
                    // Share Video — PRIMARY
                    GradientCTAButton("Share Video") {
                        shareVideo()
                    }

                    // Save to Photos — SECONDARY
                    Button("Save to Photos") {
                        saveToPhotos()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.textSecondary)
                    .frame(minHeight: 44)

                    // Make Another — TERTIARY
                    Button("Make Another →") {
                        onMakeAnother()
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.textTertiary)
                    .frame(minHeight: 44)
                }
                .padding(.bottom, Spacing.xxl)
            }
        }
        .navigationBarBackButtonHidden(true)
        .statusBarHidden(false)
        .preferredColorScheme(.dark)
        .task {
            try? await Task.sleep(for: .seconds(3))
            headlineVisible = false
        }
    }

    private func shareVideo() {
        // TODO: Share actual video file via UIActivityViewController
        // For now, placeholder
    }

    private func saveToPhotos() {
        // TODO: Save video to PHPhotoLibrary
    }
}

#Preview {
    CompletedVideoView(
        video: GeneratedVideo(dancePresetID: "hip-hop", danceName: "Hip Hop", status: "completed"),
        onMakeAnother: {}
    )
}
