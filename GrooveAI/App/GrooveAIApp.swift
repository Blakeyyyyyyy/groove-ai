import SwiftUI
import SwiftData
import UIKit
import UserNotifications
import AppTrackingTransparency
import FBSDKCoreKit
import RevenueCat
import SuperwallKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        ApplicationDelegate.shared.application(
            app,
            open: url,
            sourceApplication: options[.sourceApplication] as? String,
            annotation: options[.annotation] as Any
        )
    }
}

@main
struct GrooveAIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()
    @Environment(\.modelContext) var modelContext
    @Environment(\.scenePhase) private var scenePhase
    // Guards against the first scenePhase → .active firing on launch (same sync
    // already runs in .task below — without this flag, syncWithServer fires twice).
    @State private var hasCompletedInitialLaunch = false

    init() {
        Self.configureTabBarAppearance()
        // Prefetch onboarding videos to disk so subsequent launches load instantly.
        // On first launch these download in background while the user reads onboarding;
        // every subsequent launch plays from local disk — zero network latency.
        VideoCache.shared.prefetch([
            // All home-screen presets
            "https://videos.trygrooveai.com/presets/big-guy-V5-AI.mp4",
            "https://videos.trygrooveai.com/presets/c-walk-V5-AI.mp4",
            "https://videos.trygrooveai.com/presets/trag-V5-AI.mp4",
            "https://videos.trygrooveai.com/presets/baby-boombastic.mp4",
            "https://videos.trygrooveai.com/presets/milkshake-V5-AI.mp4",
            "https://videos.trygrooveai.com/presets/ophelia-ai.mp4",
            "https://videos.trygrooveai.com/presets/coco-channel-75fcae6c.mp4",
            "https://videos.trygrooveai.com/presets/jenny-ai.mp4",
            "https://videos.trygrooveai.com/presets/macarena-V5-AI.mp4",
            "https://videos.trygrooveai.com/presets/witch-doctor-v3.mp4",
            "https://videos.trygrooveai.com/presets/cotton-eye-joe.mp4",
            // Demo videos for onboarding reveal
            "https://videos.trygrooveai.com/woman-coco-channel.mp4",
            "https://videos.trygrooveai.com/woman-big-guy.mp4",
            "https://videos.trygrooveai.com/demos/golden-retriever-big-guy.mp4",
            "https://videos.trygrooveai.com/demos/golden-retriever-coco-channel.mp4",
            "https://videos.trygrooveai.com/demos/golden-retriever-c-walk.mp4",
        ])
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(.dark)
                .task {
                    if let userId = appState.userId {
                        RevenueCatService.shared.configureWithUserId(userId)
                    } else {
                        RevenueCatService.shared.configure()
                    }

                    // Pass Facebook Anonymous ID to RevenueCat so Meta CAPI fires on purchase.
                    // Available regardless of ATT consent — not IDFA.
                    Purchases.shared.attribution.setAttributes(["$fbAnonId": AppEvents.shared.anonymousID])

                    // Configure Superwall AFTER RevenueCat so the purchase controller
                    // can route purchases through Purchases.shared. Superwall.configure
                    // internally no-ops if called more than once, and the .task modifier
                    // only fires once per ContentView lifetime, so this is safe on
                    // scene re-creation.
                    let purchaseController = RCPurchaseController()
                    Superwall.configure(apiKey: "pk_ECkhs6Rv0polCPRF03SbD", purchaseController: purchaseController)
                    purchaseController.syncSubscriptionStatus()
                    if let userId = appState.userId {
                        Superwall.shared.identify(userId: userId)
                    }

                    // Run server sync and RevenueCat premium check in parallel
                    async let serverSync: Void = appState.syncWithServer()
                    async let premiumCheck = RevenueCatService.shared.checkPremium()
                    let (_, isPremium) = await (serverSync, premiumCheck)
                    appState.isSubscribed = isPremium

                    // Check weekly coin reset
                    CoinsService.checkWeeklyReset()

                    // Hydrate videos in background — don't await, avoids blocking launch path
                    if let userId = appState.userId {
                        Task(priority: .utility) {
                            await hydrateVideosFromSupabase(userId: userId)
                        }
                    }
                    hasCompletedInitialLaunch = true

                    // App Tracking Transparency — fire on launch so attribution
                    // is captured for the entire session. 1s delay lets the
                    // root UI render first; iOS silently ignores the request
                    // if it fires before the app is visible.
                    await requestATTOnLaunch()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    // Re-check entitlements every time the app returns to the
                    // foreground. Guard against first .active on launch — that
                    // sync already runs in .task above.
                    guard newPhase == .active, hasCompletedInitialLaunch else { return }
                    Task {
                        await appState.syncWithServer()
                        let isPremium = await RevenueCatService.shared.checkPremium()
                        await MainActor.run {
                            appState.isSubscribed = isPremium
                        }
                    }
                }
        }
        .modelContainer(for: [GeneratedVideo.self])
    }

    /// Request App Tracking Transparency authorization on app launch.
    /// If already determined, syncs the existing decision into Meta SDK. If
    /// not determined, waits 1s for the root view to appear (Apple requires
    /// the app UI to be visible before the dialog renders, otherwise it is
    /// silently ignored on some iOS versions), then presents the system prompt.
    @MainActor
    private func requestATTOnLaunch() async {
        let status = ATTrackingManager.trackingAuthorizationStatus
        if status == .notDetermined {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s for UI to settle
            let result = await ATTrackingManager.requestTrackingAuthorization()
            #if DEBUG
            print("[ATT] requested on launch -> status=\(result.rawValue)")
            #endif
        } else {
            #if DEBUG
            print("[ATT] already determined on launch -> status=\(status.rawValue)")
            #endif
        }
    }

    /// Fetch videos from Supabase for the current user and hydrate SwiftData.
    /// Gracefully handles network failures by continuing with local data.
    private func hydrateVideosFromSupabase(userId: String) async {
        #if DEBUG
        print("[App] 🔄 Fetching videos from Supabase for userId: \(userId)")
        #endif
        do {
            let remoteVideos = try await SupabaseService.shared.getVideos(userId: userId)
            #if DEBUG
            print("[App] ✅ Fetched \(remoteVideos.count) videos from Supabase")
            #endif
            guard !remoteVideos.isEmpty else { return }

            await MainActor.run {
                // One batch fetch for all local IDs — avoids N separate queries that each
                // block the main thread. Old code called modelContext.fetch() once per video.
                let existingIds = Set(
                    (try? modelContext.fetch(FetchDescriptor<GeneratedVideo>()))?.map { $0.id } ?? []
                )

                var inserted = 0
                for videoData in remoteVideos {
                    guard let videoId = videoData["video_id"] as? String,
                          !existingIds.contains(videoId) else { continue }

                    let presetId = videoData["dance_style"] as? String ?? "unknown"
                    let videoURL = videoData["video_url"] as? String
                    let completedAt = Self.parseDate(videoData["completed_at"] as? String)

                    modelContext.insert(GeneratedVideo(
                        id: videoId,
                        dancePresetID: presetId,
                        danceName: presetId,
                        videoURL: videoURL,
                        status: "completed",
                        completedAt: completedAt,
                        userId: userId
                    ))
                    inserted += 1
                }

                if inserted > 0 {
                    try? modelContext.save()
                    #if DEBUG
                    print("[App] ✅ Hydrated \(inserted) new videos")
                    #endif
                }
            }
        } catch {
            // Network failure or server error — continue with local data
            #if DEBUG
            print("[App] ⚠️ Failed to fetch videos from Supabase: \(error.localizedDescription)")
            print("[App] 📱 Continuing with local videos only")
            #endif
        }
    }

    /// Parse ISO 8601 date string from Supabase
    private static func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateString)
    }

    private static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        appearance.backgroundColor = UIColor.clear
        appearance.shadowColor = UIColor.clear

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

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().unselectedItemTintColor = UIColor.white.withAlphaComponent(0.58)
    }
}
