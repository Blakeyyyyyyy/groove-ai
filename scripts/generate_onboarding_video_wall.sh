#!/usr/bin/env bash
# generate_onboarding_video_wall.sh
# Generates a single pre-rendered looping video wall for GrooveAI onboarding
# Replaces the live 12-AVPlayer carousel with one smooth MP4

set -euo pipefail

VIDEOS_DIR="/Users/blakeyyyclaw/factory/Videos for home page hero"
PROJECT_DIR="/Users/blakeyyyclaw/.openclaw/workspace/groove-ai"
OUTPUT_VIDEO="$PROJECT_DIR/GrooveAI/Resources/onboarding_video_wall.mp4"
OUTPUT_POSTER="$PROJECT_DIR/GrooveAI/Resources/onboarding_video_wall_poster.png"
TMP_DIR="/tmp/groove_video_wall"
FFMPEG="/opt/homebrew/bin/ffmpeg"

# Layout constants
CARD_W=240
CARD_H=426
GAP=8
CARD_STEP=434
STRIP_H=1728
DOUBLE_STRIP_H=3456
VISIBLE_H=924         # must be even for libx264; 925 rounds to 924 via FFmpeg crop anyway
OUTPUT_W=736
COL2_X=248
COL3_X=496
DURATION=12
FPS=30
BG_COLOR=0x0d0d1a

# Video assignments (column : filename)
COL1_0="big-guy-V5-AI.mp4"
COL1_1="c-walk-V5-AI.mp4"
COL1_2="trag-V5-AI.mp4"
COL1_3="macarena.mp4"

COL2_0="milkshake-ai.mp4"
COL2_1="ophelia-ai.mp4"
COL2_2="coco-channel-75fcae6c.mp4"
COL2_3="jenny-ai.mp4"

COL3_0="cotton-eye-joe.mp4"
COL3_1="v2.6-pro-milkshake.mp4"
COL3_2="witch-doctor-v3.mp4"
COL3_3="big-guy-0c6caad3.mp4"

echo "============================================"
echo "GrooveAI Onboarding Video Wall Generator"
echo "============================================"

# ── Validation: all 12 videos must exist and be non-empty ──────────────────────
echo ""
echo "Step 0: Validating source videos..."
ALL_VIDEOS=(
  "$COL1_0" "$COL1_1" "$COL1_2" "$COL1_3"
  "$COL2_0" "$COL2_1" "$COL2_2" "$COL2_3"
  "$COL3_0" "$COL3_1" "$COL3_2" "$COL3_3"
)

VALIDATION_FAILED=0
for VID in "${ALL_VIDEOS[@]}"; do
  FULL_PATH="$VIDEOS_DIR/$VID"
  if [ ! -f "$FULL_PATH" ]; then
    echo "  ERROR: Missing: $FULL_PATH"
    VALIDATION_FAILED=1
  elif [ ! -s "$FULL_PATH" ]; then
    echo "  ERROR: Empty file: $FULL_PATH"
    VALIDATION_FAILED=1
  else
    SIZE=$(du -sh "$FULL_PATH" | cut -f1)
    echo "  OK: $VID ($SIZE)"
  fi
done

if [ "$VALIDATION_FAILED" -eq 1 ]; then
  echo ""
  echo "FATAL: One or more source videos are missing or empty. Aborting."
  exit 1
fi
echo "All 12 videos validated."

# ── Setup tmp dir ───────────────────────────────────────────────────────────────
echo ""
echo "Step 1: Setting up temp directory..."
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
mkdir -p "$(dirname "$OUTPUT_VIDEO")"

# ── Step 1: Scale each card video ──────────────────────────────────────────────
echo ""
echo "Step 1: Scaling 12 card videos to ${CARD_W}x${CARD_H}..."

