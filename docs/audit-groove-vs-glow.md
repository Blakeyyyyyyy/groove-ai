# Groove AI Audit — vs Glow AI Architecture

**Audit Date:** 2026-04-08  
**Auditor:** Codex (GPT-5.1-codex)  
**Requested by:** Blake Stephens  
**Last Updated:** 2026-04-09 (with new investigation findings)

---

## EXECUTIVE SUMMARY

Groove AI has several gaps vs Glow AI's proven architecture. The most critical are:
1. **No bootstrap on first launch** — backend calls fail if user doesn't exist
2. **Video storage BROKEN** — endpoints + UI exist but Supabase env vars missing = videos never sync to cloud
3. **API key hardcoded in Swift** — security risk
4. **No webhook handling** — purchases while app closed don't sync
5. **User ID in UserDefaults** — doesn't survive reinstalls

---

## NEW FINDINGS (Investigation Results)

### What's ALREADY IMPLEMENTED ✅

| Component | Status | Location |
|-----------|--------|----------|
| `/api/save-video` endpoint | ✅ Working | Backend `server.js` |
| `/api/videos/:userId` endpoint | ✅ Working | Backend `server.js` |
| `MyVideosView` screen | ✅ Working | iOS app |
| `SupabaseService.saveVideo()` | ✅ Working | iOS `SupabaseService.swift` |
| SwiftData `GeneratedVideo` model | ✅ Working | iOS app |
| User auto-creation (`/api/user/:id`) | ✅ Working | Auto-creates if user doesn't exist |
| **Supabase in backend** | ✅ **WORKING** | Env vars set in Render dashboard (not local .env) |

### What's BROKEN ❌

*(Actually working now - env vars are in Render, not local .env file)*

| ~~Component~~ | ~~Issue~~ |
|---------------|-----------|
| ~~Supabase client in backend~~ | ~~`process.env.SUPABASE_URL` is undefined~~ |
| ~~Supabase client in backend~~ | ~~`process.env.SUPABASE_ANON_KEY` is undefined~~ |
| ~~Backend .env file~~ | ~~Does not exist - no env vars set~~ |

**CORRECTION:** Supabase IS working. Env vars are set in Render dashboard, not local .env file.

---

## BLAKE'S QUESTIONS — ANSWERS

### 1. Where should app-generated videos be saved?

**Answer:** Videos should save to Supabase (cloud) for permanent storage. This is already implemented:
- Backend has `/save-video` endpoint
- Frontend has `SupabaseService.saveVideo()` method

**The Problem:** Supabase env vars are not set in backend, so the Supabase client fails to initialize. Videos get saved locally to SwiftData but never sync to the cloud.

**Fix:** Add `.env` file to backend with `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
THIS ALREADY DONE BUDDY
---

### 2. If user doesn't exist on backend, what happens?

**Answer:** `/api/user/:id` auto-creates the user if they don't exist. This already works! ✅

When the app calls `GET /api/user/{userId}`, the backend:
1. Checks if user exists in Supabase
2. If not found, creates new user record with default coin balance
3. Returns user object

**No bootstrap endpoint needed** — user creation is handled automatically.

---

### 3. Where do coins get deducted?

**Answer:** Server-side in the backend via `/deduct-credits` endpoint. However:

**Current Flow (problematic):**
1. User taps "Generate"
2. Frontend deducts coins locally immediately
3. Frontend calls backend `/deduct-credits`
4. Backend deducts from server-side balance

**Issue:** If network fails after local deduction but before backend call → coins out of sync.

**Better approach:** Call backend first, let backend deduct, then update UI from backend response (`coins_remaining`).

---

### 4. Why are videos lost?

**Answer:** Supabase env vars not set in backend, so cloud sync never happens.

- Videos save to SwiftData (local) ✅
- App calls `SupabaseService.saveVideo()` but it fails because Supabase client is broken (no env vars)
- User reinstalls app → SwiftData wiped → videos lost

**Fix:** Set Supabase env vars in backend. This has already been done you dork

---

## CURRENT STATE (Groove AI)

### 1. User Identity (Local Storage)
- UUID generated on first access, stored in **UserDefaults** (not Keychain)
- Used as RevenueCat appUserID via `configureWithUserId(userId)`
- Persists across app launches but NOT across reinstalls (cleared with app delete)
- User auto-creation works via `/api/user/{id}` — backend creates user if not exists ✅

### 2. Coin Logic
- `coinsTotal = 150` (free tier starter)
- `coinCostPerGeneration = 60` (higher than Glow AI's 10)
- Dual-source: `serverCoins` from backend OR local `coinsTotal - coinsUsed`
- Local `coinsUsed` increments after each generation
- Backend returns `coins_remaining` in generation response
- No "daily allowance" or "resetsAt" — weekly resets handled server-side only
- **Issue:** Client-side deduction before server confirmation — can desync

### 3. Subscription State
- RevenueCat configured with hardcoded API key
- `isSubscribed` tracked in UserDefaults + synced on launch
- No webhook handling — relies on manual refresh at app launch
- User auto-created on first backend call ✅

### 4. API Keys (FRONTEND EXPOSED)
- RevenueCat API key: `appl_dmOLXuPKMXatwKYxDHjLyYfULfu` — hardcoded in RevenueCatService.swift
- Backend has no API key (uses open endpoints)

### 5. Backend Integration
- Base URL: `https://groove-ai-backend-1.onrender.com/api`
- Endpoints: `/user/{id}`, `/deduct-credits`, `/add-coins`, `/generate-video`, `/video-status/{taskId}`, `/save-video`, `/videos/{userId}`
- All coin operations go through backend

