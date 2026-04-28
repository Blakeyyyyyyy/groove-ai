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
        // Synchronous — but GrooveAIApp.init() forces this on a background thread
        // so the pool is ready before HomeView renders (splash takes 3.4s of cover).
        setupPool()
    }

    private func setupPool() {
        for _ in 0..<poolSize {
            let player = AVQueuePlayer()
            playerPool.append(player)
        }
    }

    func getPlayer() -> AVQueuePlayer {
        // Pool is always ready because GrooveAIApp.init() pre-warms it.
        // Fallback init in case something calls getPlayer() before pre-warm completes.
        if playerPool.isEmpty { setupPool() }
        let player = playerPool[playerIndex % playerPool.count]
        playerIndex = (playerIndex + 1) % poolSize
        return player
    }

    func loadVideo(url: URL, into player: AVQueuePlayer) {
        // AVAsset creation off main thread to avoid blocking UI
        Task.detached(priority: .userInitiated) {
            let asset = AVAsset(url: url)
            let playerItem = AVPlayerItem(asset: asset)
            await MainActor.run {
                player.removeAllItems()
                player.insert(playerItem, after: nil)
            }
        }
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
