import SwiftUI
import AVFoundation
import Combine

struct LoopingVideoView: View {
    let videoURL: URL
    let posterURL: URL?
    @Binding var isPlaying: Bool

    @State private var player: AVPlayer?
    @State private var isReady = false
    @State private var cancellables = Set<AnyCancellable>()

    init(videoURL: URL, posterURL: URL?, isPlaying: Binding<Bool>) {
        self.videoURL = videoURL
        self.posterURL = posterURL
        self._isPlaying = isPlaying
    }

    /// Backward-compat: legacy callers (onboarding, thumbnails) used `LoopingVideoView(url:)`
    /// with optional `gravity` / `isMuted` flags. Those flags are ignored now (always muted,
    /// always resizeAspectFill); the view always plays. This shim avoids touching every site.
    init(url: URL,
         gravity: AVLayerVideoGravity = .resizeAspectFill,
         isMuted: Bool = true,
         isPlaying: Bool = true) {
        self.videoURL = url
        self.posterURL = nil
        self._isPlaying = .constant(isPlaying)
    }

    var body: some View {
        ZStack {
            if let posterURL {
                AsyncImage(url: posterURL) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: Color.black
                    }
                }
            } else {
                Color.black
            }

            if let player {
                LoopingPlayerLayerView(player: player)
                    .opacity(isReady ? 1 : 0)
                    .animation(.easeIn(duration: 0.15), value: isReady)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onAppear { setupPlayer() }
        .onDisappear { teardownPlayer() }
        .onChange(of: isPlaying) { _, playing in
            playing ? player?.play() : player?.pause()
        }
    }

    private func setupPlayer() {
        guard player == nil else { return }
        let item = AVPlayerItem(url: videoURL)
        item.preferredForwardBufferDuration = 1
        let p = AVPlayer(playerItem: item)
        p.isMuted = true
        p.automaticallyWaitsToMinimizeStalling = false
        p.actionAtItemEnd = .none

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            p.seek(to: .zero)
            p.play()
        }

        item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { status in
                if status == .readyToPlay { isReady = true }
            }
            .store(in: &cancellables)

        player = p
        if isPlaying { p.play() }
    }

    private func teardownPlayer() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        NotificationCenter.default.removeObserver(self)
        cancellables.removeAll()
        player = nil
        isReady = false
    }
}

struct LoopingPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> LoopingPlayerContainer { LoopingPlayerContainer(player: player) }
    func updateUIView(_ uiView: LoopingPlayerContainer, context: Context) {
        uiView.player = player
    }
}

final class LoopingPlayerContainer: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    var player: AVPlayer? {
        get { playerLayer.player }
        set {
            playerLayer.player = newValue
            playerLayer.videoGravity = .resizeAspectFill
        }
    }
    init(player: AVPlayer) {
        super.init(frame: .zero)
        self.player = player
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Preserved: ControlledVideoView (used by Preview / Result / Onboarding)

/// Wraps an external AVPlayer (for cases where you need play/pause control).
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

// MARK: - Preserved: AudioLoopingVideoView (used by CategorySwipeView)

/// Audio-enabled looping player for full-screen sneak-peek pages where sound matters.
/// Owns its own AVPlayer; loops via .AVPlayerItemDidPlayToEndTime; tears down on disappear.
struct AudioLoopingVideoView: UIViewRepresentable {
    let url: URL
    var gravity: AVLayerVideoGravity = .resizeAspectFill
    var isPlaying: Bool = true

    func makeUIView(context: Context) -> AudioLoopingPlayerUIView {
        AudioLoopingPlayerUIView(url: url, gravity: gravity, isPlaying: isPlaying)
    }

    func updateUIView(_ uiView: AudioLoopingPlayerUIView, context: Context) {
        uiView.setPlaying(isPlaying)
    }

    static func dismantleUIView(_ uiView: AudioLoopingPlayerUIView, coordinator: ()) {
        uiView.teardown()
    }
}

final class AudioLoopingPlayerUIView: UIView {
    private let playerLayer = AVPlayerLayer()
    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?

    init(url: URL, gravity: AVLayerVideoGravity, isPlaying: Bool) {
        super.init(frame: .zero)
        backgroundColor = .clear
        playerLayer.videoGravity = gravity
        playerLayer.backgroundColor = UIColor.clear.cgColor
        layer.addSublayer(playerLayer)

        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        p.isMuted = false
        p.actionAtItemEnd = .none
        playerLayer.player = p
        player = p

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak p] _ in
            p?.seek(to: .zero)
            p?.play()
        }

        if isPlaying { p.play() }
    }

    required init?(coder: NSCoder) { fatalError() }

    func setPlaying(_ playing: Bool) {
        guard let player else { return }
        if playing { player.play() } else { player.pause() }
    }

    func teardown() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        player = nil
    }

    deinit {
        teardown()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}
