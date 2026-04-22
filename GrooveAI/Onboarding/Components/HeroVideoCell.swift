// HeroVideoCell.swift
// UICollectionViewCell for hero video wall cards
// Plays video via AVPlayerLayer, supports pooled AVQueuePlayer

import UIKit
import AVFoundation

class HeroVideoCell: UICollectionViewCell {
    static let reuseIdentifier = "HeroVideoCell"
    
    private let playerLayer = AVPlayerLayer()
    var currentPlayer: AVQueuePlayer? // Public for access from delegate
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        // Style: 9:16 portrait card with rounded corners + white border
        contentView.layer.addSublayer(playerLayer)
        
        contentView.layer.cornerRadius = 12
        contentView.layer.borderWidth = 1.5
        contentView.layer.borderColor = UIColor.white.withAlphaComponent(0.6).cgColor
        contentView.clipsToBounds = true
        
        playerLayer.videoGravity = .resizeAspectFill
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = contentView.bounds
    }
    
    // Configure cell with a pooled player
    func configureWithPlayer(_ player: AVQueuePlayer?) {
        self.currentPlayer = player
        playerLayer.player = player
    }
    
    // Reset cell for reuse (called when leaving visible area)
    func resetPlayer() {
        playerLayer.player = nil
        currentPlayer = nil
    }
}
