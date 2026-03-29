import SwiftUI
import AVKit
import Photos

struct CompletedVideoView: View {
    let video: GeneratedVideo
    let onMakeAnother: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var headlineVisible = true
    @State private var isPlaying = true
    @State private var player: AVPlayer?
    @State private var playerLooper: AVPlayerLooper?
    @State private var isSharing = false
    @State private var shareURL: URL?
    @State private var isDownloading = false
    @State private var isSaving = false
    @State private var showDeleteConfirm = false
    @State private var showSavedAlert = false
    @State private var alertMessage = ""
    @State private var showAlert = false

    var body: some View {
        ZStack {
            // Full-screen video player background
            Color.bgPrimary
                .ignoresSafeArea()

            // Video player or photo fallback
            ZStack {
                if let player = player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                        .disabled(true) // Disable default controls, we handle play/pause
                } else if let photoData = video.photoData, let uiImage = UIImage(data: photoData) {
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

                // Play/pause overlay icon
                if !isPlaying {
                    Image(systemName: "play.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.white.opacity(0.8))
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
                }
            }
            .onTapGesture {
                isPlaying.toggle()
                if isPlaying {
                    player?.play()
                } else {
                    player?.pause()
                }
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
                    GradientCTAButton(isDownloading ? "Preparing..." : "Share Video") {
                        Task { await shareVideo() }
                    }
                    .disabled(isDownloading)
                    .opacity(isDownloading ? 0.7 : 1)

                    // Save to Photos — SECONDARY
                    Button(isSaving ? "Saving..." : "Save to Photos") {
                        Task { await saveToPhotos() }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.textSecondary)
                    .frame(minHeight: 44)
                    .disabled(isSaving)

                    // Delete — TERTIARY (destructive)
                    Button("Delete Video") {
                        showDeleteConfirm = true
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.red.opacity(0.8))
                    .frame(minHeight: 44)

                    // Make Another — QUATERNARY
                    Button("Make Another →") {
                        cleanupPlayer()
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
            setupPlayer()
            try? await Task.sleep(for: .seconds(3))
            headlineVisible = false
        }
        .onDisappear {
            cleanupPlayer()
        }
        .sheet(isPresented: $isSharing) {
            if let shareURL = shareURL {
                ShareSheet(activityItems: [shareURL])
                    .presentationDetents([.medium, .large])
            }
        }
        .confirmationDialog("Delete this video?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                deleteVideo()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK") {}
        }
        .alert("Saved to Photos!", isPresented: $showSavedAlert) {
            Button("OK") {}
        }
    }

    // MARK: - Video Player

    private func setupPlayer() {
        guard let urlString = video.videoURL, let url = URL(string: urlString) else {
            print("[CompletedVideo] No video URL available")
            return
        }

        let playerItem = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(playerItem: playerItem)
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: AVPlayerItem(url: url))

        queuePlayer.isMuted = false
        queuePlayer.play()

        self.player = queuePlayer
        self.playerLooper = looper
        self.isPlaying = true

        print("[CompletedVideo] ▶️ Player started: \(urlString)")
    }

    private func cleanupPlayer() {
        player?.pause()
        player = nil
        playerLooper = nil
    }

    // MARK: - Share

    private func shareVideo() async {
        guard let urlString = video.videoURL, let url = URL(string: urlString) else {
            alertMessage = "No video URL available"
            showAlert = true
            return
        }

        isDownloading = true
        defer { isDownloading = false }

        do {
            // Download video to temp file
            let (tempURL, _) = try await URLSession.shared.download(from: url)
            let destinationURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("groove_\(video.id).mp4")

            // Remove existing file if any
            try? FileManager.default.removeItem(at: destinationURL)
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)

            print("[CompletedVideo] 📥 Downloaded video to: \(destinationURL)")

            await MainActor.run {
                self.shareURL = destinationURL
                self.isSharing = true
            }
        } catch {
            print("[CompletedVideo] ❌ Download failed: \(error)")
            await MainActor.run {
                alertMessage = "Failed to download video. Try again."
                showAlert = true
            }
        }
    }

    // MARK: - Save to Photos

    private func saveToPhotos() async {
        guard let urlString = video.videoURL, let url = URL(string: urlString) else {
            alertMessage = "No video URL available"
            showAlert = true
            return
        }

        isSaving = true
        defer { isSaving = false }

        // Check photo library permission
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            await MainActor.run {
                alertMessage = "Allow photo library access in Settings to save videos."
                showAlert = true
            }
            return
        }

        do {
            // Download video to temp file
            let (tempURL, _) = try await URLSession.shared.download(from: url)
            let destinationURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("groove_save_\(video.id).mp4")
            try? FileManager.default.removeItem(at: destinationURL)
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)

            // Save to photo library
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: destinationURL)
            }

            print("[CompletedVideo] ✅ Saved to Photos")
            await MainActor.run {
                showSavedAlert = true
            }

            // Cleanup temp file
            try? FileManager.default.removeItem(at: destinationURL)
        } catch {
            print("[CompletedVideo] ❌ Save to Photos failed: \(error)")
            await MainActor.run {
                alertMessage = "Failed to save video. Try again."
                showAlert = true
            }
        }
    }

    // MARK: - Delete

    private func deleteVideo() {
        print("[CompletedVideo] 🗑️ Deleting video: \(video.id)")
        // Remove from local SwiftData
        modelContext.delete(video)
        try? modelContext.save()

        cleanupPlayer()
        onMakeAnother()
    }
}

// MARK: - Share Sheet (UIActivityViewController wrapper)

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    CompletedVideoView(
        video: GeneratedVideo(dancePresetID: "hip-hop", danceName: "Hip Hop", status: "completed"),
        onMakeAnother: {}
    )
}
