# Xcode Project Cleanup — Duplicate Build Phase References

**Issue:** Build fails with warnings about duplicate files in Compile Sources phase  
**Cause:** Pre-existing project structure issue (not related to Hero Video components)  
**Fix:** 2-minute Xcode cleanup

---

## Symptoms

Build output shows:
```
warning: Skipping duplicate build file in Compile Sources build phase:
  /Users/blakeyyyclaw/.openclaw/workspace/groove-ai/GrooveAI/Onboarding/Views-v2/GrooveAI/Onboarding/Views-v2/GrooveHeroScrollViewV2.swift
```

Notice the **nested path** — `Views-v2/GrooveAI/Onboarding/Views-v2/` (appears twice).

---

## Root Cause

Files in the Xcode project are referenced with their full nested paths **twice** in the Build Phases → Compile Sources list. This happens when:

1. Files were added to the project with the wrong reference path
2. Project was moved/renamed
3. Group structure in Xcode doesn't match filesystem

---

## Fix (In Xcode GUI)

### Step 1: Open Project Build Phases

1. Open `GrooveAI.xcodeproj` in Xcode
2. Select **Project → GrooveAI (target)**
3. Go to **Build Phases** tab
4. Expand **Compile Sources**

### Step 2: Identify Duplicates

Look for files with nested paths like:
```
GrooveAI/Onboarding/Views-v2/GrooveAI/Onboarding/Views-v2/GrooveHeroScrollViewV2.swift
```

Or:
```
GrooveAI/Onboarding/GrooveAI/Onboarding/GrooveOnboardingViewV2.swift
```

These are **duplicates** (the path appears twice in the hierarchy).

### Step 3: Remove Duplicates

For each duplicate:

1. **Right-click** on the duplicate entry in Compile Sources
2. Select **Delete** (or press Delete key)
3. **Keep only ONE reference** per file (the one with the correct single path)

**Files to check:**
- GrooveOnboardingViewV2.swift
- GrooveHeroScrollViewV2.swift
- GrooveDanceSelectViewV2.swift
- GrooveMagicMomentViewV2.swift
- GroovePaywallScreenV2.swift
- GroovePremiumMagicResultFlowViewV2.swift
- GrooveResultCTAViewV2.swift
- GrooveSubjectSelectViewV2.swift
- TrialEnabledScreenV2.swift

### Step 4: Verify Clean List

After cleanup, each file should appear **exactly once** in Compile Sources with path like:
```
GrooveAI/Onboarding/Views-v2/GrooveHeroScrollViewV2.swift
(NOT: GrooveAI/Onboarding/Views-v2/GrooveAI/Onboarding/Views-v2/...)
```

### Step 5: Build

Try building again:
```bash
xcodebuild -scheme GrooveAI -configuration Debug build
```

Should succeed with 0 errors.

---

## Alternative: CLI Fix (Advanced)

If you prefer command-line, you can edit the Xcode project file directly:

```bash
cd /Users/blakeyyyclaw/.openclaw/workspace/groove-ai
open -a TextEdit GrooveAI.xcodeproj/project.pbxproj
```

Search for the nested paths (e.g., `Views-v2/GrooveAI`) and remove duplicates, but **this is risky** if unfamiliar with the format.

**Recommendation:** Use the Xcode GUI method above (safer).

---

## After Cleanup

Once duplicates are removed:

1. **Build should succeed** ✅
2. **Add Hero Video components** (see HERO_VIDEO_INTEGRATION.md)
3. **Uncomment HeroVideoWallView** in GrooveHeroScrollViewV2.swift
4. **Test on simulator**

---

## References

- Xcode Build Phases: https://developer.apple.com/documentation/xcode/configuring-build-phases
- Common Xcode issues: https://developer.apple.com/xcode/

