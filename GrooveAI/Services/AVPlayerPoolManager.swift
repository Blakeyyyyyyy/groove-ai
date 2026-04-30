// HomeVideoPlayerPool — @MainActor class so all access is serialized on the main
// thread. No actor suspension points = no reentrancy, no stale-closure races.

import AVFoundation
import SwiftUI

// Opaque token returned by acquire(). release(token:) is a no-op when the slot's
// generation has rotated — prevents stale onDisappear teardowns from killing a
// player that was already re-acquired for a different card.
struct LeaseToken: Equatable {
    fileprivate let slotIndex: Int
    fileprivate let generation: UInt64
}

@MainActor
final class HomeVideoPlayerPool {
    static let shared = HomeVideoPlayerPool()

    private struct Slot {
        let player: AVQueuePlayer
        var looper: AVPlayerLooper?
        var token: LeaseToken?
        var lastUsed: Date = .distantPast
    }

    private var slots: [Slot]
    private var generationCounter: UInt64 = 0

    private init() {
        slots = (0..<6).map { _ in Slot(player: AVQueuePlayer()) }
    }

    /// Acquires a pool slot for `url`. Returns the player and a lease token.
    /// Call `release(token:)` from `onDisappear` or when the card is no longer visible.
    func acquire(url: URL) -> (AVQueuePlayer, LeaseToken) {
        let idx = pickSlot()
        teardown(slot: idx)
        generationCounter &+= 1
        let token = LeaseToken(slotIndex: idx, generation: generationCounter)
        assign(slot: idx, url: url, token: token)
        return (slots[idx].player, token)
    }

    /// Releases the slot. No-op if the token is stale (slot was re-acquired by another card).
    func release(token: LeaseToken) {
        let idx = token.slotIndex
        guard slots[idx].token == token else { return }
        teardown(slot: idx)
        slots[idx].token = nil
    }

    /// Returns false if the slot has been evicted and reassigned to another card.
    func isValid(_ token: LeaseToken) -> Bool {
        slots[token.slotIndex].token == token
    }

    func pauseAll() {
        slots.forEach { $0.player.pause() }
    }

    // MARK: - Private

    private func pickSlot() -> Int {
        if let idle = slots.firstIndex(where: { $0.token == nil }) { return idle }
        // LRU eviction: steal the slot used longest ago
        return slots.indices.min(by: { slots[$0].lastUsed < slots[$1].lastUsed })!
    }

    private func teardown(slot idx: Int) {
        slots[idx].looper = nil
        slots[idx].player.pause()
        slots[idx].player.removeAllItems()
    }

    private func assign(slot idx: Int, url: URL, token: LeaseToken) {
        slots[idx].token = token
        slots[idx].lastUsed = Date()

        let player = slots[idx].player
        // Disable stall-minimization only for local files — remote URLs need buffering headroom.
        player.automaticallyWaitsToMinimizeStalling = !url.isFileURL

        let item = AVPlayerItem(url: url)
        // Write looper synchronously before returning so teardown always sees it.
        slots[idx].looper = AVPlayerLooper(player: player, templateItem: item)
        player.isMuted = true
        player.play()
    }
}

// ─── Environment Key ──────────────────────────────────────────────────────

private struct PlayerPoolEnvironmentKey: EnvironmentKey {
    static let defaultValue: HomeVideoPlayerPool = .shared
}

extension EnvironmentValues {
    var playerPool: HomeVideoPlayerPool {
        get { self[PlayerPoolEnvironmentKey.self] }
        set { self[PlayerPoolEnvironmentKey.self] = newValue }
    }
}