scale_card() {
  local INPUT="$1"
  local OUTPUT="$2"
  local NAME="$3"
  echo "  Scaling $NAME..."
  "$FFMPEG" -y -stream_loop -1 -i "$INPUT" -t $DURATION \
    -vf "scale=${CARD_W}:${CARD_H}:force_original_aspect_ratio=increase,crop=${CARD_W}:${CARD_H}" \
    -an -r $FPS -c:v libx264 -preset ultrafast -crf 10 \
    "$OUTPUT" 2>/dev/null
}

scale_card "$VIDEOS_DIR/$COL1_0" "$TMP_DIR/c1_0.mp4" "$COL1_0"
scale_card "$VIDEOS_DIR/$COL1_1" "$TMP_DIR/c1_1.mp4" "$COL1_1"
scale_card "$VIDEOS_DIR/$COL1_2" "$TMP_DIR/c1_2.mp4" "$COL1_2"
scale_card "$VIDEOS_DIR/$COL1_3" "$TMP_DIR/c1_3.mp4" "$COL1_3"
scale_card "$VIDEOS_DIR/$COL2_0" "$TMP_DIR/c2_0.mp4" "$COL2_0"
scale_card "$VIDEOS_DIR/$COL2_1" "$TMP_DIR/c2_1.mp4" "$COL2_1"
scale_card "$VIDEOS_DIR/$COL2_2" "$TMP_DIR/c2_2.mp4" "$COL2_2"
scale_card "$VIDEOS_DIR/$COL2_3" "$TMP_DIR/c2_3.mp4" "$COL2_3"
scale_card "$VIDEOS_DIR/$COL3_0" "$TMP_DIR/c3_0.mp4" "$COL3_0"
scale_card "$VIDEOS_DIR/$COL3_1" "$TMP_DIR/c3_1.mp4" "$COL3_1"
scale_card "$VIDEOS_DIR/$COL3_2" "$TMP_DIR/c3_2.mp4" "$COL3_2"
scale_card "$VIDEOS_DIR/$COL3_3" "$TMP_DIR/c3_3.mp4" "$COL3_3"
echo "All 12 cards scaled."

# ── Step 2: Build column strips (double height for seamless loop) ──────────────
echo ""
echo "Step 2: Building column strips (${CARD_W}x${DOUBLE_STRIP_H})..."

build_strip() {
  local COL="$1"  # 1, 2, or 3
  echo "  Building strip for column $COL..."
  "$FFMPEG" -y \
    -i "$TMP_DIR/c${COL}_0.mp4" -i "$TMP_DIR/c${COL}_1.mp4" \
    -i "$TMP_DIR/c${COL}_2.mp4" -i "$TMP_DIR/c${COL}_3.mp4" \
    -filter_complex "
      [0:v]split=2[a0][b0];
      [1:v]split=2[a1][b1];
      [2:v]split=2[a2][b2];
      [3:v]split=2[a3][b3];
      color=c=${BG_COLOR}:size=${CARD_W}x${DOUBLE_STRIP_H}:r=${FPS}:d=${DURATION}[bg];
      [bg][a0]overlay=0:0[s1];
      [s1][a1]overlay=0:434[s2];
      [s2][a2]overlay=0:868[s3];
      [s3][a3]overlay=0:1302[s4];
      [s4][b0]overlay=0:1728[s5];
      [s5][b1]overlay=0:2162[s6];
      [s6][b2]overlay=0:2596[s7];
      [s7][b3]overlay=0:3030[out]
    " -map "[out]" -an -r $FPS -t $DURATION \
    -c:v libx264 -preset ultrafast -crf 10 \
    "$TMP_DIR/strip${COL}.mp4" 2>/dev/null
  echo "  Strip $COL done."
}

build_strip 1
build_strip 2
build_strip 3
echo "All 3 strips built."

# ── Step 3: Animate each column (scroll via crop) ─────────────────────────────
echo ""
echo "Step 3: Animating column scrolls..."

# Column 1: scroll DOWN
echo "  Animating column 1 (scroll down)..."
"$FFMPEG" -y -i "$TMP_DIR/strip1.mp4" \
  -vf "crop=${CARD_W}:${VISIBLE_H}:0:'t*1728/12'" \
  -an -r $FPS -t $DURATION -c:v libx264 -preset ultrafast -crf 10 \
  "$TMP_DIR/col1.mp4" 2>/dev/null

