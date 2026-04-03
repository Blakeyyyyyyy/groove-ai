import SwiftUI

struct UploadView: View {
    let preset: DancePreset
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedImage: UIImage?
    @State private var showPhotoPicker = false
    @State private var showCoinsPurchasePaywall = false
    @State private var showNotificationModal = false
    private let generationService = GenerationService()

    var body: some View {
        VStack(spacing: 0) {
            // Preset name header — compact
            Text(preset.name)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.md)

            // Upload card — BIGGER: fills from just under preset name to above generate button
            Button {
                showPhotoPicker = true
            } label: {
                uploadCard
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, Spacing.lg)

            Spacer()

            // Coins cost — only shown AFTER photo is selected, ABOVE Generate button
            if selectedImage != nil {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "circle.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.coinGold)
                    Text("This will use \(appState.coinCostPerGeneration) coins")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.bottom, Spacing.md)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(AppAnimation.gentle, value: selectedImage != nil)
            }

            // Generate button — contained width, softer styling
            Button {
                if selectedImage == nil { return }
                // Generation guard: check coins >= 60 OR user is subscribed
                if !appState.isSubscribed && !appState.hasEnoughCoins {
                    showCoinsPurchasePaywall = true
                } else {
                    startGeneration()
                }
            } label: {
                Text(selectedImage != nil ? "Generate" : "Select a Photo First")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: 260)
                    .frame(height: 52)
                    .background(
                        selectedImage != nil
                            ? AnyShapeStyle(LinearGradient.accent)
                            : AnyShapeStyle(Color.bgElevated)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
                    .opacity(selectedImage != nil ? 1.0 : 0.4)
            }
            .buttonStyle(ScaleButtonStyle())
            .allowsHitTesting(selectedImage != nil)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Color.bgPrimary)
        .navigationTitle("Upload Photo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Upload Photo")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
            }
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker(
                onImageSelected: { image in
                    withAnimation(AppAnimation.bouncy) {
                        selectedImage = image
                    }
                },
                onCancel: {}
            )
        }
        .sheet(isPresented: $showNotificationModal) {
            NotificationPermissionView {
                showNotificationModal = false
                finishGeneration()
            } onDismiss: {
                showNotificationModal = false
                finishGeneration()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
            .presentationBackground(Color.bgSecondary)
        }
        .sheet(isPresented: $showCoinsPurchasePaywall) {
            GrooveCoinPurchaseSheet(onPurchaseComplete: {
                showCoinsPurchasePaywall = false
                // After purchase, retry generation if image is ready
                if selectedImage != nil {
                    startGeneration()
                }
            })
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.bgPrimary)
        }
    }

    @ViewBuilder
    private var uploadCard: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: Radius.xl)
                .fill(Color.bgSecondary)

            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                VStack(spacing: Spacing.lg) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.accentStart)

                    VStack(spacing: Spacing.xs) {
                        Text("Tap to add photo")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.textPrimary)

                        Text("Person, pet, or baby — any photo works")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, Spacing.xl)
            }

            if selectedImage != nil {
                Text("Change Photo")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.textPrimary)
                    .padding(.vertical, Spacing.sm)
                    .padding(.horizontal, Spacing.lg)
                    .background(Color.bgElevated.opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    .padding(.bottom, Spacing.md)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: heroCardHeight)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl)
                .stroke(Color.bgElevated, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
    }

    private var heroCardHeight: CGFloat {
        min(UIScreen.main.bounds.height * 0.42, 330)
    }

    private func startGeneration() {
        print("[UploadView] 🟢 Generate button tapped")
        guard let image = selectedImage else {
            print("[UploadView] ❌ No image selected")
            return
        }
        guard let photoData = image.jpegData(compressionQuality: 0.85) else {
            print("[UploadView] ❌ Failed to convert image to JPEG data")
            return
        }
        print("[UploadView] 📸 Image converted to JPEG: \(photoData.count) bytes")

        // Ask for notification permission first if needed, then fire generation
        if !appState.hasRequestedNotificationPermission {
            print("[UploadView] 🔔 Showing notification permission modal first")
            showNotificationModal = true
        } else {
            fireGeneration(photoData: photoData)
        }
    }

    private func fireGeneration(photoData: Data) {
        print("[UploadView] 🚀 fireGeneration called — starting real generation")

        // Start generation ON MAIN ACTOR before navigating away
        // This ensures modelContext operations happen on the main queue
        generationService.startGeneration(
            preset: preset,
            photoData: photoData,
            appState: appState,
            modelContext: modelContext
        )

        print("[UploadView] ✅ Generation started, navigating to home")
        // Navigate away — generation continues in background via detached Task
        appState.selectedTab = .home
        dismiss()
    }

    private func finishGeneration() {
        print("[UploadView] 🔔 Notification modal dismissed, finishing generation")
        guard let image = selectedImage,
              let photoData = image.jpegData(compressionQuality: 0.85) else {
            print("[UploadView] ❌ No image available after notification modal")
            appState.selectedTab = .home
            dismiss()
            return
        }
        fireGeneration(photoData: photoData)
    }
}

// MARK: - Coins Purchase Paywall (NOT subscription paywall)
struct CoinsPurchasePaywallView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer().frame(height: Spacing.xl)

            Image(systemName: "circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.coinGold)

            Text("Need More Coins")
                .font(.title2.bold())
                .foregroundStyle(Color.textPrimary)

            Text("Get more coins to keep creating amazing dance videos.")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxl)

            // Coin packages
            VStack(spacing: Spacing.md) {
                coinPackage(coins: 60, price: "$2.99", label: "1 Video")
                coinPackage(coins: 180, price: "$6.99", label: "3 Videos", badge: "Popular")
                coinPackage(coins: 600, price: "$19.99", label: "10 Videos", badge: "Best Value")
            }
            .padding(.horizontal, Spacing.lg)

            // Or upgrade
            VStack(spacing: Spacing.sm) {
                Text("or")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)

                Button("Upgrade to Pro — Unlimited") {
                    // TODO: Navigate to subscription paywall
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentStart)
                .frame(minHeight: 44)
            }

            Spacer()

            Button("Not Now") {
                onDismiss()
            }
            .font(.subheadline)
            .foregroundStyle(Color.textTertiary)
            .frame(minHeight: 44)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Color.bgPrimary)
    }

    @ViewBuilder
    private func coinPackage(coins: Int, price: String, label: String, badge: String? = nil) -> some View {
        Button {
            // TODO: IAP purchase
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack(spacing: Spacing.sm) {
                        Text("🪙 \(coins)")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.textPrimary)

                        if let badge {
                            Text(badge)
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(LinearGradient.accent)
                                .clipShape(Capsule())
                        }
                    }

                    Text(label)
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                Text(price)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
            }
            .padding(Spacing.lg)
            .background(Color.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(Color.bgElevated, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        UploadView(preset: DancePreset.allPresets[0])
            .environment(AppState())
    }
}
