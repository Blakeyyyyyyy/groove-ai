import SwiftUI
import AVFoundation

/// Silent autoplay loop with zero native controls. Drop-in for VideoPlayer.
struct LoopingVideoView: UIViewRepresentable {
    let url: URL
    var gravity: AVLayerVideoGravity = .resizeAspectFill
    var isMuted: Bool = true  // Default silent for background loops
    var isPlaying: Bool = true

    func makeUIView(context: Context) -> LoopingPlayerUIView {
        LoopingPlayerUIView(
            url: url,
            gravity: gravity,
            isMuted: isMuted,
            isPlaying: isPlaying
        )
    }

    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {
        uiView.setMuted(isMuted)
        uiView.setPlaying(isPlaying)
    }
}

/// UIView that handles autoplay looping with optional audio
final class LoopingPlayerUIView: UIView {
    private var playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper?
    private var queuePlayer: AVQueuePlayer?
    private var player: AVQueuePlayer?

    init(url: URL, gravity: AVLayerVideoGravity, isMuted: Bool, isPlaying: Bool) {
        super.init(frame: .zero)
        backgroundColor = .clear

        let item = AVPlayerItem(url: url)
        player = AVQueuePlayer(playerItem: item)
        playerLooper = AVPlayerLooper(player: player!, templateItem: item)
        
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
