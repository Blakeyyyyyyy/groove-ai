# Groove AI — Full Architecture Audit

**Date:** 2026-04-08  
**Auditor:** Sheldon + Codex  

---

## A. User/Account Identity

### Verified from Code

| Question | Answer |
|----------|--------|
| How is user created? | Auto-generated UUID in iOS Keychain (AppState.swift lines 105-121) |
| Keychain or other? | **Keychain** via `KeychainHelper.save("userId", ...)` |
| Survives reinstall? | **YES** - Keychain persists, with migration from UserDefaults |
| What ID goes to RevenueCat? | `userId` from AppState (same UUID) - passed as `appUserID` |
| What ID goes to backend? | Same `userId` UUID - sent in API calls as `user_id` |
| Risk of mismatch? | **LOW** - same ID used everywhere |

---

## B. Free-User Starting State

### Verified from Code

| Source | Value | Where |
|--------|-------|-------|
| **Backend** | **0 coins** | `index.js` line 204: `coins: 0` ✅ |
| **iOS App** | Unknown fallback | AppState reads from Supabase, not hardcoded |
| **Supabase** | 0 (schema default not visible but user created with 0) | Seen in live data |

### Discrepancy Found

**Current Supabase user has 150 coins:**
```
{"id":"...","coins":150,"subscription_status":"free","revenuecat_id":null}
```
This is from before the backend fix deployed. After Render redeploys, new users = 0 coins.

---

## C. Coin Source of Truth

| Question | Answer |
|----------|--------|
| **Intended source** | Supabase/backend |
| **Actual source** | Supabase (on launch) → displays in app |
| **On app launch** | `SupabaseService.getUser(id: userId)` → updates `appState.coinsRemaining` |
| **Later overwrite** | Generation: server deducts, returns remaining → app updates |
| **Stale number risk?** | Minor - could show stale between launch and first sync, but minimal |

---

## D. Generation Spending Flow

| Question | Answer |
|----------|--------|
| Where are coins deducted? | **Backend only** - `index.js` lines 469-472 |
| Backend authoritative? | **YES** - deducts in same transaction as generation request |
| App deduct locally first? | **NO** - only updates from server response |
| Refund on failure? | Generation failure = no deduction (atomic check before deduct) |
| Desync risk? | **LOW** - server-side only |

---

## E. Coin-Pack Purchase Flow

| Question | Answer |
|----------|--------|
| Does StoreKit complete? | Yes - RevenueCat handles |
| Does RevenueCat participate? | Yes - `RevenueCatService.purchaseCoins()` uses StoreKit 2 |
| Does app update local? | Yes - after successful purchase |
| Does backend/Supabase update? | **NO** - not fully implemented |
| Exact path for persistence? | Only local `CoinStore` - NOT stored in Supabase |

**⚠️ ISSUE:** Coin pack purchases only update local state, not Supabase. If user reinstalls, purchased coins are lost.

---

## F. Subscription Purchase Flow

| Scenario | What Happens |
|---------|--------------|
| **Onboarding paywall** | `RevenueCatService.purchase()` → success → local `isSubscribed = true` |
| **Coin button paywall** | Same code path |
| **Upgrade paywall** | Same code path |

**All flows:**
- Local `isSubscribed` updates immediately ✅
- Backend/Supabase via webhook (not immediate) ⚠️

---

## G. RevenueCat Webhook Verification

| Question | Answer |
|----------|--------|
| Webhook exists? | **YES** - `POST /api/revenuecat-webhook` in `index.js` line 731 |
| Deployed? | Yes - part of backend |
| Configured in RevenueCat? | **UNKNOWN** - need to verify in RevenueCat dashboard |
| Events handled? | `INITIAL_PURCHASE`, `RENEWAL`, `PRODUCT_CHANGE` → +150 coins, active status |
| | `CANCELLATION`, `EXPIRATION` → subscription_status = 'expired' |
| Maps RevenueCat user → Groove AI? | Yes - uses `revenuecat_id` column to match |
| Revenuecat_id column used? | **YES** - line 764 `eq('revenuecat_id', appUserId)` |

---

## H. Backend User Bootstrap

| Question | Answer |
|----------|--------|
| Need bootstrap endpoint? | **NO** - `/api/user/:id` auto-creates |
| Exact path? | `index.js` lines 200-215 |
| What gets initialized? | `id: userId`, `coins: 0`, `subscription_status: 'free'` |

---

## I. Supabase Schema

### Tables

| Table | Used For |
|-------|----------|
| `users` | User account, coins, subscription status |
| `videos` | Generated video records |
| `credits_log` | Coin transaction history |
| `app_config` | Tunable config values |

### Atomic Operations

- `POST /api/deduct-coins` - atomic check + deduct
- Generation endpoint - atomic deduct (lines 466-472)

---

## J. Doc Accuracy

| Doc | Status |
|-----|--------|
| `audit-groove-vs-glow.md` | ✅ Mostly correct |
| `codex-implementation-report.md` | ✅ Correct |
| `oscar-code-review.md` | ✅ Correct |

---

## K. Product Rules (Current Implementation)

| Rule | Implemented Value |
|------|-------------------|
| Free user coins | **0** (backend line 204) |
| Weekly subscription | 150 coins/week via webhook |
| Yearly subscription | 150 coins via webhook (not 250) ⚠️ |
| Trial | 150 coins via webhook |
| Coin cost per generation | **60** (not 10 like Glow AI) |
| Reset cadence | Not implemented - just subscription status check |

---

## L. Critical Gaps

| Priority | Issue |
|----------|-------|
| **CRITICAL** | Coin packs NOT persisted to Supabase - lost on reinstall |
| **CRITICAL** | Webhook may not be configured in RevenueCat dashboard |
| **HIGH** | Yearly subscription gives 150 coins, not 250 |
| **HIGH** | Test purchases cancelled - need sandbox tester |
| **MEDIUM** | No daily allowance/reset logic |

---

## Recommended Source of Truth

| Data | Should Be | Currently Is |
|------|-----------|---------------|
| **Coins** | Supabase | Supabase ✅ |
| **Subscription** | Supabase + webhook | Supabase + webhook ✅ |

---

## Next Steps

1. **Verify webhook configured** in RevenueCat dashboard
2. **Add coin pack persistence** to backend/Supabase
3. **Fix yearly subscription** to give 250 coins
4. **Add sandbox tester** for testing purchases
5. **Implement daily allowance** logic if needed