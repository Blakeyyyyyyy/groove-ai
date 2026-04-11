// RemoteVideoThumbnail.swift
// Extracts and caches first frame from a remote video URL.
// Used across onboarding screens to show video previews instead of emojis.

import SwiftUI
import AVFoundation

// MARK: - Thumbnail Cache (app-lifetime, ~20 images max)

final class VideoThumbnailCache {
    static let shared = VideoThumbnailCache()
    private var cache: [String: UIImage] = [:]
    private let queue = DispatchQueue(label: "video-thumbnail-cache", attributes: .concurrent)

    func get(_ key: String) -> UIImage? {
        queue.sync { cache[key] }
    }

    func set(_ key: String, image: UIImage) {
        queue.async(flags: .barrier) { self.cache[key] = image }
    }
}

// MARK: - View

struct RemoteVideoThumbnail: View {
    let urlString: String
    var cornerRadius: CGFloat = 16

    @State private var thumbnail: UIImage?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                // Shimmer placeholder
                shimmerView
            } else {
                // Fallback gradient
                LinearGradient(
                    colors: [Color(hex: 0x1A1A28), Color(hex: 0x0F0F18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: urlString) {
            await loadThumbnail()
        }
    }

    private var shimmerView: some View {
        LinearGradient(
            colors: [Color(hex: 0x1A1A28), Color(hex: 0x252535), Color(hex: 0x1A1A28)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func loadThumbnail() async {
        // Check cache first
        if let cached = VideoThumbnailCache.shared.get(urlString) {
            thumbnail = cached
            isLoading = false
            return
        }

        guard let url = URL(string: urlString) else {
            isLoading = false
            return
        }

        let asset = AVURLAsset(url: url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: false
        ])
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400) // Keep small for perf

        do {
            let (cgImage, _) = try await generator.image(at: .zero)
            let uiImage = UIImage(cgImage: cgImage)
            VideoThumbnailCache.shared.set(urlString, image: uiImage)
            await MainActor.run {
                self.thumbnail = uiImage
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

// MARK: - Mini Looping Video (for small card areas)
// Lightweight wrapper that auto-plays a remote video in a small area

struct MiniLoopingVideo: View {
    let urlString: String
    var cornerRadius: CGFloat = 16

    var body: some View {
        ZStack {
            if let url = URL(string: urlString) {
                LoopingVideoView(url: url, gravity: .resizeAspectFill, isMuted: true)
            } else {
                Color(hex: 0x1A1A28)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
