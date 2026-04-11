# Groove AI — Architecture Recommendation

## Current State Assessment

### What We Have

| Component | Status |
|-----------|--------|
| **iOS App** | Code-driven paywalls in SwiftUI |
| **RevenueCat** | Integration working, webhook fixed |
| **Backend** | User creation, coin deduction, webhook synced |
| **Onboarding** | Custom SwiftUI views |
| **Paywalls** | Custom code (not remote) |

### Verified Issues
- Webhook user matching ✅ FIXED (now uses user.id)
- Purchase recognition ✅ FIXED (webhook now logs properly)
- Coin persistence ✅ WORKING (add-coins endpoint)

---

## Recommendation: Hybrid Approach

**For Groove AI specifically: Keep onboarding in code, move paywalls to remote**

### What to Keep in Code (Native SwiftUI)
1. **Onboarding flow** - animations, video players, screens 1-7
2. **Home screen / Dance grid** - core app UI
3. **Video generation** - all generation logic
4. **User settings / profile**
5. **Core app navigation** - tab bar, routing

### What Can Move to Remote (RevenueCat/Superwall)
1. **Paywall presentation** - can swap out offers quickly
2. **Offer configuration** - pricing, trials, comparisons
3. **A/B testing** - test different offers
4. **Purchase flow** - Apple/Google purchase sheet (handled by RC anyway)

### What Stays Code Even With Remote Paywalls
- Purchase button triggers
- Post-purchase state updates (though RC handles much)
- Entitlement checking (can use RC's `.isActive` but keep local cache)
- Coin balance display

---

## Why This Hybrid Works for Groove AI

| Factor | Recommendation | Reason |
|--------|---------------|--------|
| **Onboarding complexity** | Keep in code | Video integration, custom animations need precise control |
| **Speed of iteration** | Remote paywalls | Test different prices/offers without app release |
| **A/B testing** | Remote | Easy to swap offers in RC/Superwall |
| **Entitlement reliability** | Hybrid | Use RC `.isActive` but cache locally for quick loads |
| **Purchase debugging** | Code | Log purchases, verify receipt, handle edge cases |
| **Backend sync** | Already working | Webhook handles subscription, coins come from RC |
| **Developer ergonomics** | Hybrid | Don't hand-build in drag-drop, use code for complex parts |

---

## AI-Assisted Workflow (Practical)

**Yes, Codex can help with:**
- Generate RevenueCat PaywallView JSON/config from your existing designs
- Template Superwall blocks adapted for Groove AI
- Convert your current SwiftUI paywall structure to remote config
- Write A/B test variants as code, then run remotely

**What's realistic:**
1. Codex generates base paywall config from your specs
2. You refine in RevenueCat/Superwall dashboard
3. Push changes without app release
4. Monitor results, iterate

**What's NOT realistic:**
- Full Superwall setup from scratch (too complex)
- Replacing onboarding animations with remote config
- Entire app moving to drag-drop

---

## Specific Answers

### Is RevenueCat remote paywalls enough?
**Yes** - RC handles purchases, entitlements, trials. For Groove AI's paywall needs (offers, pricing, CTAs), RC alone is sufficient.

### Would Superwall help?
**Only if you need advanced A/B testing** - Superwall adds experimentation layers on top of RC. If you're happy with basic A/B in RC, skip Superwall.

### Purchase logic in code?
**Yes** - Keep purchase triggers and verification in Swift. RC handles the sheet, but you validate post-purchase.

### What stays native no matter what?
- Onboarding video players
- Dance grid / generation UI
- Settings screens

### If designing from scratch:
- Onboarding: CODE
- Paywall offers: REMOTE (RC)
- Purchase verification: CODE
- Core app: CODE
- A/B testing: REMOTE (RC)

---

## Next Steps

If you adopt this direction:
1. Keep onboarding in SwiftUI (done)
2. Move paywall offers to RevenueCat remote
3. Use Codex to generate RC paywall templates from your designs
4. Deploy webhook fix (done)
5. Test purchase flow end-to-end

---

## Entitlement Check (Quick Verify)

Check in RevenueCat Dashboard:
- Entitlement identifier: `premium` or whatever you use in `.entitlement()`
- Products attached to offering `default`
- iOS app expects same entitlement key

Your current code shows entitlement check via `isSubscribed` flag, which comes from RC. Should work once webhook deploys.

**Recommendation: Hybrid** - Code for complex/unique parts, remote for offers/experiments.