# Magnet Remote

A macOS menu bar app that handles `magnet:` URLs and forwards them to remote download clients.

## Project Overview

Magnet Remote registers as the system-wide handler for `magnet:` URL scheme. When a user clicks a magnet link in any app (browser, email, etc.), macOS routes it to this app, which forwards it to the user's configured download server.

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
│   ├── RemoteClient.swift     # Protocol + BackendFactory
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
└── screenshots/               # Generated test screenshots (gitignored)
```

## Key Patterns

### URL Handling
- Registered in `Info.plist` under `CFBundleURLTypes`
- Received via `NSAppleEventManager` in `AppDelegate.applicationWillFinishLaunching`
- Must register early (willFinish, not didFinish) to catch URLs on cold launch

### Design System
- Color tokens: `Color.MR.accent`, `.surface`, `.textPrimary`, `.accentRed`, `.accentBlue`, etc.
- Typography: `Font.MR.title1`, `.body`, `.caption`, etc.
- Spacing: `MRSpacing.sm`, `.md`, `.lg`, etc.
- Components prefixed with `MR` (MRSectionCard, MRPrimaryButton, MRConnectionStatus, etc.)
- **Purple/indigo accent color palette** matching the app icon (`#6366F1` light, `#818CF8` dark)
- Secondary accents: red (`accentRed`) and blue (`accentBlue`) from magnet icon colors

### Backend Protocol
All download clients implement `RemoteClient`:
```swift
protocol RemoteClient {
    func testConnection(url: String, username: String, password: String) async throws
    func addMagnet(_ magnet: String, url: String, username: String, password: String) async throws
}
```

### Configuration
- `ServerConfig.shared` singleton with `@AppStorage` properties
- Password stored separately in Keychain via `KeychainService`
- Key properties: `clientType`, `serverHost`, `serverPort`, `useHTTPS`, `username`
- State tracking: `hasCompletedSetup`, `lastConnectedAt`, `bannerDismissed`
- `ClientType` enum has `displayName`, `shortName` (for compact UI), `icon`, `defaultPort`

### UX Patterns
- **Connection status indicator**: Shows configured state and last connection time in header
- **Password visibility toggle**: Eye icon in password field to show/hide
- **Numeric port validation**: Port field filters non-numeric input automatically
- **User-friendly errors**: `ConnectionError.userFriendlyMessage()` maps technical errors to actionable messages
- **Dismissible welcome banner**: First-time users can dismiss before completing setup
- **Cancellable connection test**: Button changes to "Cancel" during test, user can abort and retry
- **Accessibility**: All interactive elements have `.accessibilityLabel()` and `.accessibilityHint()`

### Menu Bar & Window Conventions
- **Menu bar icon**: Uses SF Symbol `link` (simple, no background)
- **Menu items**: "Settings..." opens main window, "Quit Magnet Remote" exits
- **Window title**: Just "Magnet Remote" (not "Settings" - avoids redundancy with menu item)
- **Preferences sheet**: Opened via gear icon in main window, contains Launch at Login, Notifications, About

### Placeholder Text Conventions
Use obviously fake examples to prevent user confusion:
- Host: `nas.local or IP` (not a real IP like `192.168.1.100`)
- Username: `username` (not `admin` which could be real)
- Password: `••••••••` (standard secure placeholder)

## Supported Backends

| Client | API Type | Auth Method | Status | Known Issues |
|--------|----------|-------------|--------|--------------|
| qBittorrent | REST (Web API v2) | Session Cookie | ✅ Tested | None |
| Transmission | JSON-RPC | HTTP Basic + Session ID | ✅ Tested | None - best implementation |
| Deluge | JSON-RPC | Session Cookie | ✅ Tested | Username param ignored (by design) |
| rTorrent | XML-RPC | HTTP Basic | ✅ Tested | None - good XML escaping |
| Synology | REST | Query String SID | ✅ Tested | HTTPS required for security |

### Backend Implementation Details

**qBittorrent:**
- Endpoints: `/api/v2/auth/login`, `/api/v2/torrents/add`
- Issue: If percent encoding fails, falls back to unencoded magnet (should throw error)

**Transmission:**
- Endpoint: `/transmission/rpc`
- Handles 409 response to obtain X-Transmission-Session-Id header
- Validates `result == "success"` in response

**Deluge:**
- Endpoint: `/json` (JSON-RPC)
- Method: `core.add_torrent_magnet`
- Issue: `username` parameter accepted but ignored in auth

**rTorrent:**
- Uses XML-RPC protocol
- Methods: `system.listMethods` (test), `load.start` (add)
- Properly escapes XML special characters (&, <, >)

**Synology:**
- Endpoints: `/webapi/auth.cgi`, `/webapi/DownloadStation/task.cgi`
- **SECURITY WARNING**: Sends credentials as GET query parameters
- Should only be used over HTTPS, and even then credentials appear in server logs

### Backend Issues To Fix
1. ~~**No request timeouts**~~ - ✅ Fixed: 30s timeout via BackendSession.shared
2. ~~**No retry logic**~~ - ✅ Fixed: BackendSession.withRetry() for transient failures
3. ~~**Generic error messages**~~ - ✅ Fixed: BackendError types with userFriendlyMessage helper
4. **Session caching wasted** - BackendFactory creates fresh instances each time (nice to have)

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
- **App icon in header:** Use `NSApp.applicationIconImage` to display actual app icon in SwiftUI

