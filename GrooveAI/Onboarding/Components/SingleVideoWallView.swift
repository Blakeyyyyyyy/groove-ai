import SwiftUI
import AVFoundation

final class VideoWallPlayerModel: ObservableObject {
    let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?

    init() {
        player.isMuted = true
        guard let url = Bundle.main.url(forResource: "onboarding_video_wall", withExtension: "mp4") else {
            return
        }
        let item = AVPlayerItem(url: url)
        looper = AVPlayerLooper(player: player, templateItem: item)
        player.play()
    }
}

struct SingleVideoWallView: View {
    @StateObject private var model = VideoWallPlayerModel()

    var body: some View {
        ZStack {
            // Poster shown while video loads
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
    let player: AVQueuePlayer

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

    func setPlayer(_ player: AVQueuePlayer) {
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
    }
}
