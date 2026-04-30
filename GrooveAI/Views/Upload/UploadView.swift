import SwiftUI

struct UploadView: View {
    let preset: DancePreset
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedImage: UIImage?
    @State private var showPhotoPicker = false
    @State private var showCoinsPurchasePaywall = false
    @State private var showSubscriptionPaywall = false
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
            .accessibilityIdentifier("upload_photo_button")
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
                // Routing rules:
                //  - Active subscriber + enough coins → generate
                //  - Active subscriber + not enough coins → coin packages paywall
                //  - Expired subscriber OR has any coins → coin packages paywall
                //  - True free user (never subscribed, no coins) → onboarding paywall
                if appState.hasEnoughCoins {
                    startGeneration()
                } else if appState.hasHadSubscription {
                    showCoinsPurchasePaywall = true
                } else {
                    showSubscriptionPaywall = true
                }
            } label: {
                Text(selectedImage != nil ? "Generate" : "Select a Photo First")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: 260)
                    .frame(height: 52)
                    .background(
                        selectedImage != nil
                            ? AnyShapeStyle(Color(red: 0.545, green: 0.361, blue: 0.957)) // #8B5CF6 solid purple
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
                    showPhotoPicker = false
                    withAnimation(AppAnimation.bouncy) {
                        selectedImage = image
                    }
                },
                onCancel: {
                    showPhotoPicker = false
                }
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
            .presentationBackground(.black)
        }
        .fullScreenCover(isPresented: $showSubscriptionPaywall) {
            GroovePaywallScreen(
                onPurchaseSuccess: {
                    showSubscriptionPaywall = false
                    if selectedImage != nil {
                        startGeneration()
                    }
                },
                onDismiss: {
                    showSubscriptionPaywall = false
                }
            )
        }
    }

    @ViewBuilder
    private var uploadCard: some View {
        ZStack {
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
                            .multilineTextAlignment(.center)

                        Text(preset.isFaceDance
                            ? "Face Dance requires a human face. Pet photos will not work for this style."
                            : "Works best with a clear photo of 1 person, full body visible.")
                            .font(.caption)
                            .foregroundStyle(Color.textTertiary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: 260)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.xl)
            }
        }
        .overlay(alignment: .bottom) {
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
        // 30% larger tap area for easier photo selection
        min(UIScreen.main.bounds.height * 0.55, 430)
    }

    private func startGeneration() {
        #if DEBUG
        print("[UploadView] 🟢 Generate button tapped")
        #endif
        guard let image = selectedImage else {
            #if DEBUG
            print("[UploadView] ❌ No image selected")
            #endif
            return
        }
        guard let photoData = image.jpegData(compressionQuality: 0.85) else {
            #if DEBUG
            print("[UploadView] ❌ Failed to convert image to JPEG data")
            #endif
            return
        }
        #if DEBUG
        print("[UploadView] 📸 Image converted to JPEG: \(photoData.count) bytes")
        #endif

        // Ask for notification permission first if needed, then fire generation
        if !appState.hasRequestedNotificationPermission {
            #if DEBUG
            print("[UploadView] 🔔 Showing notification permission modal first")
            #endif
            showNotificationModal = true
        } else {
            fireGeneration(photoData: photoData)
        }
    }

    private func fireGeneration(photoData: Data) {
        #if DEBUG
        print("[UploadView] 🚀 fireGeneration called — starting real generation")
        #endif

        // Optimistic UI deduction — drop balance by 60 immediately so the
        // user sees feedback the moment they tap Generate. Server response
        // from /api/generate-video reconciles serverCoins to the authoritative
        // value once the pipeline returns. If generation fails before the
        // server deducts, GenerationService issues a refund + server sync.
        appState.useCoins()
        #if DEBUG
        print("[UploadView] 🪙 Optimistically deducted \(appState.coinCostPerGeneration) coins. Local balance: \(appState.coinsRemaining)")
        #endif

        // Start generation ON MAIN ACTOR before navigating away
        // This ensures modelContext operations happen on the main queue
        generationService.startGeneration(
            preset: preset,
            photoData: photoData,
            appState: appState,
            modelContext: modelContext
        )

        #if DEBUG
        print("[UploadView] ✅ Generation started, navigating to home")
        #endif
        // Navigate away — generation continues in background via detached Task
        appState.selectedTab = .home
        dismiss()
    }

    private func finishGeneration() {
        #if DEBUG
        print("[UploadView] 🔔 Notification modal dismissed, finishing generation")
        #endif
        guard let image = selectedImage,
              let photoData = image.jpegData(compressionQuality: 0.85) else {
            #if DEBUG
            print("[UploadView] ❌ No image available after notification modal")
            #endif
            appState.selectedTab = .home
            dismiss()
            return
        }
        fireGeneration(photoData: photoData)
    }
}

#Preview {
    NavigationStack {
        UploadView(preset: DancePreset.allPresets[0])
            .environment(AppState())
    }
}
