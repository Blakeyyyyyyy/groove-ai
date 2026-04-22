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

    init(url: URL, gravity: AVLayerVideoGravity, isMuted: Bool, isPlaying: Bool, pooledPlayer: AVQueuePlayer? = nil) {
        self.pooledPlayer = pooledPlayer
        super.init(frame: .zero)
        backgroundColor = .clear

        let item = AVPlayerItem(url: url)
        
        if let pooledPlayer {
            // Use the pooled player (Fix 1)
            isUsingPooledPlayer = true
            pooledPlayer.removeAllItems()
            pooledPlayer.insert(item, after: nil)
            player = pooledPlayer
            playerLooper = AVPlayerLooper(player: pooledPlayer, templateItem: item)
        } else {
            // Fallback: create own player (for backward compatibility)
            player = AVQueuePlayer(playerItem: item)
            playerLooper = AVPlayerLooper(player: player!, templateItem: item)
        }
        
        player?.isMuted = isMuted
        if isPlaying {
            player?.play()
        }
        
        playerLayer.player = player
        playerLayer.videoGravity = gravity
        playerLayer.backgroundColor = UIColor.clear.cgColor
        layer.addSublayer(playerLayer)
        
        queuePlayer = player
    }

    func setMuted(_ muted: Bool) {
        player?.isMuted = muted
    }

    func setPlaying(_ playing: Bool) {
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
