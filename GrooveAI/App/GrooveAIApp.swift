import SwiftUI
import SwiftData
import UIKit

@main
struct GrooveAIApp: App {
    @State private var appState = AppState()

    init() {
        // Configure RevenueCat on launch
        RevenueCatService.shared.configure()
        Self.configureTabBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(.dark)
                .task {
                    // Sync user data from server
                    await appState.syncWithServer()

                    // Check subscription status via RevenueCat
                    let isPremium = await RevenueCatService.shared.checkPremium()
                    if isPremium {
                        appState.isSubscribed = true
                    }

                    // Check weekly coin reset
                    CoinsService.checkWeeklyReset()
                }
        }
        .modelContainer(for: [GeneratedVideo.self])
    }

    private static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        appearance.backgroundColor = UIColor.white.withAlphaComponent(0.04)
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.08)

        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white
        ]
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white.withAlphaComponent(0.58)
        ]

        let stacked = appearance.stackedLayoutAppearance
        stacked.selected.iconColor = .white
        stacked.selected.titleTextAttributes = selectedAttributes
        stacked.normal.iconColor = UIColor.white.withAlphaComponent(0.58)
        stacked.normal.titleTextAttributes = normalAttributes

        let inline = appearance.inlineLayoutAppearance
        inline.selected.iconColor = .white
        inline.selected.titleTextAttributes = selectedAttributes
        inline.normal.iconColor = UIColor.white.withAlphaComponent(0.58)
        inline.normal.titleTextAttributes = normalAttributes

        let compactInline = appearance.compactInlineLayoutAppearance
        compactInline.selected.iconColor = .white
        compactInline.selected.titleTextAttributes = selectedAttributes
        compactInline.normal.iconColor = UIColor.white.withAlphaComponent(0.58)
        compactInline.normal.titleTextAttributes = normalAttributes

        appearance.selectionIndicatorImage = tabSelectionIndicatorImage()

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().unselectedItemTintColor = UIColor.white.withAlphaComponent(0.58)
    }

    private static func tabSelectionIndicatorImage() -> UIImage? {
        let size = CGSize(width: 84, height: 34)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 17)

            context.cgContext.saveGState()
            context.cgContext.setShadow(
                offset: CGSize(width: 0, height: 6),
                blur: 16,
                color: UIColor.black.withAlphaComponent(0.18).cgColor
            )
            UIColor.white.withAlphaComponent(0.12).setFill()
            path.fill()
            context.cgContext.restoreGState()

            let highlightRect = CGRect(x: 1.5, y: 1.5, width: size.width - 3, height: 13)
            let highlightPath = UIBezierPath(roundedRect: highlightRect, cornerRadius: 11)
            UIColor.white.withAlphaComponent(0.09).setFill()
            highlightPath.fill()

            let glossColors = [
                UIColor.white.withAlphaComponent(0.12).cgColor,
                UIColor.white.withAlphaComponent(0.02).cgColor,
                UIColor.black.withAlphaComponent(0.08).cgColor
            ] as CFArray
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: glossColors,
                locations: [0.0, 0.42, 1.0]
            ) {
                context.cgContext.saveGState()
                path.addClip()
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: rect.midX, y: rect.minY),
                    end: CGPoint(x: rect.midX, y: rect.maxY),
                    options: []
                )
                context.cgContext.restoreGState()
            }

            UIColor.white.withAlphaComponent(0.12).setStroke()
            path.lineWidth = 0.75
            path.stroke()
        }
        .resizableImage(withCapInsets: UIEdgeInsets(top: 17, left: 42, bottom: 17, right: 42))
    }
}
