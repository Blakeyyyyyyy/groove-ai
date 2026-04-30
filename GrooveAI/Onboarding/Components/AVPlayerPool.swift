// AVPlayerPool.swift
import AVFoundation

class HeroVideoPlayerPool {
    private let maxPlayers: Int
    private var availablePlayers: [AVQueuePlayer] = []
    private var activePlayers: Set<AVQueuePlayer> = []
    private var playerLoopers: [ObjectIdentifier: AVPlayerLooper] = [:]
    private let queue = DispatchQueue(label: "com.groove.AVPlayerPool", attributes: .concurrent)

    init(maxPlayers: Int = 9) {
        self.maxPlayers = maxPlayers
        for _ in 0..<maxPlayers {
            let player = AVQueuePlayer()
            player.isMuted = true
            availablePlayers.append(player)
        }
    }

    func acquirePlayer() -> AVQueuePlayer? {
        var player: AVQueuePlayer?
        queue.sync(flags: .barrier) {
            if !availablePlayers.isEmpty {
                player = availablePlayers.removeFirst()
                activePlayers.insert(player!)
            }
        }
        return player
    }

    func releasePlayer(_ player: AVQueuePlayer) {
        queue.sync(flags: .barrier) {
            playerLoopers[ObjectIdentifier(player)] = nil  // release looper first
            activePlayers.remove(player)
            player.pause()
            player.removeAllItems()
            availablePlayers.append(player)
        }
    }

    func loadVideo(_ urlString: String, into player: AVQueuePlayer) {
        Task.detached(priority: .userInitiated) {
            // Use cached local file if available — instant load, no network hit.
            // Otherwise fall back to remote URL and queue a background download.
            let playURL: URL
            if let cached = await VideoCache.shared.cachedURL(for: urlString) {
                playURL = cached
            } else {
                guard let remote = URL(string: urlString) else { return }
                playURL = remote
                Task.detached(priority: .background) {
                    try? await VideoCache.shared.download(urlString)
                }
            }

            let asset = AVURLAsset(url: playURL)
            guard (try? await asset.load(.isPlayable)) != nil else { return }

            await MainActor.run {
                let item = AVPlayerItem(asset: asset)
                let looper = AVPlayerLooper(player: player, templateItem: item)
                self.queue.sync(flags: .barrier) {
                    self.playerLoopers[ObjectIdentifier(player)] = looper
                }
                player.play()
            }
        }
    }

    func shutdown() {
        queue.sync(flags: .barrier) {
            playerLoopers.removeAll()
            for player in activePlayers { player.pause() }
            activePlayers.removeAll()
            availablePlayers.removeAll()
        }
    }
}
