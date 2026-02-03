#!/bin/bash

# Visual Tests for Magnet Remote
# This script captures screenshots of all app states for visual verification
#
# Usage: ./Tests/visual_tests.sh [test_name]
#   Run all tests:     ./Tests/visual_tests.sh
#   Run single test:   ./Tests/visual_tests.sh first_launch

set -e

APP_BUNDLE_ID="com.magnetremote.app"
APP_PATH="/Applications/MagnetRemote.app"
SCREENSHOT_DIR="Tests/screenshots"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Ensure app is built and installed
ensure_app_installed() {
    if [ ! -d "$APP_PATH" ]; then
        echo -e "${YELLOW}App not installed. Building and installing...${NC}"
        cd "$(dirname "$0")/.."
        xcodebuild -project MagnetRemote.xcodeproj -scheme MagnetRemote -configuration Debug build -quiet
        cp -r ~/Library/Developer/Xcode/DerivedData/MagnetRemote-*/Build/Products/Debug/MagnetRemote.app /Applications/
    fi
}

# Kill app if running
kill_app() {
    pkill -x "MagnetRemote" 2>/dev/null || true
    sleep 0.5
}

# Launch app and open settings window
launch_app() {
    open "$APP_PATH"
    sleep 1

    # Click menu bar item to open Settings (in case window didn't auto-open)
    osascript <<'EOF'
tell application "System Events"
    tell process "MagnetRemote"
        try
            click menu bar item 1 of menu bar 2
            delay 0.2
            click menu item "Settings..." of menu 1 of menu bar item 1 of menu bar 2
        end try
    end tell
end tell
EOF
    sleep 1
}

# Take screenshot with label
# Captures just the app window (not full screen) using window bounds
take_screenshot() {
    local name=$1
    local filename="${SCREENSHOT_DIR}/${name}.png"
    mkdir -p "$SCREENSHOT_DIR"

    # Bring window to front
    osascript -e 'tell application "MagnetRemote" to activate' 2>/dev/null
    sleep 0.3

    # Get window bounds and capture just the window
    local pos=$(osascript -e 'tell application "System Events" to get position of first window of process "MagnetRemote"' 2>/dev/null)
    local size=$(osascript -e 'tell application "System Events" to get size of first window of process "MagnetRemote"' 2>/dev/null)

    if [ -n "$pos" ] && [ -n "$size" ]; then
        local x=$(echo "$pos" | cut -d',' -f1 | tr -d ' ')
        local y=$(echo "$pos" | cut -d',' -f2 | tr -d ' ')
        local w=$(echo "$size" | cut -d',' -f1 | tr -d ' ')
        local h=$(echo "$size" | cut -d',' -f2 | tr -d ' ')
        screencapture -R"${x},${y},${w},${h}" -x "$filename"
    else
        # Fallback to full screen
        screencapture -x "$filename"
    fi

    echo -e "${GREEN}✓${NC} Screenshot: $filename"
}

# Reset all user defaults to clean state
reset_defaults() {
    defaults delete "$APP_BUNDLE_ID" 2>/dev/null || true
    # Also clear keychain entry
    security delete-generic-password -s "com.magnetremote.server" 2>/dev/null || true
}

# Set specific defaults for testing
set_defaults() {
    local key=$1
    local value=$2
    local type=${3:-string}

    case $type in
        bool)
            defaults write "$APP_BUNDLE_ID" "$key" -bool "$value"
            ;;
        int)
            defaults write "$APP_BUNDLE_ID" "$key" -int "$value"
            ;;
        *)
            defaults write "$APP_BUNDLE_ID" "$key" -string "$value"
            ;;
    esac
}

# Configure sample server settings
setup_sample_config() {
    set_defaults "clientType" "qbittorrent"
    set_defaults "serverHost" "192.168.1.100"
    set_defaults "serverPort" "8080"
    set_defaults "username" "admin"
    set_defaults "useHTTPS" "false" bool
    set_defaults "hasCompletedSetup" "true" bool
}

# ============================================================================
# TEST CASES
# ============================================================================

