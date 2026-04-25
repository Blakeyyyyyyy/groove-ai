import Foundation
import UIKit

class ImageCacheService {
    static let shared = ImageCacheService()

    private let cache = NSCache<NSString, UIImage>()

    let womanImageURL = "https://pub-c3256eacaaf4436c8f67e04fd794c190.r2.dev/demos/woman-onboarding.jpg"
    let dogImageURL = "https://pub-c3256eacaaf4436c8f67e04fd794c190.r2.dev/demos/Gemini_Generated_Image_1555co1555co1555%20copy.png"

    private init() {}

    func preloadImages() {
        Task {
            await loadAndCache(url: womanImageURL, key: "woman")
            await loadAndCache(url: dogImageURL, key: "dog")
            print("[ImageCache] ✅ Images preloaded")
        }
    }

    private func loadAndCache(url: String, key: String) async {
        guard let url = URL(string: url) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    self.cache.setObject(image, forKey: key as NSString)
                }
                print("[ImageCache] Cached: \(key)")
            }
        } catch {
            print("[ImageCache] Failed to load \(key): \(error)")
        }
    }

    func getImage(for subject: String) -> UIImage? {
        let key = subject == "person" ? "woman" : "dog"
        return cache.object(forKey: key as NSString)
    }
}
