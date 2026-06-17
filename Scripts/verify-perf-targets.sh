#!/usr/bin/env bash
set -euo pipefail

DEVICE_NAME="Jiyong의 iPhone"
TIME_LIMIT="${TIME_LIMIT:-5s}"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/twix-perf-traces}"

if [[ -z "$DEVICE_NAME" ]]; then
  echo "error: set DEVICE_NAME to a connected iOS device name." >&2
  exit 64
fi

mkdir -p "$OUTPUT_DIR"

features=(
  "auth:org.yapp.twix.example.auth"
  "goal-detail:org.yapp.twix.example.goal-detail"
  "home:org.yapp.twix.example.home"
  "main-tab:org.yapp.twix.example.main-tab"
  "make-goal:org.yapp.twix.example.make-goal"
  "notification:org.yapp.twix.example.notification"
  "onboarding:org.yapp.twix.example.onboarding"
  "proof-photo:org.yapp.twix.example.proof-photo"
  "settings:org.yapp.twix.example.settings"
  "stats:org.yapp.twix.example.stats"
)

for item in "${features[@]}"; do
  slug="${item%%:*}"
  bundle_id="${item#*:}"
  output="$OUTPUT_DIR/$slug.trace"

  rm -rf "$output"
  echo "recording $slug ($bundle_id)"
  xcrun xctrace record \
    --device "$DEVICE_NAME" \
    --template "Time Profiler" \
    --time-limit "$TIME_LIMIT" \
    --output "$output" \
    --launch "$bundle_id" \
    -- \
    -UITEST \
    -UITEST_SEED default \
    -UITEST_DISABLE_ANIMATIONS \
    -UITEST_WAIT_READY
done

echo "traces written to $OUTPUT_DIR"
