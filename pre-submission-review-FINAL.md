# Groove AI — Pre-Submission Security Review (FINAL)
*Reviewed by: Opus (full audit) → Codex (cross-examination) → vibe-security (static scan)*
*Date: 2026-04-29*

---

## CRITICAL — Must fix before App Store submission

### 1. `/api/confirm-subscription` — Zero receipt verification (coin farming)
**File:** `index.js:1482-1543`
**Attack:** Anyone can POST `{user_id, product_id}` to this endpoint with their own UUID and receive coins for any product. By cycling all 7 subscription product IDs, an attacker mints 2,750 free coins per account. The dedup only blocks the same product_id being granted twice to the same user — it does not verify a real purchase occurred.
**Fix:** Add Apple receipt/JWS verification before granting coins. The `/api/add-coins` endpoint already has the correct JWS chain validation pattern — replicate that here. Alternatively, remove this endpoint entirely and rely solely on the RevenueCat webhook (which is properly verified).

### 2. Six unauthenticated IDOR endpoints
**No auth on:**
- `GET /api/user/:id` — returns full user record including coin balance
- `GET /api/videos/:userId` — returns user's full generation history
- `POST /api/refund-coins` — mints coins for synthetic video IDs (unlimited accumulation)
- `POST /api/generate-video` — spends coins and triggers generation
- `POST /api/save-video` — saves videos to any user's account
- `POST /api/update-subscription-expiry` — extends any user's subscription

**Attack:** Anyone with a valid UUID (leaked through logs or guessed) can spend their victim's coins, steal their videos, or mint refunds using synthetic video IDs.
**Fix:** Add `validateUserId` middleware to all these routes. The userId in the request body/params must match a verified session token, or at minimum add a shared secret header check.

### 3. `/api/upload-demo-video` — Unauthenticated SSRF + arbitrary R2 upload
**File:** `index.js:1881-1918`
**Problem:** No auth whatsoever. Accepts any `video_url`, fetches it server-side (SSRF — attacker can probe internal IPs, metadata endpoints, etc.), then uploads to your R2 videos bucket under any key name. Content-type is caller-controlled.
**Fix:** Delete this endpoint. It's a dev tool that should never ship.

### 4. Real ASC credentials hardcoded in client code
**File:** `GrooveAI/Services/RevenueCatAPISetup.swift:16-17`
**Problem:** Your real App Store Connect Key ID (`U57CPMC5A3`) and Issuer ID (`522d4ad3-ea99-4ec6-bf4e-0e133d775c41`) are in doc comments. Combined with the .p8 key file, these can generate tokens to manage your ASC account.
**Fix:** Delete `RevenueCatAPISetup.swift` entirely — it is 516 lines of dead code that is never instantiated anywhere in the app. Confirmed by Codex: zero references.

### 5. CORS is wide open
**File:** `index.js:96`
**Problem:** CORS allows all origins (`*`). Combined with the unauthenticated endpoints above, any malicious website can make API calls on behalf of your users.
**Fix:** Lock CORS to your actual domains: `https://trygrooveai.com` and your Render.com backend URL.

---

## HIGH — Strongly recommended before submission

### 6. 218 iOS `print()` statements not wrapped in `#if DEBUG`
**Scope:** Across multiple Swift files
**Problem:** Apple reviewers and testers can see all console output in Xcode's Console during review. Many of these log `user_id`, full coin balances, and complete API response bodies. `Purchases.logLevel = .debug` is also set unconditionally (not in DEBUG only).
**Fix:** Wrap all print() calls in `#if DEBUG / #endif`. Add `#if DEBUG` guard to `Purchases.logLevel = .debug`.

### 7. Two broken paywall buttons — Apple will reject this
**File:** `GrooveAI/Views/UploadView.swift:308, 331`
**Problem:** Two buttons inside a paywall sheet showing real prices have `// TODO: IAP purchase` comments and no action handlers — taps do nothing.
**Fix:** Wire up the purchase action or remove the buttons. Apple reviewers test paywall flows.

### 8. No coin cap — unlimited accumulation
**Problem:** The `/api/refund-coins` exploit (Issue #2) combined with no maximum coin limit means unlimited accumulation. Even after fixing auth, a rogue employee or compromised admin account has no safeguard.
**Fix:** Add a `MAX_COINS = 10000` cap in the coin update stored procedure.

### 9. `/api/video-status/:taskId` retry path — unauthenticated user_id
**File:** `index.js` — video-status endpoint retry logic
**Problem:** The retry path accepts `user_id` as a query parameter and uploads Gemini-generated images to that user's R2 prefix without verifying the caller owns that user_id.
**Fix:** Require user_id to be validated against the taskId ownership before processing.

---

## MEDIUM — Should fix

### 10. RevenueCat webhook logs token length (timing oracle)
**File:** `index.js:1286`
**Code:** `console.log(\`[RevenueCat] Auth check: provided_length=${...}, expected_length=${...}\`)`
**Problem:** Logs the expected token length to Render logs. Any attacker with log access can confirm the exact secret length, aiding brute force.
**Fix:** Remove this log line entirely. The webhook either passes or fails — no debug logging needed in production.

### 11. JWS payload logged to console
**File:** `index.js:1086`
**Code:** `console.log(\`[add-coins] ✅ JWS verified. Payload: appAccountToken=${...}, productId=${...}, transactionId=${...}\`)`
**Problem:** Logs Apple transaction details. Not a critical leak but unnecessary in production.
**Fix:** Remove or move behind a DEBUG flag.

### 12. npm audit — 4 moderate vulnerabilities
**Fix:** `cd groove-ai-backend && npm audit fix`
- axios SSRF vulnerability
- fast-xml-parser injection
- follow-redirects auth leak

---

## CLEANUP

### 13. iOS calls `/deduct-credits` which doesn't exist
**Files:** `SupabaseService.swift` (`deductCoins`), `CreditsService.swift` (`deductForGeneration`)
**Problem:** These methods call a non-existent backend route. They appear to be dead code but should be confirmed and removed to avoid confusion.

### 14. `RevenueCatAPISetup.swift` — 516 lines of dead code
Already covered in Issue #4. Delete the entire file.

---

## CONFIRMED PASSING — Do not change

- ✅ RevenueCat webhook HMAC signature verification: properly implemented with timing-safe comparison
- ✅ Coin deduction on generation is atomic via stored procedure with refund-on-failure
- ✅ `/api/add-coins` has full Apple JWS certificate chain validation + appAccountToken cross-check + inAppOwnershipType enforcement + transaction_id idempotency with race rollback
- ✅ No hardcoded API secrets in iOS client (RevenueCat public SDK key is the only hardcode — correct)
- ✅ UUID stored in Keychain, not UserDefaults
- ✅ All iOS network calls use HTTPS
- ✅ No SQL injection risk (all Supabase queries parameterized)
- ✅ No third-party analytics SDKs (no Firebase, Mixpanel, etc.)
- ✅ iOS generation refund logic is sound

---

## Priority fix order

1. Delete `/api/upload-demo-video` (5 minutes, zero risk)
2. Delete `RevenueCatAPISetup.swift` (5 minutes, removes ASC credentials from binary)
3. Fix `/api/confirm-subscription` — add verification or delete endpoint
4. Add auth middleware to the 6 IDOR endpoints
5. Fix CORS to specific domains
6. Fix paywall buttons in UploadView.swift
7. Wrap print() in #if DEBUG across iOS codebase
8. Remove token length log line
9. `npm audit fix`
10. Add coin cap
