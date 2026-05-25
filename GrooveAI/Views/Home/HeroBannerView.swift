import SwiftUI

// MARK: - Hero Banner (Home screen, above presets)
struct HeroBannerView: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                Image("HomepageCollage")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                LinearGradient(
                    colors: [.clear, .black.opacity(0.70)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))

                VStack(alignment: .leading, spacing: 4) {
                    Text("9 new presets added")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)

                    HStack(spacing: 4) {
                        Text("Try now")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    HeroBannerView(onTap: {})
        .padding()
        .background(Color.black)
}
