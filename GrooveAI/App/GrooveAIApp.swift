import SwiftUI
import SwiftData
import UIKit
import UserNotifications
import StoreKit

@main
struct GrooveAIApp: App {
    @State private var appState = AppState()
    @Environment(\.modelContext) var modelContext
    @Environment(\.scenePhase) private var scenePhase

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

                    // Run server sync and RevenueCat premium check in parallel
                    async let serverSync: Void = appState.syncWithServer()
                    async let premiumCheck = RevenueCatService.shared.checkPremium()
                    let (_, isPremium) = await (serverSync, premiumCheck)
                    appState.isSubscribed = isPremium

                    // Check weekly coin reset
                    CoinsService.checkWeeklyReset()

                    // Fetch and hydrate videos from Supabase if user is authenticated
                    if let userId = appState.userId {
                        await hydrateVideosFromSupabase(userId: userId)
                    }
                }
                // Catch any StoreKit 2 consumable transactions that were never finished
                // (e.g. app killed between purchase confirmation and server ACK).
                .task(id: "storeKitTransactionUpdates") {
                    for await verificationResult in StoreKit.Transaction.updates {
                        await processTransactionUpdate(verificationResult)
                    }
                }
                .task(id: "storeKitUnfinished") {
                    for await verificationResult in StoreKit.Transaction.unfinished {
                        await processTransactionUpdate(verificationResult)
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    // Re-check entitlements every time the app returns to the
                    // foreground. Users may have cancelled/refunded in
                    // Settings → Subscriptions while the app was backgrounded.
                    guard newPhase == .active else { return }
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

    /// Handles a StoreKit 2 transaction update — used for recovery of interrupted coin purchases.
    /// Called from Transaction.updates (external transactions) and Transaction.unfinished (crash recovery).
    private func processTransactionUpdate(_ verificationResult: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let transaction) = verificationResult else { return }

        // Only handle consumable coin purchases — subscriptions go through RevenueCat
        guard transaction.productType == .consumable else {
            await transaction.finish()
            return
        }

        guard let coins = CoinPackage.coinAmount(for: transaction.productID) else {
            print("[App] ⚠️ Unknown consumable productID in transaction: \(transaction.productID) — finishing without crediting")
            await transaction.finish()
            return
        }

        guard let userId = appState.userId else {
            print("[App] ⚠️ Transaction recovery skipped — userId not available yet for \(transaction.id)")
            return
        }

        let jws = verificationResult.jwsRepresentation
        do {
            _ = try await SupabaseService.shared.addCoins(userId: userId, amount: coins, type: "purchase", appleJWS: jws)
            await transaction.finish()
            print("[App] ✅ Recovered transaction \(transaction.id): +\(coins) coins")
            await appState.syncWithServer()
        } catch let nsError as NSError where nsError.code == 409 {
            // Already credited on a previous attempt — safe to finish
            await transaction.finish()
            print("[App] ✅ Transaction \(transaction.id) already credited (409) — finishing")
            await appState.syncWithServer()
        } catch {
            // Server error — do NOT finish. StoreKit will re-deliver on next launch.
            print("[App] ⚠️ Transaction recovery failed for \(transaction.id): \(error). Will retry.")
        }
    }

    /// Fetch videos from Supabase for the current user and hydrate SwiftData.
    /// Gracefully handles network failures by continuing with local data.
    private func hydrateVideosFromSupabase(userId: String) async {
        print("[App] 🔄 Fetching videos from Supabase for userId: \(userId)")
        do {
            let remoteVideos = try await SupabaseService.shared.getVideos(userId: userId)
            print("[App] ✅ Fetched \(remoteVideos.count) videos from Supabase")
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
                    print("[App] ✅ Hydrated \(inserted) new videos")
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
