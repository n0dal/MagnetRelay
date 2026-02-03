# Magnet Remote

A macOS menu bar app that handles `magnet:` URLs and forwards them to remote torrent clients.

## Project Overview

Magnet Remote registers as the system-wide handler for `magnet:` URL scheme. When a user clicks a magnet link in any app (browser, email, etc.), macOS routes it to this app, which forwards it to the user's configured torrent client server.

**Target:** macOS 13.0+ (Sonoma)
**Language:** Swift 5.9, SwiftUI
**Distribution:** Potential App Store release

## Architecture

```
MagnetRemote/
├── MagnetRemoteApp.swift      # App entry point, SwiftUI lifecycle
├── AppDelegate.swift          # Menu bar setup, URL event handling
├── SettingsView.swift         # Settings UI
├── DesignSystem.swift         # Color tokens, typography, spacing, animations
├── Components.swift           # Reusable UI components (MRSectionCard, MRButton, etc.)
├── Models/
│   └── ServerConfig.swift     # User configuration (AppStorage-backed)
├── Backends/
│   ├── TorrentBackend.swift   # Protocol + BackendFactory
│   ├── QBittorrentBackend.swift
│   ├── TransmissionBackend.swift
│   ├── DelugeBackend.swift
│   ├── RTorrentBackend.swift
│   └── SynologyBackend.swift
├── Services/
│   ├── MagnetHandler.swift    # Core magnet processing logic
│   ├── KeychainService.swift  # Secure credential storage
│   └── LaunchAtLogin.swift    # SMAppService wrapper
├── Assets.xcassets/           # App icon (magnet themed, purple/blue)
├── Info.plist                 # URL scheme registration (magnet:)
└── MagnetRemote.entitlements  # Sandbox + network client

Tests/
├── visual_tests.sh            # Automated visual testing script
├── screenshot.sh              # Quick screenshot helper for ad-hoc testing
└── screenshots/               # Generated test screenshots
```

## Key Patterns

### URL Handling
- Registered in `Info.plist` under `CFBundleURLTypes`
- Received via `NSAppleEventManager` in `AppDelegate.applicationWillFinishLaunching`
- Must register early (willFinish, not didFinish) to catch URLs on cold launch

### Design System
- Inspired by ContextAtlas project's design patterns
- Color tokens: `Color.MR.accent`, `.surface`, `.textPrimary`, etc.
- Typography: `Font.MR.title1`, `.body`, `.caption`, etc.
- Spacing: `MRSpacing.sm`, `.md`, `.lg`, etc.
- Components prefixed with `MR` (MRSectionCard, MRPrimaryButton, etc.)
- Teal/cyan accent color palette (network utility aesthetic)

### Backend Protocol
All torrent clients implement `TorrentBackend`:
```swift
protocol TorrentBackend {
    func testConnection(url: String, username: String, password: String) async throws
    func addMagnet(_ magnet: String, url: String, username: String, password: String) async throws
}
```

### Configuration
- `ServerConfig.shared` singleton with `@AppStorage` properties
- Password stored separately in Keychain via `KeychainService`

## Supported Backends

| Client | API Type | Status |
|--------|----------|--------|
| qBittorrent | REST (Web API v2) | ✅ Tested |
| Transmission | JSON-RPC | ✅ Implemented |
| Deluge | JSON-RPC | ✅ Implemented |
| rTorrent | XML-RPC | ✅ Implemented |
| Synology Download Station | REST | ✅ Implemented |

## Build & Run

```bash
cd ~/Code/MagnetRemote

# Generate Xcode project (after adding new files)
xcodegen generate

# Build
xcodebuild -project MagnetRemote.xcodeproj -scheme MagnetRemote -configuration Debug build

# Install to /Applications
cp -r ~/Library/Developer/Xcode/DerivedData/MagnetRemote-*/Build/Products/Debug/MagnetRemote.app /Applications/

# Run
open /Applications/MagnetRemote.app
```

## Important Notes

