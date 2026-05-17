import FBSDKCoreKit

enum MetaTracker {
    static func track(_ event: String, parameters: [String: Any]? = nil) {
        var fbParams: [AppEvents.ParameterName: Any] = [:]
        if let parameters {
            for (key, value) in parameters {
                fbParams[AppEvents.ParameterName(key)] = value
            }
        }
        AppEvents.shared.logEvent(AppEvents.Name(event), parameters: fbParams)
    }

    // MARK: - Onboarding
    static func onboardingStarted()       { track("ob_step_1_hero") }
    static func subjectSelected()         { track("ob_step_2_subject_select") }
    static func danceSelected()           { track("ob_step_3_dance_select") }
    static func magicMomentShown()        { track("ob_step_4_magic_moment") }
    static func resultShown()             { track("ob_step_5_result") }
    static func trialEnabledShown()       { track("ob_step_6_trial_enabled") }
    static func paywallShown()            { track("ob_step_7_paywall") }

    // MARK: - Special Offer
    static func surpriseOfferShown()      { track("surprise_offer_shown") }
    static func surpriseOfferPaywallShown() { track("surprise_offer_paywall_shown") }

    // MARK: - Purchase
    static func subscriptionPurchased(productId: String, price: Double, currency: String) {
        AppEvents.shared.logPurchase(amount: price, currency: currency, parameters: [
            AppEvents.ParameterName("product_id"): productId
        ])
    }
}
