import SwiftUI
import AVFoundation

final class VideoWallPlayerModel: ObservableObject {
    let player = AVPlayer()
    private var endObserver: NSObjectProtocol?

    init() {
        player.isMuted = true
        player.automaticallyWaitsToMinimizeStalling = false
        guard let url = Bundle.main.url(forResource: "onboarding_video_wall", withExtension: "mp4") else {
            return
        }
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.player.seek(to: .zero)
            self?.player.play()
        }

        player.play()
    }

    deinit {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }
}

struct SingleVideoWallView: View {
    @StateObject private var model = VideoWallPlayerModel()

    var body: some View {
        ZStack {
            if let poster = UIImage(named: "onboarding_video_wall_poster") {
                Image(uiImage: poster)
                    .resizable()
                    .scaledToFill()
            }
            PlayerLayerView(player: model.player)
        }
        .onAppear {
            model.player.play()
        }
    }
}

struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerUIView {
        let view = PlayerLayerUIView()
        view.setPlayer(player)
        return view
    }

    func updateUIView(_ uiView: PlayerLayerUIView, context: Context) {}
}

final class PlayerLayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    func setPlayer(_ player: AVPlayer) {
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
    }
}
