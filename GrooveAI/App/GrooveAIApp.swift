import SwiftUI
import SwiftData
import UIKit
import UserNotifications

@main
struct GrooveAIApp: App {
    @State private var appState = AppState()
    @Environment(\.modelContext) var modelContext

    init() {
        Self.configureTabBarAppearance()
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

                    // Sync user data from server
                    await appState.syncWithServer()

                    // Check subscription status via RevenueCat
                    let isPremium = await RevenueCatService.shared.checkPremium()
                    if isPremium {
                        appState.isSubscribed = true
                    }

                    // Check weekly coin reset
                    CoinsService.checkWeeklyReset()

                    // Fetch and hydrate videos from Supabase if user is authenticated
                    if let userId = appState.userId {
                        await hydrateVideosFromSupabase(userId: userId)
                    }
                }
        }
        .modelContainer(for: [GeneratedVideo.self])
    }

    /// Fetch videos from Supabase for the current user and hydrate SwiftData.
    /// Gracefully handles network failures by continuing with local data.
    private func hydrateVideosFromSupabase(userId: String) async {
        print("[App] 🔄 Fetching videos from Supabase for userId: \(userId)")
        do {
            let remoteVideos = try await SupabaseService.shared.getVideos(userId: userId)
            print("[App] ✅ Fetched \(remoteVideos.count) videos from Supabase")

            // Map Supabase video data to GeneratedVideo models
            await MainActor.run {
                for videoData in remoteVideos {
                    guard let videoId = videoData["video_id"] as? String else { continue }

                    // Check if video already exists locally
                    let descriptor = FetchDescriptor<GeneratedVideo>(
                        predicate: #Predicate { $0.id == videoId }
                    )
                    let existingVideos = try? modelContext.fetch(descriptor)

                    if existingVideos?.isEmpty ?? true {
                        // Create new local record from Supabase data
                        let presetId = videoData["dance_style"] as? String ?? "unknown"
                        let videoURL = videoData["video_url"] as? String
                        let completedAtString = videoData["completed_at"] as? String
                        let completedAt = Self.parseDate(completedAtString)

                        let generatedVideo = GeneratedVideo(
                            id: videoId,
                            dancePresetID: presetId,
                            danceName: presetId,
                            videoURL: videoURL,
                            status: "completed",
                            completedAt: completedAt,
                            userId: userId
                        )
                        modelContext.insert(generatedVideo)
                        print("[App] 💾 Hydrated video: \(videoId)")
                    }
                }

                // Save all hydrated videos to SwiftData
                do {
                    try modelContext.save()
                    print("[App] ✅ Video hydration complete")
                } catch {
                    print("[App] ⚠️ Failed to save hydrated videos: \(error)")
                }
            }
        } catch {
            // Network failure or server error — continue with local data
            print("[App] ⚠️ Failed to fetch videos from Supabase: \(error.localizedDescription)")
            print("[App] 📱 Continuing with local videos only")
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
