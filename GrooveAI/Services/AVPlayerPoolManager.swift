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
        // Build the pool on a background thread — AVQueuePlayer allocations are heavy
        // and would stall the main thread for 2-4 seconds if done synchronously here.
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let players = (0..<self.poolSize).map { _ in AVQueuePlayer() }
            await MainActor.run { self.playerPool = players }
        }
    }

    func getPlayer() -> AVQueuePlayer {
        guard !playerPool.isEmpty else {
            // Pool not ready yet (background init still running) — create a throwaway player.
            // Once the pool is warm subsequent cards use pooled instances.
            return AVQueuePlayer()
        }
        let player = playerPool[playerIndex % playerPool.count]
        playerIndex = (playerIndex + 1) % poolSize
        return player
    }

    func loadVideo(url: URL, into player: AVQueuePlayer) {
        // Create the asset on a background thread to avoid blocking the main thread.
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
