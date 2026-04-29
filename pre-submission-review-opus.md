# Groove AI — Pre-App Store Submission Security & Code Review

Reviewer: Opus 4.7 (1M context)
Date: 2026-04-29
Scope: iOS app (`/Users/blakeyyyclaw/.openclaw/workspace/groove-ai/GrooveAI/`) + Node backend (`/Users/blakeyyyclaw/.openclaw/workspace/groove-ai-backend/index.js`).

---

# CRITICAL (must fix before submission)

## 1. `/api/confirm-subscription` grants coins with NO receipt verification — unlimited free coins
File: `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai-backend/index.js:1482-1543`
Problem:
The endpoint accepts `{ user_id, product_id }` and grants the corresponding coin amount. There is **no Apple JWS check, no RevenueCat lookup, no signature, no auth**. Any attacker who knows a `user_id` (their own UUID is fine) can call:

```
POST /api/confirm-subscription { user_id, product_id: "grooveai_weekly_1200" }
```

and receive 1200 coins. The only dedup is `user.subscription_product_id === product_id`. An attacker can rotate through all 7 product IDs (300 + 550 + 1200 + 250 + 150 + 150 + 150 = **2750 free coins** = 45 free generations) on one account, then re-register for a new account and repeat. Every subsequent call with the same product is also a no-op, but coin balance is now stuck at 2750+ until they spend.

Lines 1518–1521:
```js
if (user.subscription_product_id === product_id) {
  ...
  return res.json({ success: true, coins_granted: false, ... });
}
// Grant coins additively and update subscription_product_id
const newCoins = (user.coins || 0) + coinGrant;
```

Worse: this endpoint is called from `SupabaseService.confirmSubscription()` (`/Users/blakeyyyclaw/.openclaw/workspace/groove-ai/GrooveAI/Services/SupabaseService.swift:150-173`) without any receipt being passed. The iOS path is intentionally trusting the client.

Fix: Require an Apple StoreKit 2 JWS (same as `/api/add-coins` already does at lines 1082-1090). Reject anything where `payload.productId !== product_id` or `payload.appAccountToken !== user_id` (when present). Or remove this endpoint entirely and rely only on the RevenueCat webhook + iOS `applyCustomerInfo`. The webhook path at line 1400 already guards against double-grant via `subscription_product_id` check.

## 2. RevenueCat webhook is verified — but using `Authorization` header, not `X-RevenueCat-Signature`
File: `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai-backend/index.js:1260-1300`
Status: ACTUALLY VERIFIED — but the prompt asked specifically about `X-RevenueCat-Signature` and the code uses the `Authorization` header. RevenueCat does in fact send shared-secret auth via `Authorization` (configurable in their dashboard), so this is correct **provided** `REVENUECAT_WEBHOOK_SECRET` is set in Render. The check is timing-safe (`crypto.timingSafeEqual` at line 1295).

Action item: Confirm with Blake that `REVENUECAT_WEBHOOK_SECRET` is configured in production Render env. If not set, the endpoint hard-fails with 500 (line 1265-1267) — which is fail-closed and correct, but means webhook coin grants would silently break in production.

## 3. `/api/refund-coins` — IDOR allows any user to repeatedly refund any video_id they own
File: `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai-backend/index.js:285-355`
Problem: `validateUserId` only checks string format/length. There is **no auth tying the request to the actual caller**. An attacker who has a victim's `user_id` (UUID, but it's leaked in many backend logs and `console.log` at line 1187, line 236, etc.) can:
1. Submit `{ user_id: <victim>, video_id: <attacker_random_uuid>, amount: 60 }`
2. Get 60 coins refunded to the victim's account.

The DB function `refund_coins_for_video` enforces idempotency per `video_id` only — and the attacker controls `video_id`. So they can mint unlimited synthetic video_ids and inflate any user's coin balance.

In practice this benefits the victim, not the attacker — but the attacker on their own account can mint 60 coins per unique video_id forever, since they control both inputs. Fix:

Fix: Verify `video_id` exists in the `videos` table for that `user_id` before refunding:

```js
const { data: video } = await supabase
  .from('videos').select('user_id, status')
  .eq('id', video_id).single();
if (!video || video.user_id !== user_id) {
  return res.status(404).json({ error: 'video not found for this user' });
}
if (video.status !== 'failed') {
  return res.status(400).json({ error: 'cannot refund a non-failed video' });
}
```

