#!/bin/bash

# Quick screenshot helper for MagnetRemote
# Captures just the app window (not full screen)
#
# Usage: ./Tests/screenshot.sh [output_name]
#   ./Tests/screenshot.sh                    # Saves to Tests/screenshots/quick.png
#   ./Tests/screenshot.sh my_test            # Saves to Tests/screenshots/my_test.png
#   ./Tests/screenshot.sh --reset            # Reset to first-launch state
#   ./Tests/screenshot.sh --reset my_test    # Reset + custom name

APP_BUNDLE_ID="com.magnetremote.app"
APP_PATH="/Applications/MagnetRemote.app"
SCREENSHOT_DIR="Tests/screenshots"

# Parse arguments
RESET=false
OUTPUT_NAME="quick"

while [[ $# -gt 0 ]]; do
    case $1 in
        --reset)
            RESET=true
            shift
            ;;
        *)
            OUTPUT_NAME="$1"
            shift
            ;;
    esac
done

mkdir -p "$SCREENSHOT_DIR"

# Kill existing instance
pkill -x "MagnetRemote" 2>/dev/null
sleep 0.5

# Reset to first-launch state if requested
if [ "$RESET" = true ]; then
    defaults delete "$APP_BUNDLE_ID" 2>/dev/null || true
    security delete-generic-password -s "com.magnetremote.server" 2>/dev/null || true
    echo "Reset to first-launch state"
fi

# Launch app
open "$APP_PATH"
sleep 2

# Bring window to front
osascript -e 'tell application "MagnetRemote" to activate' 2>/dev/null
sleep 0.3

# Get window position and size
POS=$(osascript -e 'tell application "System Events" to get position of first window of process "MagnetRemote"' 2>/dev/null)
SIZE=$(osascript -e 'tell application "System Events" to get size of first window of process "MagnetRemote"' 2>/dev/null)

if [ -n "$POS" ] && [ -n "$SIZE" ]; then
    # Parse coordinates: "x, y" -> x,y
    X=$(echo "$POS" | cut -d',' -f1 | tr -d ' ')
    Y=$(echo "$POS" | cut -d',' -f2 | tr -d ' ')
    W=$(echo "$SIZE" | cut -d',' -f1 | tr -d ' ')
    H=$(echo "$SIZE" | cut -d',' -f2 | tr -d ' ')

    # Capture just the window region
    OUTPUT_PATH="$SCREENSHOT_DIR/${OUTPUT_NAME}.png"
    screencapture -R"${X},${Y},${W},${H}" -x "$OUTPUT_PATH"
    echo "Screenshot saved: $OUTPUT_PATH"
else
    # Fallback to full screen if window detection fails
    echo "Warning: Could not detect window bounds, capturing full screen"
    OUTPUT_PATH="$SCREENSHOT_DIR/${OUTPUT_NAME}.png"
    screencapture -x "$OUTPUT_PATH"
    echo "Screenshot saved: $OUTPUT_PATH"
fi
