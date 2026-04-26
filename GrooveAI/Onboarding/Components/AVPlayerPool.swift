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
        guard let url = URL(string: urlString) else { return }
        let item = AVPlayerItem(url: url)
        let looper = AVPlayerLooper(player: player, templateItem: item)
        queue.sync(flags: .barrier) {
            playerLoopers[ObjectIdentifier(player)] = looper  // retain it so ARC doesn't kill it
        }
        player.play()
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
