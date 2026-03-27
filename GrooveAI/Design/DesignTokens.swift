import SwiftUI

// MARK: - Colors
extension Color {
    // Backgrounds — near-black premium (was navy)
    static let bgPrimary = Color(red: 0.04, green: 0.04, blue: 0.04)     // #0A0A0A
    static let bgSecondary = Color(red: 0.10, green: 0.10, blue: 0.10)   // #1A1A1A
    static let bgElevated = Color(red: 0.15, green: 0.15, blue: 0.15)    // #252525

    // Text
    static let textPrimary = Color(red: 0.97, green: 0.98, blue: 0.99)   // #F8FAFC
    static let textSecondary = Color(red: 0.58, green: 0.64, blue: 0.72) // #94A3B8
    static let textTertiary = Color(red: 0.40, green: 0.45, blue: 0.53)  // #64748B

    // Accent gradient — blue → purple (matches Dance AI)
    static let accentStart = Color(red: 0.23, green: 0.51, blue: 0.96)   // #3B82F6 blue
    static let accentEnd = Color(red: 0.55, green: 0.36, blue: 0.96)     // #8B5CF6 purple

    // Coins
    static let coinGold = Color(red: 0.96, green: 0.62, blue: 0.04)      // #F59E0B

    // Feedback
    static let success = Color(red: 0.13, green: 0.77, blue: 0.37)       // #22C55E
    static let error = Color(red: 0.94, green: 0.27, blue: 0.27)         // #EF4444
    static let warning = Color(red: 0.92, green: 0.70, blue: 0.03)       // #EAB308
}

// MARK: - Accent Gradient
extension LinearGradient {
    static let accent = LinearGradient(
        colors: [Color.accentStart, Color.accentEnd],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Spacing (8pt grid)
enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

// MARK: - Corner Radii
enum Radius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let full: CGFloat = 9999
}

// MARK: - Animations
enum AppAnimation {
    static let tapResponse = Animation.spring(response: 0.3, dampingFraction: 0.6)
    static let cardTransition = Animation.spring(response: 0.5, dampingFraction: 0.8)
    static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.5)
    static let gentle = Animation.spring(response: 0.6, dampingFraction: 0.9)
    static let snappy = Animation.snappy(duration: 0.18)
}
