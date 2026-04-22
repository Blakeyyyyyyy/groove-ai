// GrooveHeroScrollView.swift
// PAGE 1 — Hero with 3-column video carousel using AVPlayerPool
// Uses UICollectionView + CompositionalLayout for performance.
// Max 5 AVQueuePlayer instances via pool — only visible cells play.

import SwiftUI
import AVFoundation
import UIKit

// MARK: - Video URLs

private let heroVideoBase = "https://videos.trygrooveai.com/presets"

private let heroVideoURLs: [URL] = [
    URL(string: "\(heroVideoBase)/big-guy-V5-AI.mp4")!,
    URL(string: "\(heroVideoBase)/coco-channel-75fcae6c.mp4")!,
    URL(string: "\(heroVideoBase)/trag-V5-AI.mp4")!,
    URL(string: "\(heroVideoBase)/c-walk-V5-AI.mp4")!,
    URL(string: "\(heroVideoBase)/boombastic-V5-AI.mp4")!,
    URL(string: "\(heroVideoBase)/ophelia-ai.mp4")!,
    URL(string: "\(heroVideoBase)/jenny-ai.mp4")!,
    URL(string: "\(heroVideoBase)/macarena-V5-AI.mp4")!,
    URL(string: "\(heroVideoBase)/milkshake-V5-AI.mp4")!,
    URL(string: "\(heroVideoBase)/witch-doctor.mp4")!,
    URL(string: "\(heroVideoBase)/cotton-eye-joe.mp4")!,
    URL(string: "\(heroVideoBase)/baby-boombastic.mp4")!,
    URL(string: "\(heroVideoBase)/big-guy-V5-AI.mp4")!,
    URL(string: "\(heroVideoBase)/trag-V5-AI.mp4")!,
    URL(string: "\(heroVideoBase)/ophelia-ai.mp4")!,
]

// MARK: - AVPlayer Pool

private final class AVPlayerPool {
    private var available: [AVQueuePlayer] = []
    private let maxPlayers = 5

    init() {
        for _ in 0..<maxPlayers {
            let player = AVQueuePlayer()
            player.isMuted = true
            available.append(player)
        }
    }

    func acquire() -> AVQueuePlayer? {
        guard !available.isEmpty else { return nil }
        return available.removeLast()
    }

    func release(_ player: AVQueuePlayer) {
        player.pause()
        player.removeAllItems()
        if available.count < maxPlayers {
            available.append(player)
        }
    }
}

// MARK: - Video Carousel Cell

private final class VideoCarouselCell: UICollectionViewCell {
    static let reuseID = "VideoCarouselCell"

    private(set) var currentPlayer: AVQueuePlayer?
    private var playerLayer: AVPlayerLayer?
    private var playerLooper: AVPlayerLooper?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = UIColor(red: 0.06, green: 0.07, blue: 0.10, alpha: 1.0) // #0F1119
        contentView.layer.cornerRadius = 24
        contentView.layer.masksToBounds = true
        contentView.clipsToBounds = true
    }

    required init?(coder: NSCoder) { fatalError() }

    func assignPlayer(_ player: AVQueuePlayer?, videoURL: URL) {
        // Clean up previous looper
        playerLooper?.disableLooping()
        playerLooper = nil
        currentPlayer = player

        guard let player = player else {
            playerLayer?.player = nil
            return
        }

        let item = AVPlayerItem(url: videoURL)
        playerLooper = AVPlayerLooper(player: player, templateItem: item)
        player.isMuted = true
        player.play()

        if playerLayer == nil {
            let layer = AVPlayerLayer(player: player)
            layer.videoGravity = .resizeAspectFill
            layer.frame = contentView.bounds
            contentView.layer.addSublayer(layer)
            playerLayer = layer
        } else {
            playerLayer?.player = player
        }
    }

    func releasePlayer() -> AVQueuePlayer? {
        let player = currentPlayer
        playerLooper?.disableLooping()
        playerLooper = nil
        currentPlayer = nil
        playerLayer?.player = nil
        return player
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        playerLooper?.disableLooping()
        playerLooper = nil
        currentPlayer = nil
        playerLayer?.player = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = contentView.bounds
    }
}

// MARK: - Carousel View Controller

