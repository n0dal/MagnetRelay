# Developing MagnetRelay

MagnetRelay is a menu bar app (`LSUIElement`), Swift 5.9 and SwiftUI, macOS 13+. This page is the map.

## What's where

| Path | What it is |
|---|---|
| `project.yml` | XcodeGen spec: targets, signing, entitlements, version. The `.xcodeproj` is generated from it. |
| `MagnetRelay/AppDelegate.swift` | Menu bar item, the `magnet:` URL event handler, the settings window. |
| `MagnetRelay/MagnetRelayApp.swift` | App entry point. |
| `MagnetRelay/Design/` | `Theme.swift` (the `Relay` colour and type tokens), `MagnetMark.swift` (the mark), `Controls.swift` (buttons, cards, tiles). |
| `MagnetRelay/Settings/` | The window: `SettingsRootView`, `SetupStepViews` (client, address, sign in), `ReadyView`, `RecentLinksView`, and `SetupFlowModel` (step state and the draft config). |
| `MagnetRelay/Models/ServerConfig.swift` | Saved server settings, plus the draft used by "Change server". |
| `MagnetRelay/Backends/` | One file per client behind the `RemoteClient` protocol, plus shared URL and form helpers in `HTTP.swift`. |
| `MagnetRelay/Services/` | `MagnetHandler` (send flow), `MagnetLink`, `Notifier`, `ConnectionError`, `NetworkAddress`, `KeychainService`, `LaunchAtLogin`, `RecentMagnets`. |
| `MagnetRelayTests/` | Unit tests. Backends are tested against a stubbed `URLSession`. |
| `Tests/` | `visual_tests.sh`, `screenshot.sh`, `window_capture.py`, and `mock_synology.py`. |
| `assets/` | `brand/` (source SVG), `readme/` (hero), `screenshots/`, `appstore/`. |
| `tools/render_brand.swift` | Renders the app icon, README hero and App Store screenshots. |
| `docs/superpowers/` | The redesign spec and plan. |

## Everyday commands

| Do this | Run |
|---|---|
| Generate the project (after adding or removing Swift files) | `xcodegen generate` |
| Build | `xcodebuild -project MagnetRelay.xcodeproj -scheme MagnetRelay -configuration Debug build` |
| Build without signing | add `CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO` |
| Test | `xcodebuild test -project MagnetRelay.xcodeproj -scheme MagnetRelay -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -quiet` |
| Install | `cp -r ~/Library/Developer/Xcode/DerivedData/MagnetRelay-*/Build/Products/Debug/MagnetRelay.app /Applications/` |
| Send a test link | `open "magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&dn=testfile"` |
| Fake Synology server | `python3 Tests/mock_synology.py`, then host `localhost`, port 5000, HTTPS off, user `admin`, password `password123` |
| Visual tests | `./Tests/visual_tests.sh` or `./Tests/visual_tests.sh ready` |
| Quick screenshot | `./Tests/screenshot.sh my_feature` |
| Rebuild icon and README hero | `swift tools/render_brand.swift .` |
| Rebuild App Store screenshots | `swift tools/render_brand.swift --appstore .` |

Visual tests need Screen Recording, Accessibility and Automation permission for your terminal. Run them against a signed build: an unsigned build reads a different defaults file, so the tests would not see the settings they set up. Tests: `first_launch`, `client_qbittorrent`, `client_transmission`, `client_deluge`, `client_rtorrent`, `client_synology`, `signin_deluge`, `signin_error`, `ready`, `ready_unchecked`, `ready_dark`.

## Gotchas

- **XcodeGen clears entitlements.** Keep them in `project.yml` under `entitlements.properties` (app sandbox and `com.apple.security.network.client`), or a regenerate empties the file.
- **Register the URL handler early.** It is set up in `applicationWillFinishLaunching`, not `applicationDidFinishLaunching`, or a magnet link that launches the app cold is lost.
- **No `Settings {}` scene.** In a menu bar app it opens a blank window. The settings window is created by hand with `NSHostingController`.
- **Keychain prompts while developing.** Ad-hoc signed builds ask for Keychain access after every rebuild. Release builds with a stable signature do not.
- **Signing.** `CODE_SIGN_IDENTITY` is "Apple Development". If Xcode asks for "Mac Development", regenerate and check `project.yml`.
- **Name.** The app is `MagnetRelay`, one word. `CFBundleName` must match it because `Tests/window_capture.py` finds the window by that name.
- **URL paths.** Never pass a leading slash to `URL.appendingPathComponent`; it produces a double slash. Use the helpers in `HTTP.swift`.
- **Wording.** Keep the word "torrent" out of anything the user sees, except client names (qBittorrent, rTorrent). App Review cares.

## Releasing

Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml` (the Info.plist reads them), run `xcodegen generate`, archive in Xcode and upload. Review notes: the app forwards magnet links to a remote download client and does not download any content itself.
