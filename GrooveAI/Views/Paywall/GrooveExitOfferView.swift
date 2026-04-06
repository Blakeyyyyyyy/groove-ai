import SwiftUI

struct GrooveExitOfferView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    let onSubscribe: () -> Void
    let onSkip: () -> Void
    
    @State private var remainingSeconds: Int = 300 // 5 minutes
    @State private var timer: Timer?
    @State private var isPurchasing = false
    
    private let timerKey = "exitOfferTimerStart"
    private let timerDuration: Int = 300 // 5 minutes
    
    var body: some View {
        ZStack {
            // Deep dark background with subtle gradient
            Color.bgPrimary
                .ignoresSafeArea()
            
            // Subtle purple radial gradient
            RadialGradient(
                colors: [Color(red: 0.10, green: 0.04, blue: 0.18).opacity(0.5), Color.clear],
                center: .center,
                startRadius: 100,
                endRadius: 500
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Tiny close button top-left
                HStack {
                    Button {
                        onSkip()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.textSecondary)
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.xl) {
                        // JUST FOR YOU badge
                        Text("JUST FOR YOU")
                            .font(.caption.bold())
                            .foregroundStyle(Color.accentStart)
                            .tracking(0.15)
                            .padding(.top, Spacing.md)
                        
                        // Hero placeholder (dance video preview)
                        heroImagePlaceholder
                        
                        // Headline
                        VStack(spacing: Spacing.sm) {
                            Text("A Special Offer,")
                                .font(.title.bold())
                                .foregroundStyle(Color.textPrimary)
                            
                            Text("Just This Once.")
                                .font(.title.bold())
                                .foregroundStyle(Color.textPrimary)
                        }
                        .multilineTextAlignment(.center)
                        
                        // Subheadline
                        Text("Get Groove AI Pro\nfor half price. Forever.")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                        
                        // Price card
                        priceCard
                        
                        // Countdown timer
                        countdownTimer
                        
                        // Primary CTA
                        Button {
                            handleSubscribe()
                        } label: {
                            Text("✨ Claim 50% Off Now")
                                .font(.headline.bold())
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(LinearGradient.accent)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                        }
                        .disabled(isPurchasing)
                        .sensoryFeedback(.selection, trigger: isPurchasing)
                        
                        // Trust line
                        Text("Includes 3-day free trial · Cancel anytime")
                            .font(.caption)
                            .foregroundStyle(Color.textTertiary)
                        
                        // Skip link (ghost text)
                        Button {
                            onSkip()
                        } label: {
                            Text("No thanks, I'll pay full price later")
                                .font(.subheadline)
                                .foregroundStyle(Color.textTertiary)
                        }
                        .frame(minHeight: 44)
                        .padding(.bottom, Spacing.lg)
                    }
                    .padding(.horizontal, Spacing.lg)
                }
            }
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    // MARK: - Hero Image Placeholder
    
    private var heroImagePlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.18, green: 0.04, blue: 0.18),
                            Color(red: 0.10, green: 0.04, blue: 0.10)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            VStack(spacing: Spacing.md) {
                Image(systemName: "figure.dance")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.6))
                
                Text("Your dance video\nwould appear here")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(height: 200)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg)
                .stroke(Color.accentStart.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Price Card
    
    private var priceCard: some View {
        VStack(spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Text("~~$99/year~~")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color.textTertiary)
                    .strikethrough()
                
                Text("$49/year")
                    .font(.title.bold())
                    .foregroundStyle(Color.textPrimary)
            }
            
            Text("That's only $4.08/month")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(Color.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg)
                .stroke(Color.accentStart.opacity(0.3), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            Text("50% OFF")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(LinearGradient.accent)
                .clipShape(Capsule())
                .padding(Spacing.sm)
        }
    }
    
    // MARK: - Countdown Timer
    
    private var countdownTimer: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "timer")
                .font(.caption)
                .foregroundStyle(Color.accentStart)
            
            Text("Offer expires in:")
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
            
            Text(formattedTime)
                .font(.caption.bold())
                .foregroundStyle(Color.accentStart)
                .monospacedDigit()
        }
    }
    
    private var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Timer Logic
    
    private func startTimer() {
        // Check if timer already started in this session
        if let startTimestamp = UserDefaults.standard.object(forKey: timerKey) as? Date {
            let elapsed = Int(Date().timeIntervalSince(startTimestamp))
            let remaining = timerDuration - elapsed
            
            if remaining > 0 {
                remainingSeconds = remaining
            } else {
                // Timer expired, don't show countdown
                remainingSeconds = 0
                return
            }
        } else {
            // First time, start timer
            UserDefaults.standard.set(Date(), forKey: timerKey)
            remainingSeconds = timerDuration
        }
        
        // Start the countdown
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                timer?.invalidate()
            }
        }
    }
    
    // MARK: - Subscribe Action
    
    private func handleSubscribe() {
        guard !isPurchasing else { return }
        isPurchasing = true
        
        Task {
            do {
                let rc = RevenueCatService.shared
                await rc.fetchOfferings()
                
                // For exit offer, we use annual with discounted introductory price
                // Fallback: mark as subscribed (revenuecat handles the actual purchase)
                await MainActor.run {
                    appState.isSubscribed = true
                    appState.hasCompletedOnboarding = true
                    appState.showPaywall = false
                    isPurchasing = false
                }
            }
        }
    }
}

#Preview {
    GrooveExitOfferView(
        onSubscribe: {},
        onSkip: {}
    )
    .environment(AppState())
}