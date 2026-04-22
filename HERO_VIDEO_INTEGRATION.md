# Hero Video Wall — Xcode Integration Guide

**Status:** Components created, ready for Xcode target linking  
**Files:** 4 Swift files in `GrooveAI/Onboarding/Components/`  
**Next Step:** Add to Xcode build target

---

## Quick Setup (2 minutes)

### 1. Open Xcode Project
```bash
open /Users/blakeyyyclaw/.openclaw/workspace/groove-ai/GrooveAI.xcodeproj
```

### 2. Add Files to Target

In Xcode:
1. **File → Add Files to "GrooveAI"**
2. Navigate to: `GrooveAI/Onboarding/Components/`
3. Select all 4 files:
   - `HeroVideoCell.swift`
   - `AVPlayerPool.swift`
   - `HeroVideoColumnView.swift`
   - `HeroVideoWallView.swift`
4. Ensure **"Copy items if needed"** is **unchecked** (files already in project)
5. Ensure **"Add to targets: GrooveAI"** is **checked**
6. Click **Add**

### 3. Uncomment Integration Code

Open `GrooveAI/Onboarding/Views-v2/GrooveHeroScrollViewV2.swift` and:

**Find this section (around line 44):**
```swift
// UNCOMMENT after adding components to Xcode target:
// HeroVideoWallView(videoURLs: videoURLs)

// TEMPORARY: Placeholder (will be replaced by HeroVideoWallView)
Color.gray.opacity(0.3)
    .frame(height: 300)
```

**Replace with:**
```swift
HeroVideoWallView(videoURLs: videoURLs)
```

### 4. Build & Test

```bash
cd /Users/blakeyyyclaw/.openclaw/workspace/groove-ai
xcodebuild -scheme GrooveAI -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build
```

---

## What Gets Added

### File: HeroVideoCell.swift (1.5 KB)
- UICollectionViewCell with AVPlayerLayer
- Supports pooled player assignment
- Styling: 9:16 portrait, 12pt rounded corners, white border

### File: AVPlayerPool.swift (2.0 KB)
- Thread-safe object pool (9 AVQueuePlayers)
- Methods: `acquirePlayer()`, `releasePlayer()`, `loadVideo()`
- Seamless looping via AVPlayerLooper

### File: HeroVideoColumnView.swift (6.9 KB)
- UIViewRepresentable wrapping UICollectionView
- Timer-based infinite auto-scroll (60fps)
- Two scroll modes: `.down` (normal) and `.up` (parallax)
- Auto player lifecycle management

### File: HeroVideoWallView.swift (2.1 KB)
- SwiftUI container for 3-column hero wall
- Shared AVPlayerPool across columns
- Column 1 & 3: scroll DOWN, Column 2: scroll UP (parallax)

---

## Expected Result

After integration, the hero onboarding screen will display:

```
┌─────────────────────────────────────┐
│        GrooveAI (wordmark)          │
├──────┬──────────┬──────┤            
│Video1│ Video2   │Video3│ (playing   
│      │  (UP)    │      │  & looping)
│      │          │      │            
├──────┴──────────┴──────┤            
│ Make Anyone Drop... (CTA) │          
└─────────────────────────────────────┘
```

Videos load from R2 and play in a parallax 3-column infinite scroll.

---

## Troubleshooting

### Build Error: "HeroVideoWallView not found"
- Files not added to target. Repeat **Step 2** above.
- In Xcode, go to **Target → GrooveAI → Build Phases → Compile Sources**
- Verify all 4 `.swift` files are listed.

### No Video Playback (Grey Box Only)
- Placeholder is showing. Uncomment didn't work.
- Verify `GrooveHeroScrollViewV2.swift` line 44-48 is updated correctly.

### Memory Warning / Crashes Under Scroll
- Player pool issue. Verify `AVPlayerPool.swift` line 35-40 (releasePlayer logic).
- Check that `HeroVideoCell.currentPlayer` is public (not private).

### Video Not Loading
- Network issue (videos hosted on R2).
- Check network connectivity: `curl https://videos.trygrooveai.com/presets/big-guy-V5-AI.mp4 -I`
- Expected: `HTTP/2 200` response.

---

## After Integration

Once the 4 files are added to the Xcode target:
1. Build should succeed ✅
2. Hero section renders with 3 columns of looping videos ✅
3. Parallax effect visible (middle column scrolls opposite) ✅
4. CTA button advances to next onboarding screen ✅

---

## Performance Notes

- **Memory:** ~9 players × ~1-2MB each = ~15MB total (vs 50MB+ if creating new players)
- **CPU:** 60fps timer scroll (standard iOS smoothness)
- **Network:** Videos cached by iOS HTTP layer; no custom caching needed
- **Thermal:** Minimal; all players muted

---

## Reference

- Full technical spec: `HERO_VIDEO_IMPLEMENTATION.md`
- Original architecture: See "AVPlayer Object Pooling" pattern
- iOS AVFoundation docs: https://developer.apple.com/avfoundation/