## Critical Gotchas

### xcodegen Clears Entitlements
When running `xcodegen generate`, the entitlements file gets emptied. To fix this permanently, include the entitlements in `project.yml`:
```yaml
entitlements:
  path: MagnetRemote/MagnetRemote.entitlements
  properties:
    com.apple.security.app-sandbox: true
    com.apple.security.network.client: true
```

### URL Handler Must Register Early
The URL event handler MUST be set up in `applicationWillFinishLaunching`, NOT `applicationDidFinishLaunching`. Otherwise, magnet links opened on cold launch won't be received.

### SwiftUI Settings Scene Creates Blank Window
Don't use `Settings { }` scene in menu bar apps - it creates a blank "Settings" window when Cmd+, is pressed. Instead, manage the settings window manually via AppDelegate using `NSHostingController`.

### Keychain Prompts Are Development-Only
During development (ad-hoc signing), macOS prompts for keychain access on each rebuild because the code signature changes. **App Store users will NOT see these prompts** - the consistent code signature means seamless keychain access.

### Team ID Is Public
The Development Team ID (e.g., `76ZSP26L92`) is NOT sensitive - it's visible in any distributed app. Safe to commit to version control.

### Apple Development vs Mac Development Certificates
Modern Apple Developer accounts use "Apple Development" certificates (universal for iOS/macOS), not the older "Mac Development" type. If Xcode complains about missing "Mac Development", specify `CODE_SIGN_IDENTITY: "Apple Development"` in project.yml or use ad-hoc signing (`-`) for local builds.

## Pre-Release Checklist

### Must Do
- [x] Add request timeouts to all backends (30s default via BackendSession.shared)
- [ ] Test each backend against a real server
- [x] Add HTTPS warning/requirement for Synology

### Should Do
- [x] Fix qBittorrent encoding fallback (now throws BackendError.encodingFailed)
- [x] Deluge username parameter (N/A - Deluge only uses password by design)
- [x] Improve error messages with more context (BackendError cases handled in userFriendlyMessage)
- [x] Add retry logic for transient network failures (via BackendSession.withRetry)

### Nice to Have
- [ ] Backend session reuse (avoid re-auth on every operation)
- [ ] Request timeout configuration in UI
- [x] Mark untested backends as "Experimental" in UI (yellow dots + warning text)
- [x] Add "Recent magnets" history in menu bar (shows last 5 with resend option)

## Testing

### Manual Testing

Test magnet handling from Terminal:
```bash
open "magnet:?xt=urn:btih:TESTHASH&dn=testfile"
```

### Mock Synology Server

For testing the Synology backend without real hardware, use the mock server:
```bash
# Terminal 1: Start mock server
python3 Tests/mock_synology.py

# Terminal 2: Configure app
# Host: localhost, Port: 5000, HTTPS: OFF
# Username: admin, Password: password123

# Send a test magnet - mock server will log receipt
open "magnet:?xt=urn:btih:TEST&dn=TestFile"
```
The mock server validates authentication and logs all received magnets.

### Visual Tests

The `Tests/` directory contains automated visual testing tools that capture screenshots of all app states with proper macOS window styling (rounded corners, shadows).

**Screenshot System:**
- `window_capture.py` - Python helper using Quartz framework for proper window capture
- `screenshot.sh` - Quick single screenshot helper
- `visual_tests.sh` - Comprehensive test suite for all app states

```bash
# Run all visual tests (captures screenshots of every app state)
./Tests/visual_tests.sh

# Run a specific test
./Tests/visual_tests.sh first_launch
./Tests/visual_tests.sh normal_settings
./Tests/visual_tests.sh client_transmission

# Quick screenshot of current state
./Tests/screenshot.sh my_feature
./Tests/screenshot.sh --reset first_launch  # Reset to first-launch state
./Tests/screenshot.sh --no-shadow clean     # Without window shadow
```

**Requires:** `pip3 install pyobjc-framework-Quartz` (auto-installed on first run)

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

**Screenshots Location:** `Tests/screenshots/` (gitignored, auto-generated)

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

**Key Principle:** Always visually verify by taking and analyzing screenshots rather than assuming the UI looks correct.

## App Store Readiness

### Completed
- [x] Privacy policy at `PRIVACY.md` (hosted on GitHub)
- [x] Removed word "torrent" from user-visible text
- [x] All backends tested (mock server for Synology)
- [x] App icon in all required sizes
- [x] Hardened runtime enabled
- [x] App sandbox with network.client entitlement
- [x] ITSAppUsesNonExemptEncryption = NO (no encryption export compliance needed)
- [x] Copyright updated to 2025
- [x] No debug print statements

### Submission Notes
- Emphasize legitimate use cases (Linux ISOs, open source distribution)
- Support multiple backends (differentiator from single-client remotes)
- No downloading in the app itself (just URL forwarding to remote servers)
- Privacy policy URL: `https://github.com/pgpillar/MagnetRemote/blob/main/PRIVACY.md`

### App Review Note
> "This app forwards magnet links to remote download clients. It does not download any content itself. Common use cases include downloading Linux distributions and open source software to a home server."

## Related Projects

- `~/Developer/MagnetHandler/` - Original simple version (shell script wrapper)
