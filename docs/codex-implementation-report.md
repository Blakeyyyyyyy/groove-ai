# Codex Implementation Report — Groove AI Audit Fixes

**Date:** 2026-04-08  
**Task:** Implement audit fixes from `groove-ai/docs/audit-groove-vs-glow.md`  
**Agent:** Codex (GPT-5.1-codex)

---

## Changes Made

### 1. RevenueCat API Key — Removed Hardcoded Value

**File:** `GrooveAI/Services/RevenueCatService.swift`

**Before:**
```swift
private let apiKey = "appl_dmOLXuPKMXatwKYxDHjLyYfULfu"
```

**After:**
```swift
// Load from Info.plist or environment
private var apiKey: String {
    if let plistKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String {
        return plistKey
    }
    return ProcessInfo.processInfo.environment["REVENUECAT_API_KEY"] ?? ""
}
```

**Why:** Security — keys should not be hardcoded in source.

---

### 2. User ID — Moved to iOS Keychain

**File:** `GrooveAI/Models/AppState.swift`

**Added new helper:**
```swift
// MARK: - Keychain Helper
enum KeychainHelper {
    static func save(_ value: String, forKey key: String) { ... }
    static func get(forKey key: String) -> String? { ... }
    static func delete(forKey key: String) { ... }
}
```

**Changed userId property:**
```swift
var userId: String? {
    get {
        // First check Keychain (preferred)
        if let keychainId = KeychainHelper.get(forKey: "userId") {
            return keychainId
        }
        // Fallback: check UserDefaults for migration
        if let existing = UserDefaults.standard.string(forKey: "userId") {
            KeychainHelper.save(existing, forKey: "userId")
            return existing
        }
        // Auto-generate new
        let newId = UUID().uuidString
        KeychainHelper.save(newId, forKey: "userId")
        UserDefaults.standard.set(newId, forKey: "userId")
        return newId
    }
    set {
        if let value = newValue {
            KeychainHelper.save(value, forKey: "userId")
        } else {
            KeychainHelper.delete(forKey: "userId")
        }
    }
}
```

**Why:** Keychain survives app reinstalls, UserDefaults doesn't.

---

### 3. Database Schema — Added revenuecat_id Column

**File:** `groove-ai/supabase/schema.sql`

**Before:**
```sql
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ DEFAULT now(),
  coins INTEGER DEFAULT 150,
  subscription_status TEXT DEFAULT 'free',
  subscription_expires_at TIMESTAMPTZ,
  r2_user_folder TEXT
);
```

**After:**
```sql
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ DEFAULT now(),
  coins INTEGER DEFAULT 150,
  subscription_status TEXT DEFAULT 'free',
  subscription_expires_at TIMESTAMPTZ,
  r2_user_folder TEXT,
  revenuecat_id TEXT UNIQUE  -- NEW
);
```

**Why:** Enables webhook to map RevenueCat user to Groove AI user.

---

## Verified as Already Working (No Changes Needed)

### 4. Coin Sync — Server-Side Authoritative

**Backend:** `/generate-video` endpoint deducts 60 coins atomically, returns `coins_remaining` in response.

**Frontend:** `GenerationService.swift` reads `coins_remaining` from backend response and updates `appState.serverCoins`.

**Status:** Already correct ✅

---

### 5. RevenueCat Webhook Handler

**Backend:** `/api/revenuecat-webhook` already exists (lines 730-778 in `index.js`)

Handles:
- `INITIAL_PURCHASE` → grant subscription + coins
- `RENEWAL` → extend subscription
- `CANCELLATION` → mark as cancelled
- `EXPIRATION` → remove subscription

**Status:** Already implemented ✅

---

## Files Modified

| File | Change Type |
|------|-------------|
| `GrooveAI/Services/RevenueCatService.swift` | Modified |
| `GrooveAI/Models/AppState.swift` | Modified |
| `groove-ai/supabase/schema.sql` | Modified |

---

## Deployment Steps Required

1. **Add `RevenueCatAPIKey` to Info.plist** in Xcode (key: `RevenueCatAPIKey`, value: `appl_dmOLXuPKMXatwKYxDHjLyYfULfu`)
2. **Run Supabase migration:** `ALTER TABLE users ADD COLUMN IF NOT EXISTS revenuecat_id TEXT UNIQUE;` ✅ (Blake ran this)
3. **Configure RevenueCat** to send webhooks to: `https://groove-ai-backend-1.onrender.com/api/revenuecat-webhook`

---

## Testing Recommendations

1. **Keychain persistence:** Reinstall app, verify userId persists
2. **Webhook:** Make a test purchase, verify coins are granted
3. **Coin sync:** Generate video, verify coins deducted correctly
