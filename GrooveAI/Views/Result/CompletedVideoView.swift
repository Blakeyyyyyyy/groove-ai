import SwiftUI
import AVKit
import Photos

struct CompletedVideoView: View {
    let video: GeneratedVideo
    let onMakeAnother: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var isPlaying = true
    @State private var player: AVQueuePlayer?
    @State private var playerLooper: AVPlayerLooper?
    @State private var isSharing = false
    @State private var shareURL: URL?
    @State private var isDownloading = false
    @State private var isSaving = false
    @State private var showDeleteConfirm = false
    @State private var showSavedAlert = false
    @State private var alertMessage = ""
    @State private var showAlert = false

    private var hasVideoURL: Bool {
        guard let videoURL = video.videoURL else { return false }
        return !videoURL.isEmpty
    }

    var body: some View {
        ZStack {
            Color.bgPrimary
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.xl) {
                    header
                    mediaCard
                    detailsCard
                    primaryActions
                    secondaryActions
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
            }
        }
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.dark)
        .task {
            setupPlayer()
        }
        .onDisappear {
            cleanupPlayer()
        }
        .sheet(isPresented: $isSharing) {
            if let shareURL {
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

    private var header: some View {
        HStack(alignment: .top) {
            Button {
                cleanupPlayer()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: Spacing.xs) {
                Text("Your Video")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)

                Text(video.danceName)
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            statusPill
        }
    }

    private var statusPill: some View {
        Text(hasVideoURL ? "Ready" : "Unavailable")
            .font(.caption.weight(.semibold))
            .foregroundStyle(hasVideoURL ? Color.success : Color.warning)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background((hasVideoURL ? Color.success : Color.warning).opacity(0.12))
            .clipShape(Capsule())
    }

    private var mediaCard: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: Radius.xxl)
                .fill(Color.bgSecondary)

            mediaContent
                .clipShape(RoundedRectangle(cornerRadius: Radius.xxl))

            LinearGradient(
                colors: [Color.clear, Color.bgPrimary.opacity(0.88)],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.xxl))

            VStack(spacing: Spacing.sm) {
                if player != nil {
                    Button {
                        togglePlayback()
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            Text(isPlaying ? "Pause Preview" : "Play Preview")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else if hasVideoURL {
                    VStack(spacing: Spacing.xs) {
                        ProgressView()
                            .tint(.white)
                        Text("Loading video preview...")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                } else {
                    VStack(spacing: Spacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.warning)
                        Text("Video file missing")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.textPrimary)
                        Text("This result was saved without a playable URL.")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(.horizontal, Spacing.xl)
                }
            }
            .padding(.bottom, Spacing.xl)
        }
        .aspectRatio(9 / 16, contentMode: .fit)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xxl)
                .stroke(Color.bgElevated, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }

    @ViewBuilder
    private var mediaContent: some View {
        if let player {
            VideoPlayer(player: player)
                .allowsHitTesting(false)
        } else if let photoData = video.photoData, let uiImage = UIImage(data: photoData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                Color.bgElevated
                Image(systemName: "film")
                    .font(.system(size: 42))
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Ready to share")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.textPrimary)

            Text(hasVideoURL
                 ? "Preview, share, or save your finished dance clip."
                 : "This result screen loaded, but the video URL is missing. Share and save actions need a valid file URL.")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(Color.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg)
                .stroke(Color.bgElevated, lineWidth: 1)
        )
    }

    private var primaryActions: some View {
        VStack(spacing: Spacing.md) {
            GradientCTAButton(primaryShareLabel, isEnabled: hasVideoURL && !isDownloading) {
                Task { await shareVideo() }
            }

            actionButton(
                title: isSaving ? "Saving..." : "Save to Photos",
                systemImage: "arrow.down.to.line",
                isDestructive: false,
                isEnabled: hasVideoURL && !isSaving
            ) {
                Task { await saveToPhotos() }
            }

            actionButton(
                title: "Make Another",
                systemImage: "sparkles",
                isDestructive: false,
                isEnabled: true
            ) {
                cleanupPlayer()
                onMakeAnother()
            }
        }
    }

    private var secondaryActions: some View {
        VStack(spacing: Spacing.md) {
            actionButton(
                title: "Delete Video",
                systemImage: "trash",
                isDestructive: true,
                isEnabled: true
            ) {
                showDeleteConfirm = true
            }

            Button {
                cleanupPlayer()
                dismiss()
            } label: {
                Text("Back to My Videos")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.textTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.plain)
        }
    }

    private var primaryShareLabel: String {
        if isDownloading { return "Preparing..." }
        return "Share Video"
    }

    private func actionButton(
        title: String,
        systemImage: String,
        isDestructive: Bool,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))

                Text(title)
                    .font(.subheadline.weight(.semibold))

                Spacer()
            }
            .foregroundStyle(isDestructive ? Color.error : Color.textPrimary)
            .padding(.horizontal, Spacing.lg)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(isDestructive ? Color.error.opacity(0.35) : Color.bgElevated, lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!isEnabled)
    }

    private func setupPlayer() {
        guard let urlString = video.videoURL,
              let url = URL(string: urlString) else {
            print("[CompletedVideo] No video URL available")
            return
        }

        let playerItem = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(playerItem: playerItem)
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: AVPlayerItem(url: url))

        queuePlayer.isMuted = false
        queuePlayer.play()

        player = queuePlayer
        playerLooper = looper
        isPlaying = true

        print("[CompletedVideo] ▶️ Player started: \(urlString)")
    }

    private func togglePlayback() {
        isPlaying.toggle()
        if isPlaying {
            player?.play()
        } else {
            player?.pause()
        }
    }

    private func cleanupPlayer() {
        player?.pause()
        player = nil
        playerLooper = nil
    }

    private func shareVideo() async {
        guard let urlString = video.videoURL, let url = URL(string: urlString) else {
            alertMessage = "No video URL available"
            showAlert = true
            return
        }

        isDownloading = true
        defer { isDownloading = false }

        do {
            let (tempURL, _) = try await URLSession.shared.download(from: url)
            let destinationURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("groove_\(video.id).mp4")

            try? FileManager.default.removeItem(at: destinationURL)
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)

            await MainActor.run {
                shareURL = destinationURL
                isSharing = true
            }
        } catch {
            print("[CompletedVideo] ❌ Download failed: \(error)")
            await MainActor.run {
                alertMessage = "Failed to download video. Try again."
                showAlert = true
            }
        }
    }

    private func saveToPhotos() async {
        guard let urlString = video.videoURL, let url = URL(string: urlString) else {
            alertMessage = "No video URL available"
            showAlert = true
            return
        }

        isSaving = true
        defer { isSaving = false }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            await MainActor.run {
                alertMessage = "Allow photo library access in Settings to save videos."
                showAlert = true
            }
            return
        }

        do {
            let (tempURL, _) = try await URLSession.shared.download(from: url)
            let destinationURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("groove_save_\(video.id).mp4")
            try? FileManager.default.removeItem(at: destinationURL)
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)

            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: destinationURL)
            }

            await MainActor.run {
                showSavedAlert = true
            }

            try? FileManager.default.removeItem(at: destinationURL)
        } catch {
            print("[CompletedVideo] ❌ Save to Photos failed: \(error)")
            await MainActor.run {
                alertMessage = "Failed to save video. Try again."
                showAlert = true
            }
        }
    }

    private func deleteVideo() {
        print("[CompletedVideo] 🗑️ Deleting video: \(video.id)")
        modelContext.delete(video)
        try? modelContext.save()

        cleanupPlayer()
        dismiss()
    }
}

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
