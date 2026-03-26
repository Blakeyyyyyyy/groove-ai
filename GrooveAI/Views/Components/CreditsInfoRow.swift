import SwiftUI

struct CreditsInfoRow: View {
    let used: Int
    let total: Int
    let costPerGeneration: Int
    let resetDay: String

    var remaining: Int { max(0, total - used) }
    var hasEnough: Bool { remaining >= costPerGeneration }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundStyle(hasEnough ? Color.accentStart : Color.error)

                if hasEnough {
                    Text("This generation uses \(costPerGeneration) credits")
                        .font(.subheadline)
                        .foregroundStyle(Color.textPrimary)
                } else {
                    Text("Not enough credits — resets \(resetDay)")
                        .font(.subheadline)
                        .foregroundStyle(Color.error)
                }
            }

            Text("You have \(remaining) remaining this week")
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(Color.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        CreditsInfoRow(used: 60, total: 150, costPerGeneration: 60, resetDay: "Monday")
        CreditsInfoRow(used: 150, total: 150, costPerGeneration: 60, resetDay: "Monday")
    }
    .padding()
    .background(Color.bgPrimary)
}
