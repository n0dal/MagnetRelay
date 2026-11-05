#!/bin/bash

# Visual Tests for MagnetRelay
# Captures one screenshot per screen state of the settings panel (3 setup steps + Ready) into
# Tests/screenshots/<test_name>.png. The panel is borderless, so a capture is the panel alone:
# no title bar, transparent outside its rounded corners, and taken without the system shadow
# (tools/render_brand.swift draws its own shadow when it places the panel on the hero).
#
# Usage: ./Tests/visual_tests.sh [test_name]
#   Run all tests:     ./Tests/visual_tests.sh
#   Run single test:   ./Tests/visual_tests.sh first_launch
#
# Needs: Screen Recording (window capture) and Accessibility + Automation for System Events
# (clicking through the steps) for the terminal that runs it.
#
# The app's settings (com.magnetrelay.app) are exported before the tests and restored afterwards,
# and the system appearance is put back if ready_dark changed it. The Keychain is never written:
# the tests never complete a Connect.
#
# After capturing, Tests/screenshots/ready.png and ready_dark.png feed
# `swift tools/render_brand.swift .` (README hero, social card) and
# `swift tools/render_brand.swift --appstore .`.
#
# On the Ready screen the panel closes when MagnetRelay stops being the active app (click-away),
# so keep other apps out of the way while a Ready test runs.

set -e

APP_BUNDLE_ID="com.magnetrelay.app"
APP_PATH="${MAGNETRELAY_APP:-/Applications/MagnetRelay.app}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCREENSHOT_DIR="$REPO_DIR/Tests/screenshots"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=""
DEFAULTS_BACKUP=""
HAD_DEFAULTS=false
ORIGINAL_DARK=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Ensure app is built and installed
ensure_app_installed() {
    if [ ! -d "$APP_PATH" ]; then
        echo -e "${YELLOW}App not installed. Building and installing...${NC}"
        cd "$REPO_DIR"
        xcodebuild -project MagnetRelay.xcodeproj -scheme MagnetRelay -configuration Debug build -quiet
        cp -r ~/Library/Developer/Xcode/DerivedData/MagnetRelay-*/Build/Products/Debug/MagnetRelay.app /Applications/
    fi
}

# Kill app if running
kill_app() {
    pkill -x "MagnetRelay" 2>/dev/null || true
    sleep 0.5
}

# ============================================================================
# STATE: owner backup / restore
# ============================================================================

backup_state() {
    BACKUP_DIR="$(mktemp -d -t magnetrelay-visual-tests)"
    DEFAULTS_BACKUP="$BACKUP_DIR/defaults.plist"
    if defaults export "$APP_BUNDLE_ID" "$DEFAULTS_BACKUP" 2>/dev/null; then
        HAD_DEFAULTS=true
    fi
    ORIGINAL_DARK=$(osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode' 2>/dev/null || true)
}

restore_state() {
    kill_app
    defaults delete "$APP_BUNDLE_ID" 2>/dev/null || true
    if [ "$HAD_DEFAULTS" = true ]; then
        defaults import "$APP_BUNDLE_ID" "$DEFAULTS_BACKUP"
        echo "Restored your MagnetRelay settings."
    fi
    [ -n "$BACKUP_DIR" ] && rm -rf "$BACKUP_DIR"
    if [ -n "$ORIGINAL_DARK" ]; then
        osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $ORIGINAL_DARK" 2>/dev/null || true
    fi
}

set_dark_mode() {
    osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $1" 2>/dev/null || true
    sleep 0.5
}

# Reset the app's settings to a clean first-launch state (the Keychain is left alone)
reset_defaults() {
    defaults delete "$APP_BUNDLE_ID" 2>/dev/null || true
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
        float)
            defaults write "$APP_BUNDLE_ID" "$key" -float "$value"
            ;;
        *)
            defaults write "$APP_BUNDLE_ID" "$key" -string "$value"
            ;;
    esac
}

# First run with an address filled in: the window opens on step 1 by itself.
setup_first_run() {
    local client=$1 host=$2 port=$3
    set_defaults "clientType" "$client"
    set_defaults "serverHost" "$host"
    set_defaults "serverPort" "$port"
    set_defaults "serverPath" ""
    set_defaults "useHTTPS" "false" bool
    set_defaults "username" "admin"
    set_defaults "hasCompletedSetup" "false" bool
}