### 6. Video Storage (PARTIALLY WORKING)
- ✅ Backend has `/save-video` endpoint
- ✅ Backend has `/videos/{userId}` endpoint
- ✅ Frontend has `MyVideosView` screen
- ✅ Frontend has `SupabaseService.saveVideo()` method
- ✅ SwiftData `GeneratedVideo` model for local storage
- ❌ **BROKEN:** Supabase env vars not set = cloud sync fails WRONG< SUpabase nev vars are already in render, 

---

## GAPS IDENTIFIED

| Gap | Severity | Description |
|-----|----------|-------------|
| **Client-side coin deduction (can desync)** | HIGH | Coins deducted locally before server confirms. Network failure mid-generation leaves coins out of sync. |
| **No webhook handling** | HIGH | RevenueCat purchases don't update backend automatically. If user buys while app is closed, coins won't sync until next launch. |
| **API key in source code** | HIGH | RevenueCat key exposed in Swift source. Should be in build config, not hardcoded. |
| **User ID not in Keychain** | MEDIUM | UUID in UserDefaults doesn't survive reinstalls. Should use iOS Keychain like Glow AI. |
| **No rate limiting** | MEDIUM | Glow AI explicitly mentions rate limiting fix. Groove AI has no rate limit enforcement. |
| **Entitlements not synced to backend** | MEDIUM | Subscription status stays in RevenueCat locally. Backend doesn't know user's true entitlement status. |
| No bootstrap on first launch | ✅ RESOLVED | `/api/user/{id}` auto-creates user - this works! |
| Video storage broken | ✅ RESOLVED | Supabase is working - videos ARE saving to cloud! |
| Supabase env vars missing | ✅ RESOLVED | Env vars set in Render dashboard |

---

## UPDATED: Video Storage Gap Status

| Aspect | Status |
|--------|--------|
| Backend `/save-video` endpoint | ✅ Working |
| Backend `/videos/:userId` endpoint | ✅ Working |
| Frontend MyVideosView screen | ✅ Working |
| Frontend SupabaseService.saveVideo() | ✅ Working |
| SwiftData GeneratedVideo model | ✅ Working |
| Supabase client initialization | ✅ Working (env vars in Render) |
| Cloud sync | ✅ WORKING |

**Video storage is fully functional.** Videos save to both local SwiftData AND Supabase cloud.

---

## COIN STRUCTURE (Per Blake's Plan)

Based on Blake's clarifications:
- **Weekly subscription:** 150 coins per week
- **Generation cost:** 60 coins per video (may vary by video type later)
- **New users (no sub):** 0 coins
- **Display:** Show coins remaining + next top-up time in hours format

**Coin display requirements (from Blake):**
- **Upgrade paywall** (shown to users WITH subscriptions): Display their coin balance
- **Settings page**: Show coins remaining + when next top-up happens
- **Coins button**: If user has coins OR is subscribed, show upgrade paywall with coin packages and the amount of coins and next reload liek settings (add this so it matches the paywall and fits properally)

---

## RECOMMENDED PLAN (Priority Order)

### 1. [HIGH] Fix coin sync (server-side authoritative)
- **Frontend:** Remove client-side coin deduction before server call
- **Frontend:** Only update coins from backend response (`coins_remaining`)
- **Backend:** Ensure `/deduct-credits` is atomic (fail = no deduction)
- **Frontend:** Add rollback — if generation fails, call `/add-coins` to refund
- **Why:** Current approach can desync coins on network failure

### 2. [HIGH] Add webhook handler for RevenueCat
- **Backend:** Create webhook endpoint to receive RevenueCat events
- **Backend:** Update user subscription + coin balance on purchase webhook
- **Why:** Purchases while app is closed won't reflect until next launch

### 4. [HIGH] Remove hardcoded RevenueCat API key
- **File:** `GrooveAI/Services/RevenueCatService.swift`
- **Change:** Move API key to build config or environment
- **Why:** Security risk — key visible in binary

### 5. [MEDIUM] Move user ID to iOS Keychain
- **File:** `GrooveAI/Models/AppState.swift`
- **Change:** Use KeychainAccess or Security framework to store UUID
- **Why:** Survives reinstalls, matches Glow AI pattern

### 6. [MEDIUM] Sync entitlements to backend
- **Backend:** Store user's subscription tier in user table
- **Frontend:** Fetch entitlement status from backend, not just RevenueCat locally
- **Why:** Backend should know if user is subscribed for coin grants

---

## SUBSCRIPTION FLOW (What Blake Wants)

**Free user (no sub):**
- Opens app → sees coin balance: 0
- Taps "Generate" → **paywall appears** (can't generate without coins)

**Subscribed user:**
- Opens app → sees coin balance: 150 (or remaining)
- Sees "Next top-up in X hours"
- Taps "Generate" → coins deducted correctly → video generates
- Can view all generated videos in "My Videos" screen

**Coin display on Upgrade Paywall (subscribed users):**
- Show current coin balance
- Show available coin packages 

**Coin display on Settings page:**
- Show coins remaining
- Show when next top-up happens (in hours)

---

## NOTES

- RevenueCat public keys are technically safe to embed (they're meant to be public)
- The real concern is backend endpoints being open
- Current coin system works at a high level — just needs the webhook layer + env vars fix
- User auto-creation is already working — no bootstrap endpoint needed
- Video storage is mostly implemented — just needs Supabase env vars to work
