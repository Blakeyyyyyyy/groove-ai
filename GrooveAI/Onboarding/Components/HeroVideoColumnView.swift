// HeroVideoColumnView.swift
// UIViewRepresentable for a single infinite-scroll video column
// Manages Timer-based auto-scroll, player pool acquisition/release, and layout

import SwiftUI
import UIKit
import AVFoundation

enum ScrollDirection {
    case down
    case up
}

struct HeroVideoColumnView: UIViewControllerRepresentable {
    let videoURLs: [String]
    let scrollDirection: ScrollDirection
    let sharedPool: HeroVideoPlayerPool
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = ColumnViewController(
            videoURLs: videoURLs,
            scrollDirection: scrollDirection,
            sharedPool: sharedPool
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Handle updates if needed
    }
}

// MARK: - ColumnViewController

class ColumnViewController: UIViewController {
    private let videoURLs: [String]
    private let scrollDirection: ScrollDirection
    private let sharedPool: HeroVideoPlayerPool
    
    private var collectionView: UICollectionView!
    private var timer: Timer?
    
    // Infinite scroll: duplicate videos 4x
    private var infiniteURLs: [String] {
        Array(repeating: videoURLs, count: 4).flatMap { $0 }
    }
    
    // Layout constants
    private let cardAspectRatio: CGFloat = 9.0 / 16.0 // Portrait
    private let cornerRadius: CGFloat = 12
    private let cardGap: CGFloat = 12
    
    init(videoURLs: [String], scrollDirection: ScrollDirection, sharedPool: HeroVideoPlayerPool) {
        self.videoURLs = videoURLs
        self.scrollDirection = scrollDirection
        self.sharedPool = sharedPool
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupCollectionView()
        startAutoScroll()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView.frame = view.bounds
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        timer = nil
    }
    
    deinit {
        timer?.invalidate()
    }
    
    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = cardGap
        layout.minimumInteritemSpacing = 0
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isScrollEnabled = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.register(HeroVideoCell.self, forCellWithReuseIdentifier: HeroVideoCell.reuseIdentifier)
        
        view.addSubview(collectionView)
        
        // For column 2 (UP scroll), initialize at bottom
        if scrollDirection == .up {
            let contentHeight = CGFloat(infiniteURLs.count) * cardHeight + CGFloat(infiniteURLs.count - 1) * cardGap
            let maxScroll = max(0, contentHeight - collectionView.bounds.height)
            collectionView.setContentOffset(CGPoint(x: 0, y: maxScroll), animated: false)
        }
    }
    
    private var cardHeight: CGFloat {
        let width = view.bounds.width
        return width / cardAspectRatio
    }
    
    private func startAutoScroll() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true, block: { [weak self] _ in
            self?.updateScroll()
        })
    }
    
    private func updateScroll() {
        guard let collectionView = collectionView else { return }
        
        let scrollSpeed: CGFloat = 0.6
        let offset = collectionView.contentOffset
        let contentHeight = collectionView.contentSize.height
        let frameHeight = collectionView.bounds.height
        
        // Calculate thresholds for seamless looping
        let unitHeight = CGFloat(videoURLs.count) * (cardHeight + cardGap)
        let topThreshold: CGFloat = 0
        let resetThreshold = contentHeight - frameHeight - (unitHeight * 0.5)
        
        let newOffset: CGFloat
        
        if scrollDirection == .down {
            // Scroll DOWN
            newOffset = offset.y + scrollSpeed
            if newOffset > resetThreshold {
                collectionView.contentOffset.y = topThreshold
            } else {
                collectionView.contentOffset.y = newOffset
            }
        } else {
            // Scroll UP (reversed)
            newOffset = offset.y - scrollSpeed
            if newOffset < topThreshold {
                collectionView.contentOffset.y = resetThreshold
            } else {
                collectionView.contentOffset.y = newOffset
            }
        }
    }
}

// MARK: - UICollectionViewDataSource

extension ColumnViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        infiniteURLs.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: HeroVideoCell.reuseIdentifier, for: indexPath) as! HeroVideoCell
        // Player will be configured in willDisplay
        cell.configureWithPlayer(nil)
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension ColumnViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? HeroVideoCell else { return }
        
        // Acquire a player from the pool
        guard let player = sharedPool.acquirePlayer() else { return }
        
        let videoURL = infiniteURLs[indexPath.item]
        sharedPool.loadVideo(videoURL, into: player)
        cell.configureWithPlayer(player)
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? HeroVideoCell else { return }
        
        // Release player back to pool
        if let player = cell.currentPlayer {
            sharedPool.releasePlayer(player)
        }
        
        cell.resetPlayer()
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension ColumnViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width
        let height = width / (9.0 / 16.0) // 9:16 aspect ratio
        return CGSize(width: width, height: height)
    }
}
