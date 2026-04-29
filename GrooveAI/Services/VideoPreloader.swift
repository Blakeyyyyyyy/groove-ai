import AVFoundation

/// Preloads upcoming video URLs to reduce buffering lag on initial play.
/// Triggers DNS resolution + initial HTTP request to warm the connection.
final class VideoPreloader: NSObject {
    static let shared = VideoPreloader()

    private var preloadedAssets: NSCache<NSString, AVAsset> = NSCache()
    private let lock = NSLock()

    private override init() {
        super.init()
    }

    /// Preload a video URL asynchronously — does NOT block the calling thread.
    /// AVAsset(url:) does DNS + HTTP handshake; running it on the main thread
    /// causes multi-second hangs when many cards appear simultaneously.
    func preload(url: URL) {
        let key = url.absoluteString as NSString

        lock.lock()
        let alreadyCached = preloadedAssets.object(forKey: key) != nil
        lock.unlock()

        guard !alreadyCached else { return }

        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }

            // Guard against duplicate concurrent preloads
            self.lock.lock()
            let stillNeeded = self.preloadedAssets.object(forKey: key) == nil
            self.lock.unlock()
            guard stillNeeded else { return }

            let asset = AVAsset(url: url)

            self.lock.lock()
            self.preloadedAssets.setObject(asset, forKey: key)
            self.lock.unlock()

            asset.loadValuesAsynchronously(forKeys: ["playable", "duration"]) { [weak asset] in
                guard let asset else { return }
                let status = asset.statusOfValue(forKey: "playable", error: nil)
                switch status {
                case .loaded:
                    #if DEBUG
                    print("[VideoPreloader] Preloaded: \(url.lastPathComponent)")
                    #endif
                case .failed, .cancelled, .unknown:
                    #if DEBUG
                    print("[VideoPreloader] Preload failed for: \(url.lastPathComponent)")
                    #endif
                @unknown default:
                    break
                }
            }
        }
    }

    /// Preload the next N videos in a list (for horizontal scrolling cards)
    func preloadNext(from urls: [URL], currentIndex: Int, count: Int = 3) {
        for offset in 1...count {
            let nextIndex = currentIndex + offset
            guard nextIndex < urls.count else { break }
            preload(url: urls[nextIndex])
        }
    }

    /// Clear cached preloads (call on memory warning)
    func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        preloadedAssets.removeAllObjects()
        #if DEBUG
        print("[VideoPreloader] Cache cleared")
        #endif
    }
}
