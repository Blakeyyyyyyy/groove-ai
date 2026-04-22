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

    /// Preload a video URL to trigger DNS + HTTP handshake.
    /// This warms the connection so playback is faster when the card becomes visible.
    func preload(url: URL) {
        lock.lock()
        let key = url.absoluteString as NSString
        lock.unlock()

        // Skip if already preloading
        if preloadedAssets.object(forKey: key) != nil {
            return
        }

        let asset = AVAsset(url: url)
        preloadedAssets.setObject(asset, forKey: key)

        // Async load metadata. This triggers initial HTTP connection.
        asset.loadValuesAsynchronously(forKeys: ["playable", "duration"]) { [weak asset] in
            guard let asset else { return }

            let status = asset.statusOfValue(forKey: "playable", error: nil)
            switch status {
            case .loaded:
                print("[VideoPreloader] Preloaded: \(url.lastPathComponent)")
            case .failed, .cancelled, .unknown:
                print("[VideoPreloader] Preload failed for: \(url.lastPathComponent)")
            @unknown default:
                break
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
        print("[VideoPreloader] Cache cleared")
    }
}
