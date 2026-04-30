import Foundation

/// Disk-backed video cache. Downloads MP4s to Caches/groove_videos/ so subsequent
/// launches load from disk instead of re-downloading. URLSession handles the actual
/// download; the actor serialises concurrent requests for the same URL.
actor VideoCache {
    static let shared = VideoCache()

    private let cacheDir: URL
    private var inFlight: [String: Task<URL, Error>] = [:]

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDir = caches.appendingPathComponent("groove_videos", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    /// Returns the local file URL if the video is already on disk, else nil.
    func cachedURL(for urlString: String) -> URL? {
        let local = localPath(for: urlString)
        return FileManager.default.fileExists(atPath: local.path) ? local : nil
    }

    /// Downloads the video to disk and returns the local URL. Deduplicates
    /// concurrent requests for the same URL. Returns cached URL immediately
    /// if already on disk.
    func download(_ urlString: String) async throws -> URL {
        if let cached = cachedURL(for: urlString) { return cached }
        if let task = inFlight[urlString] { return try await task.value }

        let dest = localPath(for: urlString)
        let task = Task<URL, Error> {
            guard let remote = URL(string: urlString) else { throw URLError(.badURL) }
            let (temp, _) = try await URLSession.shared.download(from: remote)
            try FileManager.default.moveItem(at: temp, to: dest)
            return dest
        }

        inFlight[urlString] = task
        do {
            let url = try await task.value
            inFlight.removeValue(forKey: urlString)
            return url
        } catch {
            inFlight.removeValue(forKey: urlString)
            throw error
        }
    }

    /// Fire-and-forget prefetch. Silently ignores failures.
    func prefetch(_ urls: [String]) {
        Task.detached(priority: .background) {
            for url in urls {
                try? await self.download(url)
            }
        }
    }

    private func localPath(for urlString: String) -> URL {
        let hash = abs(urlString.hashValue)
        let ext = URL(string: urlString)?.pathExtension ?? "mp4"
        return cacheDir.appendingPathComponent("\(hash).\(ext)")
    }
}
