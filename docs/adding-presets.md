# Adding a New Dance Preset to Groove AI

Quick reference for Oscar or Codex when adding new dance styles.

## 3-Step Process

### 1. Upload video to R2
- Bucket: `groove-ai-videos`, folder: `/presets/`
- Requirements: single person, clean background, no cuts, no camera movement, 3–30s, MP4, <100MB

### 2. Update backend — `groove-ai-backend/index.js`

Find `PRESET_VIDEO_MAP` and add:

```js
'your-preset-id': 'Your Video Filename.mp4',
```

Key = dance_style ID (lowercase, hyphenated). Value = exact filename in R2 /presets/.

### 3. Update iOS — `GrooveAI/Models/DancePreset.swift`

Add to `allPresets` array:

```swift
DancePreset(
    id: "your-preset-id",
    name: "Display Name",
    shortDescription: "Short tagline",
    category: "Trending",
    badge: .trending,
    coinCost: 60,
    pillTags: ["🔥 Trending", "👤 All Faces"],
    placeholderGradientTop: Color(red: 0.04, green: 0.04, blue: 0.04),
    placeholderGradientBottom: Color(red: 0.10, green: 0.10, blue: 0.18),
    videoURL: "\(r2Base)/Your%20Video%20Filename.mp4",
    thumbnailURL: nil
)
```

### Then deploy:

- Backend: push index.js → Render auto-deploys (~2 min)
- iOS: push DancePreset.swift → build + TestFlight

## Notes

- thumbnailURL stays nil until thumbnail script runs
- Preset IDs must be unique and match exactly between iOS and backend