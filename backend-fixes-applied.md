# Groove AI Backend Security Fixes — Applied 2026-04-29

All fixes applied to: `/Users/blakeyyyclaw/.openclaw/workspace/groove-ai-backend/index.js`

---

## FIX 1: Deleted /api/upload-demo-video (SSRF exploit)
- **Removed**: `app.post('/api/upload-demo-video', ...)` — lines ~1880–1918
- Unauthenticated endpoint that fetched any arbitrary URL server-side and uploaded to R2.
- **Verified**: `grep upload-demo-video index.js` returns no results.

---

## FIX 2: Deleted /api/confirm-subscription (coin farming)
- **Removed**: `app.post('/api/confirm-subscription', ...)` — lines ~1478–1543
- No receipt verification; any caller could claim coins for any product_id. RevenueCat webhook handles coin grants correctly.
- Also cleaned up a comment referencing the old endpoint.
- **Verified**: `grep confirm-subscription index.js` returns no results.

---

## FIX 3: CORS locked to specific domains
- **Changed** line ~95: `app.use(cors())` → explicit allowlist
- Now only allows: `https://trygrooveai.com`, `https://groove-ai-backend-1.onrender.com`
- Methods: GET, POST, PUT, PATCH, DELETE
- AllowedHeaders: Content-Type, Authorization, x-admin-key

---

## FIX 4: validateApiKey middleware added to 6 IDOR endpoints
- **Added** `validateApiKey` function (lines ~93–101): checks `x-api-key` header against `process.env.GROOVE_API_KEY`. Skips check if env var not set (dev mode).
- Applied to:
  - `GET /api/user/:id` (line ~236)
  - `GET /api/videos/:userId` (line ~1122)
  - `POST /api/refund-coins` (line ~345)
  - `POST /api/generate-video` (line ~557)
  - `POST /api/save-video` (line ~1022)
  - `POST /api/update-subscription-expiry` (line ~1541)

---

## FIX 5: Sensitive log lines removed/redacted
1. **Deleted** `[RevenueCat] Auth check: provided_length=...expected_length=...` log (leaked secret token length via server logs)
2. **Redacted** `[add-coins] ✅ JWS verified. Payload: appAccountToken=..., productId=..., transactionId=...` → now only logs `[add-coins] ✅ JWS verified for transaction ${transactionId}`
3. Reviewed all other log lines — no full user objects or sensitive tokens logged.

---

## FIX 6: Coin cap added (10,000 max)
- In the RevenueCat webhook coin-granting path, added:
  ```javascript
  const cappedCoins = Math.min(newCoins, 10000);
  ```
- `webhookUpdate.coins` now uses `cappedCoins` instead of `newCoins`.
- Log line updated to show capped value and original if capping occurred.
- Applies to INITIAL_PURCHASE, RENEWAL, and PRODUCT_CHANGE events.

---

## FIX 7: npm audit fix
- Ran: `npm audit fix`
- Result: **4 packages added, 8 packages changed, 0 vulnerabilities remaining.**

---

## FIX 8: IP-based registration rate limiting
- **Added** `registrationIpStore` Map and `checkRegistrationRateLimit(ip)` function (lines ~104–136)
- Limits: max 5 UUID registrations per IP per hour.
- `POST /api/register` checks `req.ip` at the start and returns 429 if exceeded.
- Added hourly `setInterval` cleanup to prevent unbounded memory growth in the IP store (mirrors the pattern used by `rateLimitStore`).

---

## No-change confirmation
- `POST /api/revenuecat-webhook` — **untouched**
- `POST /api/add-coins` — **untouched**
- All other existing endpoints — **untouched**
