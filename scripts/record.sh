#!/usr/bin/env bash
# Records a short screen capture from the connected Android device and
# pulls it into today's devmedia/ folder, named for the feature it shows.
# Vertical/9:16 by default (phone screen) -- ready for TikTok/Reels.
#
# Usage: scripts/record.sh <feature-name> [duration-seconds]
#   scripts/record.sh nadir-floor-clear
#   scripts/record.sh battle-screen-manual 45
#
# Requires: adb on PATH (or ANDROID_SDK platform-tools), a connected/
# authorized device, and the project run from its own root (so
# devmedia/ lands in the right place).

set -euo pipefail

FEATURE_NAME="${1:?Usage: scripts/record.sh <feature-name> [duration-seconds]}"
DURATION="${2:-30}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TODAY="$(date +%Y-%m-%d)"
OUT_DIR="$PROJECT_ROOT/devmedia/$TODAY"
OUT_FILE="$OUT_DIR/${TODAY}_${FEATURE_NAME}.mp4"
DEVICE_FILE="/sdcard/hollowhunter_rec.mp4"

mkdir -p "$OUT_DIR"

if ! command -v adb >/dev/null 2>&1; then
	echo "adb not found on PATH -- add platform-tools to PATH first." >&2
	exit 1
fi

if ! adb get-state >/dev/null 2>&1; then
	echo "No authorized device connected (adb get-state failed)." >&2
	exit 1
fi

echo "Recording ${DURATION}s to device, screen must stay on and showing the feature now..."
# MSYS_NO_PATHCONV avoids git-bash mangling the /sdcard/... device path into
# a Windows path (same issue hit repeatedly this session with adb shell/pull).
# `adb shell` calls are all-remote so it's safe for the whole command; `adb
# pull` mixes a remote source with a local destination, so it instead uses a
# doubled leading slash (//sdcard/...) to protect just that one argument
# while still letting the local destination path convert normally.
MSYS_NO_PATHCONV=1 adb shell screenrecord --time-limit "$DURATION" "$DEVICE_FILE"

echo "Pulling recording..."
adb pull "/$DEVICE_FILE" "$OUT_FILE" >/dev/null
MSYS_NO_PATHCONV=1 adb shell rm -f "$DEVICE_FILE"

echo "Saved: $OUT_FILE"