# A completed setup (Ready screen). The tested-config fingerprint matches ServerConfig.currentConfigHash
# ("client|host|port|https|path|username"), so Ready shows "checked 2m ago".
setup_ready_config() {
    set_defaults "clientType" "qbittorrent"
    set_defaults "serverHost" "192.168.0.100"
    set_defaults "serverPort" "8080"
    set_defaults "serverPath" ""
    set_defaults "useHTTPS" "false" bool
    set_defaults "username" "admin"
    set_defaults "showNotifications" "true" bool
    set_defaults "hasCompletedSetup" "true" bool
    set_defaults "lastTestedConfigHash" "qbittorrent|192.168.0.100|8080|false||admin"
    set_defaults "lastConnectedAt" "$(( $(date +%s) - 120 ))" float
}

# ============================================================================
# DRIVING THE APP
# ============================================================================

# Launch the app. On first run (hasCompletedSetup false) it opens the settings window itself.
launch_app() {
    open "$APP_PATH"
    sleep 1.5
}

# Open the settings window from the menu bar item (needed once setup is complete).
open_settings_from_menu() {
    osascript <<'EOF' 2>/dev/null || true
tell application "System Events"
    tell process "MagnetRelay"
        try
            click menu bar item 1 of menu bar 2
            delay 0.3
            click menu item "Settings…" of menu 1 of menu bar item 1 of menu bar 2
        end try
    end tell
end tell
EOF
    sleep 1
}

# Click a button in the settings window by its title or accessibility label
# (e.g. "Continue", "Back", "Connect", or a client tile such as "Deluge").
click_button() {
    local label=$1
    local result
    result=$(osascript - "$label" <<'EOF' 2>/dev/null || true
on run argv
    set wanted to item 1 of argv
    tell application "System Events"
        tell process "MagnetRelay"
            repeat with el in (entire contents of window 1)
                try
                    if class of el is button then
                        if name of el is wanted or description of el is wanted then
                            click el
                            return "ok"
                        end if
                    end if
                end try
            end repeat
        end tell
    end tell
    return "missing"
end run
EOF
)
    if [ "$result" != "ok" ]; then
        echo -e "${RED}✗${NC} Couldn't find button \"$label\""
    fi
    sleep 0.6
}

# Capture the panel alone: window capture without the shadow keeps its rounded, transparent corners
take_screenshot() {
    local name=$1
    local filename="${SCREENSHOT_DIR}/${name}.png"
    mkdir -p "$SCREENSHOT_DIR"

    # Bring window to front
    osascript -e 'tell application "MagnetRelay" to activate' 2>/dev/null || true
    sleep 0.3

    # Use Python helper for proper window capture
    if python3 "$SCRIPT_DIR/window_capture.py" --capture "$filename" --no-shadow 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Screenshot: $filename"
        return 0
    fi

    # Fallback: Try to get window ID and capture
    local window_id=$(python3 "$SCRIPT_DIR/window_capture.py" --get-id 2>/dev/null)

    if [ -n "$window_id" ]; then
        screencapture -l"$window_id" -o -x "$filename"
        echo -e "${GREEN}✓${NC} Screenshot: $filename"
        return 0
    fi

    # Last resort fallback: region capture
    local pos=$(osascript -e 'tell application "System Events" to get position of first window of process "MagnetRelay"' 2>/dev/null)
    local size=$(osascript -e 'tell application "System Events" to get size of first window of process "MagnetRelay"' 2>/dev/null)

    if [ -n "$pos" ] && [ -n "$size" ]; then
        local x=$(echo "$pos" | cut -d',' -f1 | tr -d ' ')
        local y=$(echo "$pos" | cut -d',' -f2 | tr -d ' ')
        local w=$(echo "$size" | cut -d',' -f1 | tr -d ' ')
        local h=$(echo "$size" | cut -d',' -f2 | tr -d ' ')
        screencapture -R"${x},${y},${w},${h}" -x "$filename"
        echo -e "${YELLOW}⚠${NC} Screenshot (region fallback): $filename"
    else
        screencapture -x "$filename"
        echo -e "${YELLOW}⚠${NC} Screenshot (full screen fallback): $filename"
    fi
}

# ============================================================================
# TEST CASES
# ============================================================================

# Step 1: pick the client.
test_first_launch() {
    echo -e "\n${YELLOW}Test: First launch (step 1)${NC}"
    kill_app
    reset_defaults
    launch_app
    take_screenshot "first_launch"
    kill_app
}

