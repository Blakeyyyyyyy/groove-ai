import SwiftUI
import SwiftData
import UIKit
import UserNotifications

@main
struct GrooveAIApp: App {
    @State private var appState = AppState()
    @Environment(\.modelContext) var modelContext
    @Environment(\.scenePhase) private var scenePhase
    // Guards against the first scenePhase → .active firing on launch (same sync
    // already runs in .task below — without this flag, syncWithServer fires twice).
    @State private var hasCompletedInitialLaunch = false

    init() {
        Self.configureTabBarAppearance()
        // Pre-warm AVPlayerPoolManager on background thread. The pool creation
        // is synchronous but heavy (~1s for 6 AVQueuePlayers). Running it here
        // means it completes well before HomeView renders (splash takes 3.4s).
        DispatchQueue.global(qos: .userInitiated).async {
            _ = AVPlayerPoolManager.shared
        }
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