(The synthetic `gen-fail-{uuid}` path at line 690 still works since the server controls it.)

## 4. `/api/upload-presigned` — IDOR + path traversal in filename
File: `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai-backend/index.js:358-372`
Problem:
```js
const { user_id, filename, contentType } = req.body;
const key = `uploads/${user_id}/${Date.now()}-${filename}`;
```

No validation, no auth, no sanitization.
- IDOR: any `user_id` (including a victim's) can be passed → presigned PUT URL gets issued for any user's namespace.
- Path traversal: `filename = "../../../malicious/index.html"` → key becomes `uploads/<user>/<ts>-../../../malicious/index.html`. While S3-compat usually rejects `..` segments, R2's behavior on `..` should be confirmed — and even if rejected, an attacker can use `filename = "../poisoned.jpg"` which on most S3 implementations resolves into `uploads/<ts>-poisoned.jpg`, escaping the per-user prefix.
- ContentType is honored verbatim (line 365): an attacker can upload an `.html` with `text/html` Content-Type and host XSS bait under your R2 public domain.

Fix:
```js
if (!user_id || !validateUserId(user_id).valid) return res.status(400)...;
if (typeof filename !== 'string' || /[/\\\.]{2,}|^\./.test(filename)) {
  return res.status(400).json({ error: 'invalid filename' });
}
const allowed = ['image/jpeg', 'image/png', 'image/webp'];
const ct = allowed.includes(contentType) ? contentType : 'image/jpeg';
```

## 5. `/api/update-subscription-expiry` — IDOR allows arbitrary expiry write
File: `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai-backend/index.js:1548-1584`
Problem: Accepts any `user_id` and any ISO date string and writes it to `users.subscription_expires_at`. An attacker can extend their own `subscription_expires_at` to year 9999, granting effectively perpetual subscriber state on the lazy-expiry path used by `/api/user/:id` (lines 217-231) and the cancellation flow (line 1456). They cannot directly grant coins this way, but can keep `subscription_status='active'` and prevent demotion.

Fix: Either remove this endpoint and trust only the RevenueCat webhook for `expires_at`, or require an Apple JWS receipt and enforce that `payload.expiresDate === subscription_expires_at`.

## 6. `/api/videos/:userId` — IDOR exposes any user's video history
File: `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai-backend/index.js:1062-1067`
Problem:
```js
app.get('/api/videos/:userId', async (req, res) => {
  const { data } = await supabase.from('videos').select('*').eq('user_id', req.params.userId)...
  res.json(data);
});
```
No auth. Pass any UUID, get that user's complete generated-video history with R2 video URLs (which are persistent on `videos.trygrooveai.com`). Combined with the user_ids leaked in many `console.log` statements, this is a privacy leak.

Fix: Require an Apple device-attestation token, RevenueCat appUserId+token, or a server-issued session cookie. Minimum: HMAC-sign every user_id at registration and require the signature on subsequent calls.

## 7. `/api/user/:id` — IDOR + leaks subscription / coin balances of any user
File: `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai-backend/index.js:184-242`
Problem: Same as #6 — pass any UUID, get back the full `users` row including `coins`, `purchased_coins`, `subscription_status`, `subscription_product_id`, `subscription_expires_at`, `last_coin_reset_at`. Anyone in possession of a user's UUID (which leaks via webhooks, logs, support tickets, etc.) can spy on their account state.

Fix: Same as #6.

## 8. `/api/generate-video` — IDOR allows spending another user's coins
File: `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai-backend/index.js:497-733`
Problem: The body's `user_id` is taken on faith. An attacker who knows a victim's `user_id` can:
1. POST `{ user_id: <victim>, image_url: <attacker's image>, dance_style: <any>, subject_type: 'HUMAN' }`
2. The server deducts 60 coins from the victim and submits a Kling job paid for by the victim's coin balance.
3. The video is associated with the victim's account (line 661-663 inserts into `videos` with `user_id`).

This is "griefing" rather than direct theft, but Apple may flag this if reported. Coin-deduction is correctly atomic via the `deduct_coins_if_not_subscriber` RPC (line 601), so attackers can't double-spend, but they CAN spend a victim's coins.

Fix: Same as #6 — require auth tying the caller to `user_id`.

---

# HIGH (strongly recommended)

## 9. CORS is wide-open
File: `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai-backend/index.js:96`
```js
app.use(cors());
```
With no options, `cors()` defaults to `Access-Control-Allow-Origin: *`. Combined with the IDOR endpoints above, **any malicious website** the user visits in Safari can call your API in their context (CSRF-style) since the API has no auth at all. While the iOS app is the only intended caller, the backend is reachable from browsers.

Fix: Restrict origins or, better, require an X-Client header signed with a server-issued token tied to `user_id`. At minimum:
```js
app.use(cors({ origin: false }));  // disallow all browser origins
```
The iOS app does not send Origin headers and is unaffected.

## 10. Rate limiting is in-memory and per-instance only
File: `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai-backend/index.js:24`, `30-66`
The `rateLimitStore` is a JS `Map` in process memory. On Render free/standard tier with autoscaling or a restart, the limit resets. Also, the limit is keyed by `user_id` — and since the attacker controls `user_id` (no auth, see #6/#8), they bypass the limit by rotating UUIDs.

Defaults: 3 generations/hour, 10/day per user_id. After fixing the auth IDOR in #8, this is fine for honest users. As-is it provides almost no protection against a determined attacker.

Fix: After auth is added, key on the authenticated user's identity. For DDoS resilience, also rate-limit by source IP using `express-rate-limit` with a `redis` store (or Render's KV).

## 11. `ALLOW_SANDBOX_RECEIPTS` env flag
File: `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai-backend/index.js:1247-1253`
Problem: If `ALLOW_SANDBOX_RECEIPTS=true` is left set on the production Render env after TestFlight testing, attackers can use **sandbox StoreKit receipts** (free) to call `/api/add-coins` and have them accepted as if they were real purchases. The Apple JWS verifier is also `ignoreExpiration: true` (line 1241) — also necessary for StoreKit 2 but worth noting.

Fix: Confirm `ALLOW_SANDBOX_RECEIPTS` is **unset or `false`** on production. Add a startup log that prints this state and a CI check that fails if it's enabled when `NODE_ENV === 'production'`.

## 12. `/api/save-video` — no auth, can corrupt other users' video records
File: `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai-backend/index.js:962-1059`
Problem: Accepts `{ video_id, video_url }`. If an attacker knows a victim's `video_id` (returned by the IDOR-vulnerable `/api/videos/:userId` in #6) and a fresh Kling URL (or a victim's incomplete generation), they can call `/save-video` with someone else's video_id and overwrite the `videos` row. The function does verify the URL is a Kling CDN host (line 977, `isKlingCdnUrl`), which limits the attack to Kling URLs (the attacker would need a Kling URL of their choosing — possible by submitting their own generation).