# Step 2 for one client: picks its tile on step 1 so the app applies that client's port, path and
# HTTPS defaults, then continues to the address step.
run_client_test() {
    local name=$1 host=${2:-192.168.0.100}
    kill_app
    reset_defaults
    setup_first_run "qbittorrent" "$host" "8080"
    launch_app
    click_button "$name"
    click_button "Continue"
    take_screenshot "client_$(echo "$name" | tr '[:upper:]' '[:lower:]')"
    kill_app
}

test_client_qbittorrent() {
    echo -e "\n${YELLOW}Test: Step 2 - qBittorrent (port 8080)${NC}"
    run_client_test "qBittorrent"
}

test_client_transmission() {
    echo -e "\n${YELLOW}Test: Step 2 - Transmission (port 9091)${NC}"
    run_client_test "Transmission"
}

test_client_deluge() {
    echo -e "\n${YELLOW}Test: Step 2 - Deluge (port 8112)${NC}"
    run_client_test "Deluge"
}

test_client_rtorrent() {
    echo -e "\n${YELLOW}Test: Step 2 - rTorrent (port 8080, path /RPC2 shown)${NC}"
    run_client_test "rTorrent"
}

test_client_synology() {
    echo -e "\n${YELLOW}Test: Step 2 - Synology (HTTPS on, port 5001)${NC}"
    run_client_test "Synology" "nas.local"
}

# Step 3 for Deluge: no Username row, "Deluge only asks for a password."
test_signin_deluge() {
    echo -e "\n${YELLOW}Test: Step 3 - Deluge sign in${NC}"
    kill_app
    reset_defaults
    setup_first_run "deluge" "192.168.0.100" "8112"
    launch_app
    click_button "Continue"
    click_button "Continue"
    take_screenshot "signin_deluge"
    kill_app
}

# Step 3 with an error: nothing listens on 127.0.0.1:9, so Connect fails with "Couldn't reach…".
test_signin_error() {
    echo -e "\n${YELLOW}Test: Step 3 - connection error${NC}"
    kill_app
    reset_defaults
    setup_first_run "qbittorrent" "127.0.0.1" "9"
    launch_app
    click_button "Continue"
    click_button "Continue"
    click_button "Connect"
    sleep 2
    take_screenshot "signin_error"
    kill_app
}

# Ready: green pill, "checked 2m ago".
test_ready() {
    echo -e "\n${YELLOW}Test: Ready${NC}"
    kill_app
    reset_defaults
    setup_ready_config
    launch_app
    open_settings_from_menu
    take_screenshot "ready"
    kill_app
}

# Ready after the config was edited since the last test: grey pill, "not checked yet".
test_ready_unchecked() {
    echo -e "\n${YELLOW}Test: Ready - config edited after test${NC}"
    kill_app
    reset_defaults
    setup_ready_config
    set_defaults "serverPort" "8081"
    launch_app
    open_settings_from_menu
    take_screenshot "ready_unchecked"
    kill_app
}

# Ready in dark mode (switches the system appearance; restored on exit).
test_ready_dark() {
    echo -e "\n${YELLOW}Test: Ready - dark mode${NC}"
    kill_app
    reset_defaults
    setup_ready_config
    set_dark_mode true
    launch_app
    open_settings_from_menu
    take_screenshot "ready_dark"
    kill_app
    if [ -n "$ORIGINAL_DARK" ]; then set_dark_mode "$ORIGINAL_DARK"; fi
}

ALL_TESTS="first_launch client_qbittorrent client_transmission client_deluge client_rtorrent client_synology signin_deluge signin_error ready ready_unchecked ready_dark"

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo "========================================"
    echo "MagnetRelay Visual Tests"
    echo "========================================"
    echo "Timestamp: $TIMESTAMP"
    echo "Screenshots: $SCREENSHOT_DIR/"
    echo ""

    local test_name=${1:-all}

    if [ "$test_name" != "all" ] && ! declare -f "test_$test_name" > /dev/null; then
        echo -e "${RED}Unknown test: $test_name${NC}"
        echo "Available tests:"
        echo "  $ALL_TESTS" | fold -s -w 72
        exit 1
    fi

    ensure_app_installed
    backup_state
    trap restore_state EXIT

    if [ "$test_name" = "all" ]; then
        for t in $ALL_TESTS; do
            "test_$t"
        done
    else
        "test_$test_name"
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
