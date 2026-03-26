import SwiftUI

struct SettingsRow: View {
    let icon: String?
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(Color.accentStart)
                        .frame(width: 24)
                }

                Text(label)
                    .font(.body)
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.textTertiary)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        SettingsRow(icon: "questionmark.circle", label: "Help & FAQ") {}
        Divider().overlay(Color.bgElevated)
        SettingsRow(icon: nil, label: "Contact Support") {}
    }
    .padding()
    .background(Color.bgSecondary)
    .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
    .padding()
    .background(Color.bgPrimary)
}
