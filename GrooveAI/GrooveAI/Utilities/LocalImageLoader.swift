import UIKit

enum LocalImageLoader {
    private static let workspaceRoot = "/Users/blakeyyyclaw/.openclaw/workspace/groove-ai"

    static func loadImage(named name: String, fallbackPaths: [String] = []) -> UIImage? {
        if let image = UIImage(named: name) {
            return image
        }

        let candidatePaths = [name] + fallbackPaths
        for path in candidatePaths {
            let absolutePath = path.hasPrefix("/") ? path : "\(workspaceRoot)/\(path)"
            if let image = UIImage(contentsOfFile: absolutePath) {
                return image
            }
        }

        return nil
    }
}