Net effect: an attacker can swap a victim's completed video with their own Kling video. Low impact but real.

Fix: Verify `video.user_id === <authenticated_user>` before updating.

## 13. `/api/process-image` — coin-free Gemini abuse
File: `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai-backend/index.js:1587-1878`
Problem: This endpoint calls Gemini for classification AND a Gemini image-edit (Nano Banana, line 1789) for PETs. Both consume your Google API quota. There is no rate limit on this endpoint (only `/api/generate-video` is rate-limited at line 522). An attacker can call `/process-image` with any `user_id` and a small PNG of a pet, repeatedly, costing you Gemini quota dollars. No coins are deducted.

Fix: Apply `checkRateLimit` to `/api/process-image` too. Or deduct coins/charge a small fee here. Or require the same auth as `/generate-video`.

## 14. `/api/classify-image`, `/api/upload-demo-video`, `/api/generate-image` — completely unauthenticated, abuse-able
Files:
- `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai-backend/index.js:376-417` (classify-image — calls Gemini, no auth, no rate limit)
- `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai-backend/index.js:1881-1918` (upload-demo-video — accepts ANY `video_url`, fetches it server-side, uploads to YOUR R2 under `demos/`. SSRF risk and storage abuse.)
- `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai-backend/index.js:1927-1987` (generate-image — calls Gemini Nano Banana with arbitrary text prompts. No coins deducted, no auth.)

