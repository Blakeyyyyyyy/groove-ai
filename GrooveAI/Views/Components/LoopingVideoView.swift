import SwiftUI
import AVFoundation

/// Silent autoplay loop with zero native controls. Drop-in for VideoPlayer.
struct LoopingVideoView: UIViewRepresentable {
    let url: URL
    var gravity: AVLayerVideoGravity = .resizeAspectFill

    func makeUIView(context: Context) -> LoopingPlayerUIView {
        LoopingPlayerUIView(url: url, gravity: gravity)
    }

    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {}
}

/// UIView that handles silent autoplay looping
final class LoopingPlayerUIView: UIView {
    private var playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper?
    private var queuePlayer: AVQueuePlayer?

    init(url: URL, gravity: AVLayerVideoGravity) {
        super.init(frame: .zero)
        backgroundColor = .clear

        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer(playerItem: item)
        playerLooper = AVPlayerLooper(player: player, templateItem: item)
        
        player.isMuted = true
        player.play()
        
        playerLayer.player = player
        playerLayer.videoGravity = gravity
        playerLayer.backgroundColor = UIColor.clear.cgColor
        layer.addSublayer(playerLayer)
        
        queuePlayer = player
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