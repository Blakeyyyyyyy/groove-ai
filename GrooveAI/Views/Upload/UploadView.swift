import SwiftUI

struct UploadView: View {
    let preset: DancePreset
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedImage: UIImage?
    @State private var showPhotoPicker = false
    @State private var showInsufficientCoinsAlert = false
    @State private var showNotificationModal = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            // Dance name reminder
            Text(preset.name)
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
                .padding(.top, Spacing.lg)

            Spacer()

            // Upload card — no dashed borders (lessons.md rule)
            Button {
                showPhotoPicker = true
            } label: {
                uploadCard
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, Spacing.lg)

            // Coins info
            CoinsInfoRow(
                used: appState.coinsUsed,
                total: appState.coinsTotal,
                costPerGeneration: appState.coinCostPerGeneration,
                resetDay: "Monday"
            )
            .padding(.horizontal, Spacing.lg)

            Spacer()

            // Generate button
            GradientCTAButton(
                selectedImage != nil ? "Generate" : "Select a Photo First",
                isEnabled: selectedImage != nil && appState.hasEnoughCoins
            ) {
                if !appState.hasEnoughCoins {
                    showInsufficientCoinsAlert = true
                } else {
                    startGeneration()
                }
            }
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
        .alert("Not Enough Coins", isPresented: $showInsufficientCoinsAlert) {
            Button("Manage Subscription") {
                // TODO: RevenueCat management
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your coins reset Monday. Come back then or manage your subscription.")
        }
    }

    @ViewBuilder
    private var uploadCard: some View {
        ZStack {
            if let selectedImage {
                // Photo selected — fills card
                Image(uiImage: selectedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 260)
                    .clipped()
                    .overlay(alignment: .bottom) {
                        Text("Change Photo")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.textPrimary)
                            .padding(.vertical, Spacing.sm)
                            .padding(.horizontal, Spacing.lg)
                            .background(Color.bgElevated.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                            .padding(.bottom, Spacing.md)
                    }
            } else {
                // Empty state — solid card, no dashed border
                VStack(spacing: Spacing.lg) {
                    Image(systemName: "figure.dance")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.accentStart)

                    VStack(spacing: Spacing.xs) {
                        Text("Drop your photo here")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.textPrimary)

                        Text("Person, pet, or baby — any photo works")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl)
                .stroke(Color.bgElevated, lineWidth: 1)
        )
    }

    private func startGeneration() {
        appState.useCoins()
        let jobId = UUID().uuidString
        appState.startGeneration(jobId: jobId)

        if !appState.hasRequestedNotificationPermission {
            showNotificationModal = true
        } else {
            finishGeneration()
        }
    }

    private func finishGeneration() {
        // Pop back to Home — the generating pill will be visible
        appState.selectedTab = .home
        dismiss()
    }
}

#Preview {
    NavigationStack {
        UploadView(preset: DancePreset.allPresets[0])
            .environment(AppState())
    }
}