`/api/upload-demo-video` is **especially dangerous**:
```js
const videoResponse = await fetch(video_url);  // SSRF
...
await r2.send(new PutObjectCommand({ Bucket: ..., Key: `demos/${key_name || ...}`, Body: fileBuffer }));
```
- SSRF: an attacker can pass `video_url=http://169.254.169.254/...` to attempt cloud metadata exfiltration (depends on Render's network policy).
- Storage abuse: an attacker can upload arbitrary content (up to whatever fetch returns, no size limit set) into your R2 `demos/` bucket, served from `videos.trygrooveai.com/demos/...`.
- `key_name` is taken verbatim — path traversal possible.

Fix: **Delete or gate these endpoints behind admin auth** (`isAdminBypass(req)`). They appear to be developer tools. `/api/generate-image` in particular is a content-policy nightmare (image generation with no prompt filter).

## 15. Print statements throughout iOS code expose user_id, coin balances, and internal API URLs in release builds
File: 218 `print(` calls across 23 Swift files (none wrapped in `#if DEBUG`).
Problem: Apple reviewers run the app in release configuration, but `print()` still emits to the unified Console log, which the reviewer or any user with a Mac and Console.app can inspect. More importantly, several logs leak sensitive data:

Examples of sensitive logs:
- `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai/GrooveAI/Services/SupabaseService.swift:34` — `print("[Supabase] ✅ register: user_id=\(userId), coins=\(coins)")`
- `SupabaseService.swift:44` — `print("[Supabase] ✅ getUser response: \(result)")` — entire user record including subscription_product_id, expires_at
- `SupabaseService.swift:191` — `print("[Supabase] ✅ addCoins response: \(result)")` — full server response
- `SupabaseService.swift:265, 280, 298, 308, 322` — every API request and response body
- `SupabaseService.swift:176` — `print("[Supabase] 📡 POST /add-coins userId=\(userId) amount=... jws=\(appleJWS != nil ? "present" : "MISSING")")`
- `Services/AppState.swift:185` — `print("[AppState] ✅ User registered: user_id=\(newUserId), coins=\(initialCoins)")`
- `RevenueCatService.swift:136` — `Purchases.logLevel = .debug` — RevenueCat SDK is left in DEBUG mode in release. This pumps verbose logs (transactions, entitlements, customerInfo dumps) to Console.

Fix: Wrap all `print` in `#if DEBUG` or use `os_log` with subsystem and `.private` for user data. Set `Purchases.logLevel = .error` (or `.warn`) in release.

Minimum patch:
```swift
#if DEBUG
print("[Supabase] ...")
#endif
```
Apply across all 218 sites — there are no DEBUG conditionals anywhere in the project today.

## 16. `RevenueCatAPISetup.swift` — dead code with App Store Connect API client (private key handling) shipping in app
File: `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai/GrooveAI/Services/RevenueCatAPISetup.swift` (entire file, 516 lines)
Problem: This file ships an `RevenueCatAPISetup` class with full ASC API JWT signing logic (`P256.Signing.PrivateKey` handling, `keyID`, `issuerID`, etc.). It is never instantiated (`grep RevenueCatAPISetup` returns only the class definition itself). It bloats the binary and is a footgun — if anyone ever passes a real ASC private key into the constructor (e.g. for testing) and ships, that key is in the bundle.

Fix: **Delete this file.** It's a server-side responsibility that has no place in a client app.

## 17. iOS calls non-existent backend endpoint `/deduct-credits`
File:
- iOS caller: `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai/GrooveAI/Services/SupabaseService.swift:48-60` (`deductCoins` POSTs to `/deduct-credits`)
- iOS legacy wrapper: `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai/GrooveAI/Services/CreditsService.swift:21-24` (`deductForGeneration`)
- Backend has no such route (`grep "deduct-credits" index.js` → 0 hits).

Problem: If anything ever calls `CreditsService.deductForGeneration(userId:)`, it will throw a 404 and the user will see a broken state. Today nothing calls it (verified) — but `SupabaseService.deductCoins(userId:amount:)` is also dead. This is dead code that misleads future maintainers and could be wired up by mistake. The actual coin deduction happens server-side inside `/api/generate-video`.

Fix: Delete `SupabaseService.deductCoins(...)` and the entire `CoinsService.deductForGeneration` and `CoinsService.addCoins` methods. They are not called.

---

# MEDIUM (should fix)

## 18. iOS user_id is stored in Keychain but with default accessibility — backed up to iCloud
File: `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai/GrooveAI/Models/AppState.swift:20-38`
Problem: `KeychainHelper.save` does not set `kSecAttrAccessible`. Default is `kSecAttrAccessibleWhenUnlocked`, which **gets backed up to iCloud Keychain and migrates across devices on restore**. This means a user can restore on a new device and inherit the same `user_id` — sharing coin balance. Probably intended? But also means the UUID lives in iCloud forever, raising the privacy bar.

Fix: If you want device-local-only:
```swift
kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
```
If you want iCloud-portable user identity (current behavior): leave as-is, but document the privacy implication.

## 19. Missing `[weak self]` in async closures — possible retain cycles
Files:
- `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai/GrooveAI/Services/RevenueCatService.swift:90-93`:
  ```swift
  Task {
      await SupabaseService.shared.updateSubscriptionExpiry(expiresAt)
  }
  ```
- `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai/GrooveAI/Models/AppState.swift:255` — `Task { await self.initializeUser() }` (inside `init`).
- 29 `Task {` calls vs. only 6 `[weak ` captures.

These are mostly inside singletons (RevenueCatService.shared) so the retain cycle is not catastrophic, but `AppState` is an `@Observable` class held by SwiftUI — if a view ever holds a Task closure capturing `self`, the AppState lifetime can extend unexpectedly.

Fix: Audit every `Task {` in non-singleton contexts and add `[weak self]` where the Task lifetime can outlive the owner.

## 20. `/api/process-image` server-side `petDetailsCache` is in-memory, leaks across requests
File: `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai-backend/index.js:19, 540-549, 1869-1871`
Problem: `petDetailsCache = new Map()` is a process-local Map, never garbage-collected proactively. On a Render free tier with multiple instances or restarts, this is unreliable. Also, an attacker who learns a victim's `user_id` can read their cached pet details by submitting a `/api/generate-video` request that hits the cached entry (reflected in the response at line 669: `pet_details: pet_details || null`).

Fix: Use Supabase to cache pet_details on the user record (one column, expires after 10 min), or cache by an opaque server-generated session token instead of `user_id`.

## 21. Console logs leak full webhook payloads, transaction IDs, and product info
File: `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai-backend/index.js`
- Line 1086: `console.log("[add-coins] ✅ JWS verified. Payload: appAccountToken=${payload.appAccountToken}, productId=${payload.productId}, transactionId=${payload.transactionId}")`
- Line 1187: `console.log("[add-coins] ✅ Success: user_id=..., product=..., purchased_coins_added=..., purchased_total=..., sub_coins=..., grand_total=..., transactionId=...")`
- Line 1314: full RevenueCat webhook payload meta logged
- Line 1080: first 50 chars of the JWS itself logged
- Line 369: full presigned upload URL hostname + path logged

These end up in Render logs which are accessible to anyone with the dashboard credentials. transactionId values, while not secret, are PII tied to a specific Apple ID purchase and should not be logged in plaintext.

Fix: Hash user_id and transaction_id before logging (`crypto.createHash('sha256').update(userId).digest('hex').slice(0,8)`). Never log JWS contents, even prefixes.

## 22. `Purchases.logLevel = .debug` left enabled in release
File: `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai/GrooveAI/Services/RevenueCatService.swift:136, 153`
Problem: RevenueCat SDK is configured with `.debug` log level both in `configure()` and `configureWithUserId(_:)`. This emits verbose subscription state logs to Console in production, which Apple reviewers see.

Fix:
```swift
#if DEBUG
Purchases.logLevel = .debug
#else
Purchases.logLevel = .error
#endif
```

## 23. Onboarding fake AI loader — Apple may flag as misleading
File: `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai/GrooveAI/Onboarding/Views/GrooveMagicMomentView.swift:1-224`
Problem: This view shows a 0→100% progress ring with status messages "Mapping the movement", "Adding your style", "Finishing touches" over a 2.8s simulation. **No actual generation is happening** — it's a UX time-filler before showing pre-rendered onboarding videos. Apple's App Review Guideline 2.3.1 (accurate metadata) and 5.6.1 have flagged similar fake-loader patterns in AI apps.

Risk level: medium — many AI apps use this pattern and ship fine. But it's a known reject reason if combined with other guideline issues.

Fix: Either rename the messages to something obviously aspirational ("See what others made", "Loading your preview") or delete the loader and go straight to the demo. Keep the v2 version (`GrooveMagicMomentViewV2.swift`) consistent.

`GrooveOnboardingFeatureFlags.activeOnboardingFlow = .current` (line 15) → the v1 flow with this loader is the one that ships today.

## 24. TODO comments in Upload paywall sheet — incomplete IAP buttons
File: `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai/GrooveAI/Views/Upload/UploadView.swift:308, 331`
Problem:
```swift
Button("Upgrade to Pro — Unlimited") {
    // TODO: Navigate to subscription paywall
}
```
and
```swift
Button { /* TODO: IAP purchase */ } label: { ... }
```
These appear inside a paywall sheet (`coinPackage` sub-view, lines 329-356). If the user can reach this sheet, tapping "Upgrade to Pro" or any coin tier does nothing. This is a broken purchase path — Apple Review will likely catch this, especially since the button shows real prices.

Fix: Either wire these up to the same `purchaseCoins` flow as `GrooveCoinPurchaseSheet`, or remove the inline paywall sheet and present `GrooveCoinPurchaseSheet`/`GroovePlansSheet` as a real sheet.

## 25. npm audit — 4 moderate vulnerabilities in axios, fast-xml-parser, follow-redirects
File: `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai-backend/package.json`
```
axios 1.0.0 - 1.14.0 (NO_PROXY SSRF + cloud-metadata header injection)
fast-xml-parser <5.7.0 (XML/CDATA injection)
follow-redirects <=1.15.11 (auth header leak on cross-domain redirect)
@aws-sdk/xml-builder (transitive)
```
Severity: moderate. Axios in particular is exploitable (you call `axios.get(image_url, ...)` at line 383 and elsewhere with user-influenced URLs).

Fix: `cd /Users/blakeyyyclaw/.openclaw/workspace/groove-ai-backend && npm audit fix` then verify nothing breaks.

---

# LOW / CLEANUP

## 26. `petDetailsCache` 10-minute TTL is hand-rolled and never sweeps
Lines 540-549 only purge an entry when it's read after expiry. An idle entry sits in memory until the user requests again. Memory grows unbounded over weeks. Use `node-cache` (already in `package.json`) or a periodic sweep.

## 27. `kling-direct.js` — orphan script in backend repo
File: `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai-backend/kling-direct.js` (5585 bytes)
Not referenced from `index.js`. Likely a one-off test. If it has secrets, delete it.

## 28. `test-pipeline.sh`, `test-atomic-coins.js`, `test-refund-coins.js`, `test-v2.6-pro.js`, `backfill-videos.js`
All in backend repo root. Confirm none are exposed via static serving (they aren't — Express only serves the routes defined). But they shouldn't ship in a deploy. Add a `.renderignore` or move to `scripts/`.

## 29. `Splash dismissed` raw print in release
File: `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai/GrooveAI/Views/Components/GrooveSplashView.swift:229`
Plain `print("Splash dismissed")` — no tag, no useful info. Remove or wrap in DEBUG.

## 30. R2 public dev URLs hardcoded in iOS for demo media
File: `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai/GrooveAI/Services/ImageCacheService.swift:9-10`
```
https://pub-c3256eacaaf4436c8f67e04fd794c190.r2.dev/...
```
Cloudflare explicitly states `pub-*.r2.dev` URLs should not be used in production (rate-limited, no SLA). The rest of the app uses the custom domain `https://videos.trygrooveai.com/`. Switch these two URLs to the custom domain (you'll need an `images.trygrooveai.com` if not already present, or move the demo files to the videos bucket).

## 31. `iOS Info.plist` key uses wrong name `SUPABASE_URL` for backend URL
File: `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai/GrooveAI/Info.plist:5-6`
The plist key is `SUPABASE_URL` but the value is the **Render backend URL**, not Supabase. Cosmetic only — but if a reviewer or future maintainer looks at the plist, the naming is misleading. Also, the backend URL `https://groove-ai-backend-1.onrender.com/api` is NOT a secret, but it's the canonical attack surface for everything described above.

Fix: Rename to `BACKEND_URL` or `API_BASE_URL`. Update the Info.plist key reader in `SupabaseService.swift:10`.

## 32. `petDetailsCache.delete(user_id)` only on expired-read; otherwise PII (pet description) lingers in process memory
See #20. Treat `pet_details` (animal_type, breed, fur, etc.) as user-supplied PII; sweep aggressively.

## 33. Backend `console.log` of received form fields including filename
File: `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai-backend/index.js:1775`
```js
console.log(`[NanoBanana] Uploaded image: user_id=${user_id}, filename=${imageFilename}`);
```
Filename is whatever the iOS client sent (always `photo.jpg` in `SupabaseService.processImage`, lines 254-255 of `SupabaseService.swift`). Low risk.

## 34. `crypto.timingSafeEqual` length check pre-guard logs both lengths
File: `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai-backend/index.js:1290`
```js
console.warn(`[RevenueCat] Auth FAILED: length mismatch (provided=${providedToken?.length || 0}, expected=${expectedToken?.length || 0})`);
```
Logging both lengths leaks the expected secret length. Tiny info leak but improves brute-force.

Fix: Log only that auth failed.

---

# PASSED (confirmed secure / acceptable)

### `/api/add-coins` (consumable coin packs)
- Verifies Apple StoreKit 2 JWS via embedded x5c chain (lines 1217-1230) — chain validation, ES256 sig.
- Cross-checks `appAccountToken` matches `user_id` (line 1093) when present.
- Validates `inAppOwnershipType === 'PURCHASED'` (line 1099).
- Idempotency via `transaction_id` unique constraint, with race rollback on 23505 (lines 1174-1180).
- Sandbox receipts rejected unless explicit env override (lines 1247-1253).
- This is the gold-standard path. **If your other endpoints used this same pattern, every CRITICAL above goes away.**

### RevenueCat webhook signature verification
- Uses Authorization header + `crypto.timingSafeEqual` (line 1295) with length-pre-guard.
- Robust to header casing.
- Idempotency via `webhook_events.event_id` table; INITIAL_PURCHASE fails closed on dedup-table errors (lines 1338-1342).
- Unknown product_id is rejected loudly (lines 1385-1395) — won't silently grant default 150.
- RESTORE / SUBSCRIBER_ALIAS / TRANSFER / UNCANCELLATION / SUBSCRIPTION_PAUSED / BILLING_ISSUE all explicitly classified as no-grant (line 1317).
- Status-only `CANCELLATION` and `EXPIRATION` correctly handled.

### Coin deduction in `/api/generate-video`
- Atomic via stored procedure `deduct_coins_if_not_subscriber` (line 601).
- Order is correct: deduct first, then call Kling. Failure path refunds via `refund_coins_for_video` (lines 689-708) using a synthetic UUID (`gen-fail-{uuid}`) that can never collide with a real video.id.
- Refund function uses partial unique index on `credits_log(video_id) WHERE type='refund_failed_generation'` for exactly-once.
- This is well-designed.

### iOS Keychain usage for `user_id`
- `userId` getter/setter in `AppState.swift:125-150` correctly uses `KeychainHelper`.
- Migrates from UserDefaults if found (back-compat for older installs) and removes the UserDefaults copy.
- Stored under service `com.grooveai.app` with account `userId`. (Caveat: see #18 about iCloud accessibility.)

### All iOS network calls use HTTPS
Confirmed via `grep "http://"` — zero matches in Swift sources. All API calls go through `SupabaseService.baseURL` which is `https://groove-ai-backend-1.onrender.com/api`.

### No SQL injection risk
All Supabase queries use the JS client library's parameterized methods (`.eq()`, `.update()`, `.insert()`, `.select()`, `.rpc()`). No raw SQL string construction anywhere.

### No hardcoded API keys or secrets in iOS
Only `appl_dmOLXuPKMXatwKYxDHjLyYfULfu` (RevenueCat **public** SDK key) is hardcoded — that's correct and documented at `RevenueCatService.swift:55-57`. No Gemini, Kling, R2, or Supabase secrets in client code.

### Apple JWS sandbox/production gating
The verifier rejects sandbox receipts unless `ALLOW_SANDBOX_RECEIPTS=true` env (line 1250). Just confirm production env doesn't have it set (#11).

### Info.plist
`ITSAppUsesNonExemptEncryption=false` is correctly declared (line 7-8). No other sensitive values exposed.

---

# Backend Endpoint Audit Summary

| Method | Path | Auth | Coin Impact | Risk | Notes |
|--------|------|------|-------------|------|-------|
| GET    | `/api/presets` | none | none | LOW | Public dance preset list |
| GET    | `/api/categories` | none | none | LOW | Public category list |
| GET    | `/api/user/:id` | **NONE** | none (read) | **CRITICAL** | IDOR — leaks any user's full record (#7) |
| POST   | `/api/register` | none | grants 0 | LOW | Returns server-generated UUID; race-safe |
| POST   | `/api/refund-coins` | **NONE** | +60 | **CRITICAL** | IDOR — attacker controls video_id, can mint refunds (#3) |
| POST   | `/api/upload-presigned` | **NONE** | none | **CRITICAL** | IDOR + path traversal in filename (#4) |
| POST   | `/api/classify-image` | **NONE** | none | HIGH | Burns Gemini quota, no rate limit (#14) |
| POST   | `/api/generate-video` | **NONE** | -60 | **CRITICAL** | IDOR — spend victim's coins (#8). Coin RPC is atomic (good). |
| GET    | `/api/video-status/:taskId` | **NONE** | none (but can RE-trigger Kling on retry path) | HIGH | No auth on retry path; retry burns Gemini + Kling quota |
| POST   | `/api/save-video` | **NONE** | none | HIGH | Can overwrite victim's video record (#12); URL is gated to Kling host |
| GET    | `/api/videos/:userId` | **NONE** | none | **CRITICAL** | IDOR — leaks any user's video history (#6) |
| POST   | `/api/add-coins` | **JWS** | +100/300/600 | LOW | Properly verified — see PASSED |
| POST   | `/api/revenuecat-webhook` | **HMAC** | +250..1200 | LOW | Properly verified — see PASSED |
| POST   | `/api/confirm-subscription` | **NONE** | +150..1200 | **CRITICAL** | NO RECEIPT CHECK — unlimited free coins (#1) |
| POST   | `/api/update-subscription-expiry` | **NONE** | none directly | HIGH | IDOR — extend victim's subscription_expires_at (#5) |
| POST   | `/api/process-image` | **NONE** | none | HIGH | Burns Gemini quota, no rate limit (#13) |
| POST   | `/api/upload-demo-video` | **NONE** | none | HIGH | SSRF + R2 storage abuse (#14) |
| GET    | `/health` | none | none | LOW | Standard health check |
| POST   | `/api/generate-image` | **NONE** | none | HIGH | Arbitrary Gemini Nano-Banana prompts (#14) |

---

# Recommended pre-submission action plan (ranked)

1. **Block the unauthenticated coin-grant**: fix or delete `/api/confirm-subscription` (#1). This alone is a complete economic-model break.
2. Add minimal auth to all user-data endpoints (`/api/user/:id`, `/api/videos/:userId`, `/api/refund-coins`, `/api/generate-video`, `/api/save-video`, `/api/update-subscription-expiry`, `/api/process-image`). Easiest path: HMAC-sign `user_id` server-side at registration, return signature to iOS, store in Keychain alongside user_id, and require `X-User-Sig` on every authenticated call. (#1, #3, #5, #6, #7, #8, #12)
3. Delete or admin-gate `/api/upload-demo-video`, `/api/generate-image`, `/api/classify-image` (#14).
4. Fix `/api/upload-presigned` filename sanitization + content-type allowlist (#4).
5. Wrap all 218 iOS `print(` calls in `#if DEBUG` and set `Purchases.logLevel = .error` in release (#15, #22).
6. Delete `RevenueCatAPISetup.swift` (#16).
7. Delete dead `CoinsService.deductForGeneration` and `SupabaseService.deductCoins` (#17).
8. Run `npm audit fix` (#25).
9. Verify `ALLOW_SANDBOX_RECEIPTS` is unset on production Render (#11) and `REVENUECAT_WEBHOOK_SECRET` is set (#2).
10. Wire up the two `// TODO: IAP purchase` buttons in `UploadView.swift` or remove that paywall sheet (#24).
11. Restrict CORS (#9).

After fixes, re-run this review to confirm.