- **Bundle ID:** `com.magnetremote.app` (used for defaults, keychain, etc.)
- **Menu bar only:** No Dock icon (`LSUIElement: true`)
- **Settings window:** Created manually via `NSHostingController` (SwiftUI Settings scene doesn't work reliably in menu bar apps)
- **Entitlements:** Requires `com.apple.security.network.client` for API calls
- **URL path bug:** When using `URL.appendingPathComponent()`, don't include leading slash (causes double-slash)

## Testing

### Manual Testing

Test magnet handling from Terminal:
```bash
open "magnet:?xt=urn:btih:TESTHASH&dn=testfile"
```

### Visual Tests

The `Tests/` directory contains automated visual testing tools that capture screenshots of all app states.

```bash
# Run all visual tests (captures screenshots of every app state)
./Tests/visual_tests.sh

# Run a specific test
./Tests/visual_tests.sh first_launch
./Tests/visual_tests.sh normal_settings
./Tests/visual_tests.sh client_transmission
```

**Available Tests:**

| Test Name | Description |
|-----------|-------------|
| `first_launch` | First-time user experience with welcome banner |
| `normal_settings` | Standard settings view after setup complete |
| `client_qbittorrent` | qBittorrent client selected |
| `client_transmission` | Transmission client selected |
| `client_deluge` | Deluge client selected |
| `client_rtorrent` | rTorrent client selected |
| `client_synology` | Synology Download Station selected |
| `https_enabled` | HTTPS protocol toggle enabled |
| `empty_config` | Settings with no server configured |

**Screenshots Location:** `Tests/screenshots/`

**Adding New Tests:**

To add a new visual test, add a function to `Tests/visual_tests.sh`:
```bash
test_my_new_state() {
    echo -e "\n${YELLOW}Test: My New State${NC}"
    kill_app
    reset_defaults
    # Set up the specific state using set_defaults
    set_defaults "someKey" "someValue"
    launch_app
    sleep 1
    take_screenshot "10_my_new_state"
    kill_app
}
```

Then add `test_my_new_state` to the `main()` function's test list.

### UI Debugging & Visual Verification

**IMPORTANT: When the user asks to see something in the app or references a UI feature:**

1. **Check if a relevant test exists** in `Tests/visual_tests.sh`
2. **If yes:** Run that test, read the screenshot, analyze it
3. **If no:** Create a new test for that state, run it, analyze the screenshot

**Quick Screenshot** (captures just the app window, not full screen):
```bash
# Screenshot current app state
./Tests/screenshot.sh

# Reset to first-launch state, then screenshot
./Tests/screenshot.sh --reset

# Custom named screenshot
./Tests/screenshot.sh my_feature_test

# Screenshots saved to Tests/screenshots/
```

**Custom State Testing:**
```bash
# Set up specific state before screenshot
defaults write com.magnetremote.app clientType -string "transmission"
defaults write com.magnetremote.app serverHost -string "myserver.local"
./Tests/screenshot.sh custom_state
```

**Feature Verification Workflow** (for specific features or after changes):
```bash
# Run existing test
./Tests/visual_tests.sh first_launch

# Or run all tests after UI changes
./Tests/visual_tests.sh

# Screenshots are saved to Tests/screenshots/
# Read the relevant screenshot file to analyze
```

**Creating New Tests:**

When a user asks about a feature not covered by existing tests, add it to `Tests/visual_tests.sh`:
```bash
test_feature_name() {
    echo -e "\n${YELLOW}Test: Feature Description${NC}"
    kill_app
    reset_defaults
    # Configure the specific state
    set_defaults "key" "value"
    launch_app
    sleep 1
    take_screenshot "XX_feature_name"
    kill_app
}
```

Then add `test_feature_name` to the main() function and run it.

**Key Principle:** Always visually verify by taking and analyzing screenshots rather than assuming the UI looks correct.

## App Store Considerations

- Emphasize legitimate use cases (Linux ISOs, open source distribution)
- Support multiple backends (differentiator from single-client remotes)
- No torrent downloading in the app itself (just URL forwarding)
- Clean, professional UI
- Privacy policy required

## Related Projects

- `~/Developer/MagnetHandler/` - Original simple version (shell script wrapper)
- `~/Code/ContextAtlas/` - Design system reference
