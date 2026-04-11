# Groove AI — Critical Architecture Questions Answered

**Date:** 2026-04-09

---

## Q1: Where exactly is users.revenuecat_id ever populated in production?

**ANSWER: NEVER in current production**

Evidence:
- Backend only READS revenuecat_id (lines 762, 768)
- No code in backend WRITES to revenuecat_id
- iOS never sends revenuecat_id to backend
- Query to Supabase returns empty: `[]` - no rows have revenuecat_id set

---

## Q2: If revenuecat_id is not populated, how is the webhook supposed to match event.app_user_id to a Groove AI user?

**ANSWER: It CAN'T - WEBHOOK IS BROKEN**

The webhook code tries:
```javascript
.eq('revenuecat_id', appUserId)
```

But since revenuecat_id is never set, this lookup ALWAYS fails. Webhook updates silently do nothing because no user matches.

---

## Q3: Is the iOS app in production actually configuring RevenueCat with the app's stable userId, or is it still using anonymous RevenueCat users?

**ANSWER: Using ANONYMOUS users**

Evidence:
- `RevenueCatService.configure()` (line 93) calls `Purchases.configure(withAPIKey: apiKey)` WITHOUT appUserID
- `configureWithUserId()` EXISTS (line 101) but is NEVER CALLED anywhere in codebase
- Result: RevenueCat sees all users as anonymous `$ RCPurchaseTransaction`

---

## Q4: Is there any deployed backend endpoint or admin script outside the repo that syncs revenuecat_id after purchase or on launch?

**ANSWER: NO**

- No such endpoint in `index.js`
- No admin scripts in repo
- No webhook logic to populate revenuecat_id

---

## Q5: Is RevenueCat dashboard definitely configured to send webhooks to the deployed /api/revenuecat-webhook endpoint with the correct HMAC secret?

**ANSWER: UNKNOWN - Cannot verify**

- Code exists at `POST /api/revenuecat-webhook`
- Code expects HMAC from `process.env.REVENUECAT_WEBHOOK_SECRET`
- Need to check RevenueCat dashboard to verify webhook URL and secret configured

---

## Q6: For coin packs: is there any production path outside the iOS repo that calls /api/add-coins after successful StoreKit purchase, or is that currently missing?

**ANSWER: YES - Fully connected**

Evidence:
- Backend has `POST /api/add-coins` (line 721)
- iOS calls this via `SupabaseService.addCoins()` → POST to /add-coins
- Connected in `RevenueCatService.purchaseCoins()` which calls `addCoins(package.coins)` on success

---

## Q7: Is the intended Groove AI rule really flat 150 for all subscription grants, or should weekly/yearly differ?

**ANSWER: Currently flat 150 for ALL**

Backend code (line 764):
```javascript
await supabase.from('users').update({ coins: (user.coins || 0) + 150, subscription_status: 'active' })
```
No differentiation between weekly/yearly/trial.

**Intended rule should be:**
- Weekly: 150 coins/week
- Yearly: 250 coins/month
- But currently NOT implemented

---

## Q8: Is there any actual reset/refill logic deployed outside this backend repo, or is "no reset cadence" the current truth?

**ANSWER: NO RESET - Current truth**

- No cron jobs in backend
- No reset logic in any endpoint
- No scheduled functions in Supabase
- Coin balance only changes on: generation (deduct), purchase (add), webhook (add)

---

## Summary of Broken Things

| Issue | Severity | Impact |
|-------|----------|--------|
| revenuecat_id never populated | **CRITICAL** | Webhook can't match users - subscriptions don't sync |
| RevenueCat using anonymous users | **CRITICAL** | Can't map purchases to users |
| Webhook configured in RevenueCat? | **UNKNOWN** | Need dashboard check |
| Yearly = 150 instead of 250 | **MEDIUM** | Revenue mismatch |
| No reset/refill logic | **LOW** | Future feature |

---

## Fixes Needed

1. **iOS must call `configureWithUserId(userId)`** after getting userId from Keychain
2. **Backend must save revenuecat_id** when webhook fires - need to capture RevenueCat app_user_id and store it
3. **Verify webhook configured** in RevenueCat dashboard
4. **Differentiate yearly vs weekly** coin grants in webhook