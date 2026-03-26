import SwiftUI

struct PageIndicatorDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == current ? AnyShapeStyle(LinearGradient.accent) : AnyShapeStyle(Color.bgElevated))
                    .frame(width: 8, height: 8)
                    .animation(AppAnimation.snappy, value: current)
            }
        }
    }
}

#Preview {
    PageIndicatorDots(count: 3, current: 1)
        .padding()
        .background(Color.bgPrimary)
}
