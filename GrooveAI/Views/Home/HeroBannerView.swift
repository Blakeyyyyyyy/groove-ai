import SwiftUI

// MARK: - Hero Banner (Home screen, above presets)
// Full-width collage image card with "Try now" label beneath
struct HeroBannerView: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                Image("HomepageCollage")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                Text("Try now")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    HeroBannerView(onTap: {})
        .padding()
        .background(Color.bgPrimary)
}
