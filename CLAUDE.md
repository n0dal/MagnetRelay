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

- **Menu bar only:** No Dock icon (`LSUIElement: true`)
- **Settings window:** Created manually via `NSHostingController` (SwiftUI Settings scene doesn't work reliably in menu bar apps)
- **Entitlements:** Requires `com.apple.security.network.client` for API calls
- **URL path bug:** When using `URL.appendingPathComponent()`, don't include leading slash (causes double-slash)

## Testing

Test magnet handling from Terminal:
```bash
open "magnet:?xt=urn:btih:TESTHASH&dn=testfile"
```

## App Store Considerations

- Emphasize legitimate use cases (Linux ISOs, open source distribution)
- Support multiple backends (differentiator from single-client remotes)
- No torrent downloading in the app itself (just URL forwarding)
- Clean, professional UI
- Privacy policy required

## Related Projects

- `~/Developer/MagnetHandler/` - Original simple version (shell script wrapper)
- `~/Code/ContextAtlas/` - Design system reference