test_first_launch() {
    echo -e "\n${YELLOW}Test: First Launch Experience${NC}"
    kill_app
    reset_defaults
    launch_app
    sleep 1
    take_screenshot "01_first_launch"
    kill_app
}

test_normal_settings() {
    echo -e "\n${YELLOW}Test: Normal Settings View${NC}"
    kill_app
    reset_defaults
    setup_sample_config
    launch_app
    sleep 1
    take_screenshot "02_normal_settings"
    kill_app
}

test_client_qbittorrent() {
    echo -e "\n${YELLOW}Test: Client - qBittorrent${NC}"
    kill_app
    reset_defaults
    setup_sample_config
    set_defaults "clientType" "qbittorrent"
    launch_app
    sleep 1
    take_screenshot "03_client_qbittorrent"
    kill_app
}

test_client_transmission() {
    echo -e "\n${YELLOW}Test: Client - Transmission${NC}"
    kill_app
    reset_defaults
    setup_sample_config
    set_defaults "clientType" "transmission"
    set_defaults "serverPort" "9091"
    launch_app
    sleep 1
    take_screenshot "04_client_transmission"
    kill_app
}

test_client_deluge() {
    echo -e "\n${YELLOW}Test: Client - Deluge${NC}"
    kill_app
    reset_defaults
    setup_sample_config
    set_defaults "clientType" "deluge"
    set_defaults "serverPort" "8112"
    launch_app
    sleep 1
    take_screenshot "05_client_deluge"
    kill_app
}

test_client_rtorrent() {
    echo -e "\n${YELLOW}Test: Client - rTorrent${NC}"
    kill_app
    reset_defaults
    setup_sample_config
    set_defaults "clientType" "rtorrent"
    launch_app
    sleep 1
    take_screenshot "06_client_rtorrent"
    kill_app
}

test_client_synology() {
    echo -e "\n${YELLOW}Test: Client - Synology${NC}"
    kill_app
    reset_defaults
    setup_sample_config
    set_defaults "clientType" "synology"
    set_defaults "serverPort" "5000"
    launch_app
    sleep 1
    take_screenshot "07_client_synology"
    kill_app
}

test_https_enabled() {
    echo -e "\n${YELLOW}Test: HTTPS Enabled${NC}"
    kill_app
    reset_defaults
    setup_sample_config
    set_defaults "useHTTPS" "true" bool
    launch_app
    sleep 1
    take_screenshot "08_https_enabled"
    kill_app
}

test_empty_config() {
    echo -e "\n${YELLOW}Test: Empty Configuration${NC}"
    kill_app
    reset_defaults
    set_defaults "hasCompletedSetup" "true" bool
    launch_app
    sleep 1
    take_screenshot "09_empty_config"
    kill_app
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo "========================================"
    echo "Magnet Remote Visual Tests"
    echo "========================================"
    echo "Timestamp: $TIMESTAMP"
    echo "Screenshots: $SCREENSHOT_DIR/"
    echo ""

    ensure_app_installed

    local test_name=${1:-all}

    if [ "$test_name" = "all" ]; then
        test_first_launch
        test_normal_settings
        test_client_qbittorrent
        test_client_transmission
        test_client_deluge
        test_client_rtorrent
        test_client_synology
        test_https_enabled
        test_empty_config
    else
        # Run specific test
        if declare -f "test_$test_name" > /dev/null; then
            "test_$test_name"
        else
            echo -e "${RED}Unknown test: $test_name${NC}"
            echo "Available tests:"
            echo "  first_launch, normal_settings, client_qbittorrent,"
            echo "  client_transmission, client_deluge, client_rtorrent,"
            echo "  client_synology, https_enabled, empty_config"
            exit 1
        fi
    fi

    echo ""
    echo "========================================"
    echo -e "${GREEN}All tests completed!${NC}"
    echo "Screenshots saved to: $SCREENSHOT_DIR/"
    echo "========================================"

    # List screenshots
    echo ""
    echo "Generated screenshots:"
    ls -la "$SCREENSHOT_DIR"/*.png 2>/dev/null || echo "No screenshots found"
}

main "$@"
