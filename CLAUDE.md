# MagnetRelay

A macOS menu bar app that handles `magnet:` URLs and forwards them to remote download clients.

## Project Overview

MagnetRelay registers as the system-wide handler for `magnet:` URL scheme. When a user clicks a magnet link in any app (browser, email, etc.), macOS routes it to this app, which forwards it to the user's configured download server.

**Target:** macOS 13.0+ (Ventura)
**Language:** Swift 5.9, SwiftUI
**Distribution:** App Store

## Architecture

```
MagnetRelay/
├── MagnetRelayApp.swift      # App entry point, SwiftUI lifecycle
├── AppDelegate.swift          # Menu bar, URL event handling, settings window
├── Design/
│   ├── Theme.swift            # `Relay` colour/type tokens, RelayMetrics
│   ├── MagnetMark.swift       # The horseshoe-magnet mark (+ menu bar template)
│   └── Controls.swift         # Buttons, cards, tiles
├── Settings/
│   ├── SettingsRootView.swift # Switches between setup steps and Ready
│   ├── SetupStepViews.swift   # Client, Address, Sign in
│   ├── SetupFlowModel.swift   # Step state, draft config, connect/cancel
│   ├── ReadyView.swift
│   └── RecentLinksView.swift
├── Models/
│   └── ServerConfig.swift     # User configuration (AppStorage-backed), ConnectionDraft
├── Backends/
│   ├── HTTP.swift             # Form encoding, ServerEndpoint, URL joining
│   ├── RemoteClient.swift     # Protocol + BackendFactory
│   └── QBittorrent / Transmission / Deluge / RTorrent / Synology Backend.swift
├── Services/                  # MagnetHandler, MagnetLink, Notifier, ConnectionError,
│                              # NetworkAddress, KeychainService, LaunchAtLogin, RecentMagnets
├── Assets.xcassets/           # App icon (magnet mark, red poles)
├── Info.plist                 # URL scheme registration (magnet:)
└── MagnetRelay.entitlements  # Sandbox + network client

MagnetRelayTests/              # Unit tests (StubURLProtocol for backends)
assets/                        # brand/, readme/, screenshots/, appstore/
tools/render_brand.swift       # Icon, README hero, App Store screenshots (--appstore)
docs/DEVELOPMENT.md            # Human-facing repo map and commands

Tests/
├── visual_tests.sh            # Automated visual testing script (run on a signed build)
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
- Tokens live in `Color.Relay`: `background`, `card`, `ink`, `secondary`, `hairline`, `accent` (magnet red, only for the active/selected thing), `ready` (green, only the connected dot and on-switches). Type in `Font.Relay`, sizes in `RelayMetrics`.
- Native macOS controls first; cards are 10pt continuous radius with a 0.5pt hairline, no shadows. No springs or scale-on-press; respect Reduce Motion.
- The mark (`MagnetMark`): dark tile, white horseshoe magnet, red pole tips. Source SVG: `assets/brand/magnetrelay-mark.svg`.

### Backend Protocol
All download clients implement `RemoteClient`:
```swift
protocol RemoteClient {
    func testConnection(_ endpoint: ServerEndpoint) async throws
    func addMagnet(_ magnet: String, to endpoint: ServerEndpoint) async throws
}
```

### Configuration
- `ServerConfig.shared` singleton with `@AppStorage` properties
- Password stored separately in Keychain via `KeychainService`
- Key properties: `clientType`, `serverHost`, `serverPort`, `serverPath`, `useHTTPS`, `username`
- State tracking: `hasCompletedSetup`, `lastConnectedAt`
- `ClientType` enum has `displayName` and `defaultPort`

### UX Patterns
- Three-step setup (Client, Address, Sign in) then a Ready screen; Change server edits a draft until Connect succeeds
- Password visibility toggle (eye icon)
- Numeric port validation
- User-friendly error messages via `ConnectionError.userFriendlyMessage()`
- Cancellable connection test
- Accessibility labels on all interactive elements

### Menu Bar & Window Conventions
- Menu bar icon: template magnet (`MagnetMark`), monochrome
- Menu items: recent links, "Settings..." and "Quit MagnetRelay"
- Settings window: a borderless panel (`SettingsPanel`), no title bar or window buttons, 16pt continuous corners, a quiet "esc" hint top-right. Esc or ⌘W closes it (Esc first dismisses the Recent links popover if it is open); clicking away closes it only on the Ready screen, never mid-setup. Its accessibility title is "MagnetRelay".
- Open at login and notification switches live on the Ready screen

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

Raw captures in `Tests/screenshots/` (from these tests or the screenshot harness) are the panel alone with no shadow, transparent outside the rounded corners; they feed `tools/render_brand.swift`. The committed README screenshots in `assets/screenshots/` do have a soft shadow on a transparent canvas. Details, plus the hero, social card and App Store images: `docs/DEVELOPMENT.md`.

Available tests: `first_launch`, `client_qbittorrent`, `client_transmission`, `client_deluge`, `client_rtorrent`, `client_synology`, `signin_deluge`, `signin_error`, `ready`, `ready_unchecked`, `ready_dark`

## Important Notes

- **Bundle ID:** `com.magnetrelay.app`
- **Menu bar only:** No Dock icon (`LSUIElement: true`)
- **Settings window:** A `SettingsPanel` created manually with an `NSHostingController` (SwiftUI Settings scene doesn't work reliably in menu bar apps)
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

## Identity

- GitHub account: `n0dal` (the account was renamed; old links redirect). Repo: github.com/n0dal/MagnetRelay.
- Commit as Henry Cuevas, `81403084+n0dal@users.noreply.github.com`.
- No Co-Authored-By trailers on commits.

## App Store Notes

- No "torrent" in user-visible text (App Store compliance)
- Privacy policy required and hosted
- Emphasize legitimate use cases (Linux ISOs, open source) in submission
- App Review note: "This app forwards magnet links to remote download clients. It does not download any content itself."
