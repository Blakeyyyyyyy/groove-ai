import SwiftUI

struct CoinsInfoRow: View {
    let used: Int
    let total: Int
    let costPerGeneration: Int
    let resetDay: String

    var remaining: Int { max(0, total - used) }
    var hasEnough: Bool { remaining >= costPerGeneration }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(hasEnough ? Color.coinGold : Color.error)

                if hasEnough {
                    Text("This generation uses \(costPerGeneration) coins")
                        .font(.subheadline)
                        .foregroundStyle(Color.textPrimary)
                } else {
                    Text("Not enough coins — resets \(resetDay)")
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
        CoinsInfoRow(used: 60, total: 150, costPerGeneration: 60, resetDay: "Monday")
        CoinsInfoRow(used: 150, total: 150, costPerGeneration: 60, resetDay: "Monday")
    }
    .padding()
    .background(Color.bgPrimary)
}
