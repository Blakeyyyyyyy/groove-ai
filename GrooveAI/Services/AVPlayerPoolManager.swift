// AVPlayerPoolManager.swift
// Shared player pool for hero video wall
// Manages AVPlayer lifecycle to prevent resource leaks in 3-column parallax views

import AVFoundation
import SwiftUI

final class AVPlayerPoolManager: NSObject, ObservableObject {
    static let shared = AVPlayerPoolManager()

    private var playerPool: [AVQueuePlayer] = []
    private let poolSize = 6 // 3 columns × 2 videos per column
    private var playerIndex = 0

    override private init() {
        super.init()
        setupPool()
    }

    private func setupPool() {
        for _ in 0..<poolSize {
            let player = AVQueuePlayer()
            playerPool.append(player)
        }
    }

    func getPlayer() -> AVQueuePlayer {
        let player = playerPool[playerIndex % poolSize]
        playerIndex = (playerIndex + 1) % poolSize
        return player
    }

    func loadVideo(url: URL, into player: AVQueuePlayer) {
        let asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        player.removeAllItems()
        player.insert(playerItem, after: nil)
    }

    func stopAll() {
        playerPool.forEach { $0.pause() }
    }
}

// ─── Environment Key ──────────────────────────────────────────────────────

struct PlayerPoolEnvironmentKey: EnvironmentKey {
    static let defaultValue: AVPlayerPoolManager = .shared
}

extension EnvironmentValues {
    var playerPool: AVPlayerPoolManager {
        get { self[PlayerPoolEnvironmentKey.self] }
        set { self[PlayerPoolEnvironmentKey.self] = newValue }
    }
}
