import SwiftUI
import AVFoundation

/// Silent autoplay loop with zero native controls. Drop-in for VideoPlayer.
/// Can optionally use a pooled player (pass `pooledPlayer`), or create its own.
struct LoopingVideoView: UIViewRepresentable {
    let url: URL
    var gravity: AVLayerVideoGravity = .resizeAspectFill
    var isMuted: Bool = true  // Default silent for background loops
    var isPlaying: Bool = true
    var pooledPlayer: AVQueuePlayer? = nil  // Optional pooled player (for Fix 1)

    func makeUIView(context: Context) -> LoopingPlayerUIView {
        LoopingPlayerUIView(
            url: url,
            gravity: gravity,
            isMuted: isMuted,
            isPlaying: isPlaying,
            pooledPlayer: pooledPlayer
        )
    }

    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {
        // Pooled path: pool owns the looper; don't tear it down on re-render.
        if pooledPlayer == nil {
            uiView.setVideoURL(url)
        }
        uiView.setMuted(isMuted)
        uiView.setPlaying(isPlaying)
    }
}

/// UIView that handles autoplay looping with optional audio.
/// Can use a pooled player (Fix 1) or create its own.
final class LoopingPlayerUIView: UIView {
    private var playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper?
    private var queuePlayer: AVQueuePlayer?
    private var player: AVQueuePlayer?
    private let pooledPlayer: AVQueuePlayer?
    private var isUsingPooledPlayer: Bool = false
    private var loadTask: Task<Void, Never>?
    private var currentURL: URL?
    private var shouldPlayWhenReady = true

    init(url: URL, gravity: AVLayerVideoGravity, isMuted: Bool, isPlaying: Bool, pooledPlayer: AVQueuePlayer? = nil) {
        self.pooledPlayer = pooledPlayer
        super.init(frame: .zero)
        backgroundColor = .clear

        if let pooledPlayer {
            isUsingPooledPlayer = true
            player = pooledPlayer
        } else {
            player = AVQueuePlayer()
        }

        player?.isMuted = isMuted
        shouldPlayWhenReady = isPlaying
        playerLayer.player = player
        playerLayer.videoGravity = gravity
        playerLayer.backgroundColor = UIColor.clear.cgColor
        layer.addSublayer(playerLayer)

        queuePlayer = player
        // Pooled path: the pool already set up AVPlayerLooper and called play().
        // Calling setVideoURL here would tear that down and re-create it unnecessarily.
        if pooledPlayer == nil {
            setVideoURL(url)
        }
    }

    func setMuted(_ muted: Bool) {
        player?.isMuted = muted
    }

    func setVideoURL(_ url: URL) {
        guard currentURL != url else { return }

        currentURL = url
        loadTask?.cancel()
        playerLooper = nil
        player?.pause()
        player?.removeAllItems()

        guard let player else { return }

        loadTask = Task(priority: .userInitiated) { [weak self] in
            let urlString = url.absoluteString

            // 1. Use VideoPreloader's in-memory asset if already loaded (fastest)
            if let preloadedAsset = VideoPreloader.shared.cachedAsset(for: url) {
                guard !Task.isCancelled else { return }
                let item = AVPlayerItem(asset: preloadedAsset)
                await MainActor.run {
                    guard let self, self.currentURL == url else { return }
                    player.removeAllItems()
                    self.playerLooper = AVPlayerLooper(player: player, templateItem: item)
                    player.isMuted = self.player?.isMuted ?? true
                    if self.shouldPlayWhenReady { player.play() }
                }
                return
            }

            // 2. Use disk-cached local file if available (fast, avoids network)
            if let cachedLocal = await VideoCache.shared.cachedURL(for: urlString) {
                guard !Task.isCancelled else { return }
                let asset = AVURLAsset(url: cachedLocal)
                do {
                    _ = try await asset.load(.isPlayable)
                    guard !Task.isCancelled else { return }
                    let item = AVPlayerItem(asset: asset)
                    await MainActor.run {
                        guard let self, self.currentURL == url else { return }
                        player.removeAllItems()
                        self.playerLooper = AVPlayerLooper(player: player, templateItem: item)
                        player.isMuted = self.player?.isMuted ?? true
                        if self.shouldPlayWhenReady { player.play() }
                    }
                } catch {
                    #if DEBUG
                    print("[LoopingVideoView] Local cache load failed: \(url.lastPathComponent)")
                    #endif
                }
                return
            }

            // 3. Remote URL — skip .isPlayable wait, let AVPlayer buffer naturally.
            //    Kick off a background disk-cache download for next time.
            guard !Task.isCancelled else { return }
            Task.detached(priority: .background) {
                try? await VideoCache.shared.download(urlString)
            }
            let item = AVPlayerItem(url: url)
            await MainActor.run {
                guard let self, self.currentURL == url else { return }
                player.removeAllItems()
                self.playerLooper = AVPlayerLooper(player: player, templateItem: item)
                player.isMuted = self.player?.isMuted ?? true
                if self.shouldPlayWhenReady { player.play() }
            }
        }
    }

    func setPlaying(_ playing: Bool) {
        shouldPlayWhenReady = playing
        guard let player else { return }
        if playing {
            player.play()
        } else {
            player.pause()
        }
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    deinit {
        loadTask?.cancel()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}

/// Version that wraps an external AVPlayer (for cases where you need play/pause control)
struct ControlledVideoView: UIViewRepresentable {
    let player: AVPlayer?
    var gravity: AVLayerVideoGravity = .resizeAspectFill

    func makeUIView(context: Context) -> ControlledPlayerUIView {
        ControlledPlayerUIView(gravity: gravity)
    }

    func updateUIView(_ uiView: ControlledPlayerUIView, context: Context) {
        uiView.playerLayer.player = player
        uiView.playerLayer.videoGravity = gravity
    }
}

/// UIView for controlled player (external AVPlayer, no looping logic)
final class ControlledPlayerUIView: UIView {
    let playerLayer = AVPlayerLayer()

    init(gravity: AVLayerVideoGravity) {
        super.init(frame: .zero)
        backgroundColor = .clear
        playerLayer.videoGravity = gravity
        playerLayer.backgroundColor = UIColor.clear.cgColor
        layer.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}

/// Audio-enabled version for sneak peek pages where sound matters
struct AudioLoopingVideoView: UIViewRepresentable {
    let url: URL
    var gravity: AVLayerVideoGravity = .resizeAspectFill
    var isPlaying: Bool = true

    func makeUIView(context: Context) -> LoopingPlayerUIView {
        // Audio ON for sneak peek
        LoopingPlayerUIView(
            url: url,
            gravity: gravity,
            isMuted: false,
            isPlaying: isPlaying
        )
    }

    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {
        uiView.setPlaying(isPlaying)
    }
}
