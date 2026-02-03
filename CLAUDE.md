# MagnetRelay

A macOS menu bar app that handles `magnet:` URLs and forwards them to remote download clients.

## Project Overview

MagnetRelay registers as the system-wide handler for `magnet:` URL scheme. When a user clicks a magnet link in any app (browser, email, etc.), macOS routes it to this app, which forwards it to the user's configured download server.

**Target:** macOS 13.0+ (Sonoma)
**Language:** Swift 5.9, SwiftUI
**Distribution:** App Store

## Architecture

```
MagnetRelay/
├── MagnetRelayApp.swift      # App entry point, SwiftUI lifecycle
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
└── MagnetRelay.entitlements  # Sandbox + network client

Tests/
├── visual_tests.sh            # Automated visual testing script
├── screenshot.sh              # Quick screenshot helper
├── window_capture.py          # Python/Quartz helper for window screenshots
├── mock_synology.py           # Mock Synology server for testing
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
- Purple/indigo accent color palette (`#6366F1` light, `#818CF8` dark)

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
- `ClientType` enum has `displayName`, `shortName`, `icon`, `defaultPort`

### UX Patterns
- Connection status indicator in header
- Password visibility toggle (eye icon)
- Numeric port validation
- User-friendly error messages via `ConnectionError.userFriendlyMessage()`
- Dismissible welcome banner for first-time users
- Cancellable connection test
- Accessibility labels on all interactive elements

### Menu Bar & Window Conventions
- Menu bar icon: SF Symbol `link`
- Menu items: "Settings..." and "Quit MagnetRelay"
- Window title: "MagnetRelay"
- Preferences sheet via gear icon (Launch at Login, Notifications, About)

## Supported Backends

| Client | API Type | Auth Method | Notes |
|--------|----------|-------------|-------|
| qBittorrent | REST (Web API v2) | Session Cookie | |
| Transmission | JSON-RPC | HTTP Basic + Session ID | |
| Deluge | JSON-RPC | Session Cookie | Username ignored (by design) |
| rTorrent | XML-RPC | HTTP Basic | |
| Synology | REST | Query String SID | HTTPS required |

## Build & Run

```bash
# Generate Xcode project (after adding new files)
xcodegen generate

# Build
xcodebuild -project MagnetRelay.xcodeproj -scheme MagnetRelay -configuration Debug build

# Install to /Applications
cp -r ~/Library/Developer/Xcode/DerivedData/MagnetRelay-*/Build/Products/Debug/MagnetRelay.app /Applications/

# Run
open /Applications/MagnetRelay.app
```

## Testing

### Manual Testing
```bash
open "magnet:?xt=urn:btih:TESTHASH&dn=testfile"
```

### Mock Synology Server
```bash
# Terminal 1: Start mock server
python3 Tests/mock_synology.py

# Terminal 2: Configure app (Host: localhost, Port: 5000, HTTPS: OFF)
# Username: admin, Password: password123
open "magnet:?xt=urn:btih:TEST&dn=TestFile"
```

### Visual Tests
```bash
# Run all visual tests
./Tests/visual_tests.sh

# Run specific test
./Tests/visual_tests.sh first_launch

# Quick screenshot of current state
./Tests/screenshot.sh my_feature
```

Available tests: `first_launch`, `normal_settings`, `client_qbittorrent`, `client_transmission`, `client_deluge`, `client_rtorrent`, `client_synology`, `https_enabled`, `empty_config`

## Important Notes

- **Bundle ID:** `com.magnetrelay.app`
- **Menu bar only:** No Dock icon (`LSUIElement: true`)
- **Settings window:** Created manually via `NSHostingController` (SwiftUI Settings scene doesn't work reliably in menu bar apps)
- **Entitlements:** Requires `com.apple.security.network.client` for API calls
- **URL path bug:** Don't include leading slash with `URL.appendingPathComponent()` (causes double-slash)

## Critical Gotchas

### xcodegen Clears Entitlements
Include entitlements in `project.yml` to prevent this:
```yaml
entitlements:
  path: MagnetRelay/MagnetRelay.entitlements
  properties:
    com.apple.security.app-sandbox: true
    com.apple.security.network.client: true
```

### URL Handler Must Register Early
Set up the URL event handler in `applicationWillFinishLaunching`, NOT `applicationDidFinishLaunching`. Otherwise, magnet links on cold launch won't be received.

### SwiftUI Settings Scene Creates Blank Window
Don't use `Settings { }` scene in menu bar apps - it creates a blank window on Cmd+,. Manage the settings window manually via AppDelegate using `NSHostingController`.

### Keychain Prompts Are Development-Only
During development (ad-hoc signing), macOS prompts for keychain access on each rebuild. App Store users won't see these prompts due to consistent code signing.

### Apple Development vs Mac Development Certificates
Modern Apple Developer accounts use "Apple Development" certificates (universal for iOS/macOS). If Xcode complains about missing "Mac Development", specify `CODE_SIGN_IDENTITY: "Apple Development"` in project.yml.

### Naming Convention: MagnetRelay (One Word)
The app name is **MagnetRelay** (no space). `CFBundleName` and `CFBundleDisplayName` in Info.plist must match.

### Window Owner Name Matches CFBundleName
The Quartz window owner name (used by `Tests/window_capture.py`) is determined by `CFBundleName`. If you change the display name, update `Tests/window_capture.py` to match.

## App Store Notes

- No "torrent" in user-visible text (App Store compliance)
- Privacy policy required and hosted
- Emphasize legitimate use cases (Linux ISOs, open source) in submission
- App Review note: "This app forwards magnet links to remote download clients. It does not download any content itself."