private final class GrooveHeroCarouselVC: UIViewController {
    private let playerPool = AVPlayerPool()
    private var collectionView: UICollectionView!
    private let videoURLs: [URL]
    var carouselHeight: CGFloat = 500

    init(videoURLs: [URL]) {
        self.videoURLs = videoURLs
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupCollectionView()
    }

    private func setupCollectionView() {
        let layout = UICollectionViewCompositionalLayout { [weak self] section, environment -> NSCollectionLayoutSection? in
            guard self != nil else { return nil }
            let itemWidth: CGFloat = 1.0 / 3.0
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(itemWidth),
                heightDimension: .absolute(260)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(260)
            )
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize,
                subitems: [item, item, item]
            )

            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)
            return section
        }

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.showsVerticalScrollIndicator = false
        collectionView.register(VideoCarouselCell.self, forCellWithReuseIdentifier: VideoCarouselCell.reuseID)

        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}

extension GrooveHeroCarouselVC: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        videoURLs.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: VideoCarouselCell.reuseID, for: indexPath) as! VideoCarouselCell
        return cell
    }
}

extension GrooveHeroCarouselVC: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let videoCell = cell as? VideoCarouselCell else { return }
        if let player = playerPool.acquire() {
            videoCell.assignPlayer(player, videoURL: videoURLs[indexPath.item])
        }
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let videoCell = cell as? VideoCarouselCell else { return }
        if let player = videoCell.releasePlayer() {
            playerPool.release(player)
        }
    }
}

// MARK: - SwiftUI Bridge

private struct HeroCarouselRepresentable: UIViewControllerRepresentable {
    let videoURLs: [URL]
    let height: CGFloat

    func makeUIViewController(context: Context) -> GrooveHeroCarouselVC {
        let vc = GrooveHeroCarouselVC(videoURLs: videoURLs)
        vc.carouselHeight = height
        return vc
    }

    func updateUIViewController(_ uiViewController: GrooveHeroCarouselVC, context: Context) {}
}

// MARK: - Public SwiftUI View

struct GrooveHeroScrollView: View {
    let onNext: () -> Void

    @State private var contentVisible = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                GrooveOnboardingTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer().frame(height: 24)

                    // 3-column video carousel
                    ZStack {
                        GrooveOnboardingTheme.radialGlow
                            .scaleEffect(1.75)
                            .blur(radius: 30)

                        HeroCarouselRepresentable(
                            videoURLs: heroVideoURLs,
                            height: min(geo.size.height * 0.58, 500)
                        )

                        // Top fade
                        VStack {
                            LinearGradient(
                                colors: [GrooveOnboardingTheme.background, GrooveOnboardingTheme.background.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 42)
                            Spacer()
                        }
                        .allowsHitTesting(false)

                        // Bottom fade
                        VStack {
                            Spacer()
                            LinearGradient(
                                colors: [GrooveOnboardingTheme.background.opacity(0), GrooveOnboardingTheme.background],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 92)
                        }
                        .allowsHitTesting(false)
                    }
                    .frame(height: min(geo.size.height * 0.58, 500))
                    .clipped()

                    Spacer().frame(height: 22)

                    VStack(spacing: 12) {
                        Text("Make Anyone Drop the Beat")
                            .font(.system(size: 36, weight: .heavy))
                            .tracking(-0.5)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(-4)

                        Text("Upload a photo. Pick a dance. Watch it come alive.")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(GrooveOnboardingTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                    }
                    .padding(.horizontal, 24)
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 16)

                    Spacer().frame(height: 28)

                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onNext()
                    }) {
                        Text("Make yours →")
                            .font(.system(size: GrooveOnboardingTheme.ctaFontSize, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: GrooveOnboardingTheme.ctaButtonHeight)
                            .background(GrooveOnboardingTheme.blueAccent)
                            .clipShape(Capsule())
                            .shadow(color: GrooveOnboardingTheme.ctaShadow, radius: 12, y: 4)
                    }
                    .buttonStyle(CTAPressStyle())
                    .padding(.horizontal, GrooveOnboardingTheme.ctaHorizontalPadding)
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 18)

                    Spacer().frame(height: GrooveOnboardingTheme.ctaBottomPadding)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.35).delay(0.08)) {
                contentVisible = true
            }
        }
    }
}

struct CTAPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
