// AVPlayerPool.swift
// Manages a pool of reusable AVQueuePlayers for efficient video playback

import AVFoundation

class HeroVideoPlayerPool {
    private let maxPlayers: Int
    private var availablePlayers: [AVQueuePlayer] = []
    private var activePlayers: Set<AVQueuePlayer> = []
    private let queue = DispatchQueue(label: "com.groove.AVPlayerPool", attributes: .concurrent)
    
    init(maxPlayers: Int = 9) {
        self.maxPlayers = maxPlayers
        // Pre-create players
        for _ in 0..<maxPlayers {
            let player = AVQueuePlayer()
            player.isMuted = true
            availablePlayers.append(player)
        }
    }
    
    // Acquire a player from the pool (or create if needed)
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
    
    // Release a player back to the pool
    func releasePlayer(_ player: AVQueuePlayer) {
        queue.sync(flags: .barrier) {
            activePlayers.remove(player)
            player.pause()
            player.removeAllItems()
            availablePlayers.append(player)
        }
    }
    
    // Configure and load video URL into a player
    func loadVideo(_ urlString: String, into player: AVQueuePlayer) {
        guard let url = URL(string: urlString) else { return }
        
        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        
        // Create looper for seamless looping
        _ = AVPlayerLooper(player: player, templateItem: item)
        
        player.play()
    }
    
    // Cleanup all players
    func shutdown() {
        queue.sync(flags: .barrier) {
            for player in activePlayers {
                player.pause()
            }
            activePlayers.removeAll()
            availablePlayers.removeAll()
        }
    }
}
