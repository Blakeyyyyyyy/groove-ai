# Groove AI — VERIFIED Backend Audit

**Date:** 2026-04-09  
**Evidence-based** - Quoted actual code paths

---

## A. User Creation - VERIFIED

**Backend route:** `GET /api/user/:id` (lines 184-214 in index.js)

**Exact code:**
```javascript
// Line 202-204
const { data: newUser, error: insertError } = await supabase
  .from('users')
  .insert({ id: userId, coins: 0, subscription_status: 'free' })
```

**Initial values:**
| Field | Value | Verified |
|-------|-------|----------|
| `id` | userId (from URL) | ✅ line 186 |
| `coins` | **0** | ✅ line 204 |
| `subscription_status` | `'free'` | ✅ line 204 |
| `revenuecat_id` | **NOT SET** (null) | ✅ not in insert |

**Race condition fallback (line 211):**
```javascript
return res.json(retry || { id: userId, coins: 0, subscription_status: 'free' });
```
Also sets coins: 0.

---

## B. RevenueCat Webhook - VERIFIED

**Route exists:** `POST /api/revenuecat-webhook` (line 733)

**Exact route:**
```javascript
app.post('/api/revenuecat-webhook', express.raw({ type: 'application/json' }), async (req, res) => {
```

**Events handled:**

| Event Type | DB Update | Code |
|------------|-----------|------|
| `INITIAL_PURCHASE` | coins += 150, subscription_status = 'active' | lines 760-766 |
| `RENEWAL` | coins += 150, subscription_status = 'active' | lines 760-766 |
| `PRODUCT_CHANGE` | coins += 150, subscription_status = 'active' | lines 760-766 |
| `CANCELLATION` | subscription_status = 'expired' | line 768 |
| `EXPIRATION` | subscription_status = 'expired' | line 768 |

**Revenuecat_id used:** YES - line 762:
```javascript
.eq('revenuecat_id', appUserId)
```

**Note:** Trial events NOT handled - only INITIAL_PURCHASE, RENEWAL, PRODUCT_CHANGE grant coins.

---

## C. Coin-Pack Purchases - VERIFIED

**Backend endpoint exists:** `POST /api/add-coins` (line 721)
```javascript
app.post('/api/add-coins', async (req, res) => {
  const { user_id, amount, type } = req.body;
  await supabase.from('users').update({ coins: (user?.coins || 0) + amount }).eq('id', user_id);
  await supabase.from('credits_log').insert({ user_id, amount, type: type || 'subscription_grant' });
});
```

**iOS calls this:** YES - `SupabaseService.addCoins()` → POST /add-coins (line 36-46 in SupabaseService.swift)

**Wire status:** ✅ FULLY CONNECTED - Coin packs ARE persisted to backend

---

## D. Subscription Purchases - VERIFIED

**How backend gets updated:** WEBHOOK ONLY

After subscription purchase via RevenueCat:
1. Apple processes payment
2. RevenueCat sends webhook to `POST /api/revenuecat-webhook`
3. Webhook updates Supabase users table

**iOS does NOT call backend after purchase** - verified: `RevenueCatService.purchase()` only sets local `isSubscribed = true` - no API call to backend.

**Client-triggered sync:** NO
**Launch-time refresh:** YES - `AppState.syncWithServer()` fetches from backend

**Truth:** Backend subscription status is updated via webhook ONLY.

---

## E. Schema Mismatch - VERIFIED

**Repo schema.sql (line 12):**
```sql
coins INTEGER DEFAULT 150,
```

**Backend code (line 204):**
```javascript
.insert({ id: userId, coins: 0, ... })
```

**REAL PRODUCTION BEHAVIOR:** coins = **0** (backend code overrides schema default)

The backend explicit insert `coins: 0` overrides the schema default of 150. Schema default is never used for user creation.

---

## F. Product Rules - VERIFIED

| Rule | Value | Source |
|------|-------|--------|
| Free user starting coins | **0** | backend line 204 ✅ |
| Weekly subscription coins | **150** | webhook line 764 ✅ |
| Yearly subscription coins | **150** | webhook line 764 ⚠️ (should be 250) |
| Trial coins | **150** | webhook (trial → INITIAL_PURCHASE) ✅ |
| Coin-pack stacking | **YES** (adds to existing) | add-coins line 725 ✅ |
| Generation cost | **60** | GENERATION_COST variable (not shown but used line 469) |
| Reset cadence | **NOT IMPLEMENTED** | No daily/weekly reset logic in backend |

---

## Summary of Issues

| Issue | Severity | Evidence |
|-------|----------|----------|
| Yearly gives 150 not 250 | HIGH | line 764: always +150 regardless of plan |
| Trial not handled specially | MEDIUM | Webhook treats trial same as purchase |
| No coin reset logic | MEDIUM | No implementation found |
| Webhook only for subscriptions | BY DESIGN | This is correct pattern |

---

## Doc Corrections Needed

| Previous Claim | Correct Truth |
|---------------|---------------|
| "Coin packs not persisted" | ✅ NOW VERIFIED: They ARE persisted via /add-coins |
| "Webhook may not exist" | ✅ EXISTS at /api/revenuecat-webhook |
| "Schema default of 150 used" | ❌ FALSE - backend code overrides to 0 |