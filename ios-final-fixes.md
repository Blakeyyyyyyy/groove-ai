# iOS Final Fixes — Pre-App-Store Submission
Date: 2026-04-29

## TASK 1: Privacy/Terms URL Correction — DONE

All `https://grooveai.app/*` web URLs replaced with `https://trygrooveai.com/*`.

**Files changed:**
- `GrooveAI/Views/Settings/TermsView.swift` — fallback remote URL + support email
- `GrooveAI/Views/Settings/PrivacyPolicyView.swift` — fallback remote URL
- `GrooveAI/Views/Paywall/GrooveSpecialOfferView.swift` — Privacy Policy footer button

**Note:** `com.grooveai.app` in `Models/AppState.swift` is a Keychain service identifier (bundle ID style), NOT a URL. It was intentionally left unchanged.

Verification: `grep -rn "grooveai.app" GrooveAI/ --include="*.swift" | grep -v "com.grooveai.app"` returns 0 results.

---

## TASK 2: Terms + Privacy Disclosure on First Onboarding Screen — DONE

**File changed:** `GrooveAI/Onboarding/Views/GrooveHeroScrollView.swift`

Added the required disclosure HStack below the "Make yours →" CTA button, outside any scroll view, always visible without scrolling. Links to `https://trygrooveai.com/terms` and `https://trygrooveai.com/privacy`. Inherits the `contentVisible` fade-in animation for visual consistency.

---

## TASK 3: "Free Trial" Text — REPORTED (no changes made)

**Occurrences found:**
1. `GrooveAI/Onboarding/Views-v2/TrialEnabledScreenV2.swift:49` — `Text("7-day free trial enabled")` — display text shown in an animated pre-paywall screen
2. `GrooveAI/Onboarding/Views/TrialEnabledScreen.swift:29` — `Text("7 day trial enabled")` — same screen, older non-V2 version (the live version used in `GrooveOnboardingView` is `TrialEnabledScreen`, the non-V2 struct)

**RevenueCat offer type:** The codebase uses `storeProduct.introductoryDiscount` throughout (not `.freeTrial` offer type). This is a discounted introductory price, not a zero-cost free trial. The "7-day free trial" text in the UI does NOT match the actual offer type — the app shows "7-day free trial" language but the underlying product is a discounted first week, not a free period.

**Recommendation for Blake:** Either (a) remove the TrialEnabledScreen from the flow (currently page 6 in `GrooveOnboardingView`) since there is no actual free trial, or (b) update the text to say something like "First week discounted" to accurately represent the offer. Apple may flag the discrepancy during review.

---

## TASK 4: GROOVE_API_KEY Wired to All Backend Requests — DONE

**File changed:** `GrooveAI/Services/SupabaseService.swift`

Added `private let apiKey = "<REDACTED — see GrooveAI/Config/Config.xcconfig>"` near the top of the class.

Added `request.setValue(apiKey, forHTTPHeaderField: "x-api-key")` to all 13 backend request sites:

| Method | Endpoint | Type |
|--------|----------|------|
| `register()` | POST /register | POST |
| `getUser()` | GET /user/:id | GET (converted to URLRequest) |
| `refundCoins()` | POST /refund-coins | POST |
| `updateSubscriptionExpiry()` | POST /update-subscription-expiry | POST |
| `addCoins()` | POST /add-coins | POST |
| `getVideos()` | GET /videos/:userId | GET (converted to URLRequest) |
| `getPresets()` | GET /presets | GET (converted to URLRequest) |
| `getPresignedUploadURL()` | POST /upload-presigned | POST |
| `processImage()` | POST /process-image | multipart POST |
| `classifyImage()` | POST /classify-image | POST |
| `generateVideo()` | POST /generate-video | POST |
| `checkVideoStatus()` | GET /video-status/:taskId | GET (converted to URLRequest) |
| `saveVideo()` | POST /save-video | POST |

GET endpoints that previously used `URLSession.shared.data(from: url)` were converted to `URLRequest` form to allow setting the header.

---

## Git Commit

All changes committed locally (not pushed) in commit `91a084e`:
> fix: correct privacy URLs, add onboarding disclosure, wire API key to all backend requests
