import SwiftUI

struct DancePreviewView: View {
    let preset: DancePreset
    @Environment(\.dismiss) private var dismiss
    @State private var navigateToUpload = false

    var body: some View {
        VStack(spacing: 0) {
            // Sneak Peek header
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Sneak Peek")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)

                // Pill tags
                HStack(spacing: Spacing.sm) {
                    ForEach(preset.pillTags, id: \.self) { tag in
                        Text(tag)
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(Color.bgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.full))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)

            Spacer().frame(height: Spacing.lg)

            // Main video preview card
            ZStack {
                RoundedRectangle(cornerRadius: Radius.xxl)
                    .fill(Color.bgSecondary)

                VStack(spacing: Spacing.md) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(LinearGradient.accent)

                    Text(preset.name)
                        .font(.headline)
                        .foregroundStyle(Color.textPrimary)
                }
            }
            .aspectRatio(9/16, contentMode: .fit)
            .padding(.horizontal, Spacing.lg)

            Spacer().frame(height: Spacing.xl)

            // Validation line
            HStack(spacing: Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.success)

                Text("Works great with your photo")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()

            // CTA
            NavigationLink(value: "upload-\(preset.id)") {
                Text("Use This Dance →")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(LinearGradient.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            }
            .buttonStyle(ScaleButtonStyle())
            .sensoryFeedback(.success, trigger: navigateToUpload)
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Color.bgPrimary)
        .navigationTitle(preset.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(preset.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        DancePreviewView(preset: DancePreset.allPresets[0])
    }
}