# Column 2: scroll UP
echo "  Animating column 2 (scroll up)..."
"$FFMPEG" -y -i "$TMP_DIR/strip2.mp4" \
  -vf "crop=${CARD_W}:${VISIBLE_H}:0:'1728-t*1728/12'" \
  -an -r $FPS -t $DURATION -c:v libx264 -preset ultrafast -crf 10 \
  "$TMP_DIR/col2.mp4" 2>/dev/null

# Column 3: scroll DOWN
echo "  Animating column 3 (scroll down)..."
"$FFMPEG" -y -i "$TMP_DIR/strip3.mp4" \
  -vf "crop=${CARD_W}:${VISIBLE_H}:0:'t*1728/12'" \
  -an -r $FPS -t $DURATION -c:v libx264 -preset ultrafast -crf 10 \
  "$TMP_DIR/col3.mp4" 2>/dev/null

echo "All 3 columns animated."

# ── Step 4: Composite 3 columns into final output ─────────────────────────────
echo ""
echo "Step 4: Compositing final ${OUTPUT_W}x${VISIBLE_H} video..."
"$FFMPEG" -y \
  -i "$TMP_DIR/col1.mp4" \
  -i "$TMP_DIR/col2.mp4" \
  -i "$TMP_DIR/col3.mp4" \
  -filter_complex "
    color=c=${BG_COLOR}:size=${OUTPUT_W}x${VISIBLE_H}:r=${FPS}:d=${DURATION}[canvas];
    [canvas][0:v]overlay=0:0[f1];
    [f1][1:v]overlay=248:0[f2];
    [f2][2:v]overlay=496:0[final]
  " -map "[final]" \
  -c:v libx264 -preset fast -crf 23 -pix_fmt yuv420p \
  -an -t $DURATION "$OUTPUT_VIDEO" 2>/dev/null
echo "Final video composited."

# ── Step 5: Extract poster frame ──────────────────────────────────────────────
echo ""
echo "Step 5: Extracting poster frame..."
"$FFMPEG" -y -i "$OUTPUT_VIDEO" -frames:v 1 -q:v 2 "$OUTPUT_POSTER" 2>/dev/null
echo "Poster extracted."

# ── Step 6: Cleanup ───────────────────────────────────────────────────────────
echo ""
echo "Step 6: Cleaning up temp files..."
rm -rf "$TMP_DIR"
echo "Temp cleaned."

# ── Validation ────────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "Final Validation"
echo "============================================"

SUCCESS=1

if [ -f "$OUTPUT_VIDEO" ]; then
  VIDEO_SIZE=$(du -sh "$OUTPUT_VIDEO" | cut -f1)
  VIDEO_BYTES=$(stat -f%z "$OUTPUT_VIDEO")
  echo "  Video:  $OUTPUT_VIDEO"
  echo "  Size:   $VIDEO_SIZE"
  if [ "$VIDEO_BYTES" -lt 1048576 ]; then
    echo "  WARNING: Video is < 1MB — may be incomplete"
    SUCCESS=0
  else
    echo "  Status: OK (> 1MB)"
  fi
else
  echo "  ERROR: Output video not found at $OUTPUT_VIDEO"
  SUCCESS=1
fi

if [ -f "$OUTPUT_POSTER" ]; then
  POSTER_SIZE=$(du -sh "$OUTPUT_POSTER" | cut -f1)
  echo "  Poster: $OUTPUT_POSTER"
  echo "  Size:   $POSTER_SIZE"
  echo "  Status: OK"
else
  echo "  ERROR: Output poster not found at $OUTPUT_POSTER"
  SUCCESS=0
fi

echo ""
if [ "$SUCCESS" -eq 1 ]; then
  echo "SUCCESS: Video wall generated successfully!"
else
  echo "FAILED: One or more outputs are missing or invalid."
  exit 1
fi
