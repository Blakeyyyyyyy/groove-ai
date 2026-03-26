import SwiftUI

struct UploadView: View {
    let preset: DancePreset
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedImage: UIImage?
    @State private var showPhotoPicker = false
    @State private var showInsufficientCreditsAlert = false
    @State private var showNotificationModal = false
    @State private var navigateToHome = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            // Dance name reminder
            Text(preset.name)
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
                .padding(.top, Spacing.lg)

            Spacer()

            // Upload card
            Button {
                showPhotoPicker = true
            } label: {
                uploadCard
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, Spacing.lg)

            // Credits info
            CreditsInfoRow(
                used: appState.creditsUsed,
                total: appState.creditsTotal,
                costPerGeneration: appState.creditCostPerGeneration,
                resetDay: "Monday"
            )
            .padding(.horizontal, Spacing.lg)

            Spacer()

            // Generate button
            GradientCTAButton(
                selectedImage != nil ? "Generate" : "Select a Photo First",
                isEnabled: selectedImage != nil && appState.hasEnoughCredits
            ) {
                if !appState.hasEnoughCredits {
                    showInsufficientCreditsAlert = true
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
        .alert("Not Enough Credits", isPresented: $showInsufficientCreditsAlert) {
            Button("Manage Subscription") {
                // TODO: RevenueCat management
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your credits reset Monday. Come back then or manage your subscription.")
        }
    }

    @ViewBuilder
    private var uploadCard: some View {
        ZStack {
            if let selectedImage {
                // Photo selected
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
                // Empty state
                VStack(spacing: Spacing.lg) {
                    Image(systemName: "person.crop.rectangle.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(LinearGradient.accent)

                    VStack(spacing: Spacing.xs) {
                        Text("Upload Your Photo")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.textPrimary)

                        Text("Tap to choose from your Camera Roll")
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
        appState.useCredits()
        appState.isGenerating = true
        appState.generationFailed = false
        appState.minutesRemaining = 10
        appState.generatingVideoID = UUID().uuidString

        // Save photo data for the video record
        // In a real app, this would upload to R2 and trigger backend

        if !appState.hasRequestedNotificationPermission {
            showNotificationModal = true
        } else {
            finishGeneration()
        }
    }

    private func finishGeneration() {
        // Pop back to Home - the generating pill will be visible
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
