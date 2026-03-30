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

            VStack(spacing: Spacing.xl) {
                header

                // 4:5 video container — clean, no overlay
                videoContainer
                    .padding(.horizontal, Spacing.lg)

                // Horizontal action row: Play | Share | Save | Delete
                actionRow
                    .padding(.horizontal, Spacing.lg)

                Spacer()

                // Make Another CTA
                GradientCTAButton("Make Another") {
                    cleanupPlayer()
                    onMakeAnother()
                }
                .padding(.bottom, Spacing.xxl)
            }
            .padding(.top, Spacing.lg)
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
        .alert("Delete this video?", isPresented: $showDeleteConfirm) {
            Button("Delete Forever", role: .destructive) {
                deleteVideo()
            }
            Button("Keep It", role: .cancel) {}
        } message: {
            Text("Delete this video and it's gone forever.")
        }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK") {}
        }
        .alert("Saved to Photos!", isPresented: $showSavedAlert) {
            Button("OK") {}
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
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

            Text(video.danceName)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.textPrimary)

            Spacer()

            // Invisible spacer for centering
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Video Container (4:5, rounded, no dark overlay)

    private var videoContainer: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.xxl)
                .fill(Color.bgSecondary)

            mediaContent
                .clipShape(RoundedRectangle(cornerRadius: Radius.xxl))

            // Loading state only (no dark overlay on video)
            if player == nil && hasVideoURL {
                VStack(spacing: Spacing.xs) {
                    ProgressView()
                        .tint(.white)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            } else if !hasVideoURL {
                VStack(spacing: Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.warning)
                    Text("Video file missing")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                }
            }
        }
        .aspectRatio(4.0 / 5.0, contentMode: .fit)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xxl)
                .stroke(Color.bgElevated, lineWidth: 1)
        )
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

    // MARK: - Horizontal Action Row

    private var actionRow: some View {
        HStack(spacing: Spacing.md) {
            actionIcon(
                icon: isPlaying ? "pause.fill" : "play.fill",
                label: isPlaying ? "Pause" : "Play",
                enabled: player != nil
            ) {
                togglePlayback()
            }

            actionIcon(
                icon: "square.and.arrow.up.fill",
                label: "Share",
                enabled: hasVideoURL && !isDownloading
            ) {
                Task { await shareVideo() }
            }

            actionIcon(
                icon: "arrow.down.to.line.compact",
                label: isSaving ? "Saving" : "Save",
                enabled: hasVideoURL && !isSaving
            ) {
                Task { await saveToPhotos() }
            }

            actionIcon(
                icon: "trash.fill",
                label: "Delete",
                isDestructive: true,
                enabled: true
            ) {
                showDeleteConfirm = true
            }
        }
    }

    private func actionIcon(
        icon: String,
        label: String,
        isDestructive: Bool = false,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .frame(width: 48, height: 48)
                    .background(Color.bgSecondary)
                    .clipShape(Circle())

                Text(label)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(
                isDestructive
                    ? Color.error
                    : (enabled ? Color.textPrimary : Color.textTertiary)
            )
            .frame(maxWidth: .infinity)
            .opacity(enabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: - Player

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

    // MARK: - Actions

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
