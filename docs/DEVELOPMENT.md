# Developing MagnetRelay

MagnetRelay is a menu bar app (`LSUIElement`), Swift 5.9 and SwiftUI, macOS 13+. This page is the map.

## What's where

| Path | What it is |
|---|---|
| `project.yml` | XcodeGen spec: targets, signing, entitlements, version. The `.xcodeproj` is generated from it. |
| `MagnetRelay/AppDelegate.swift` | Menu bar item, the `magnet:` URL event handler, the settings window. |
| `MagnetRelay/MagnetRelayApp.swift` | App entry point. |
| `MagnetRelay/Design/` | `Theme.swift` (the `Relay` colour and type tokens), `MagnetMark.swift` (the mark), `Controls.swift` (buttons, cards, tiles). |
| `MagnetRelay/Settings/` | The window: `SettingsPanel` (borderless panel; Esc, ⌘W, or clicking away on Ready closes it), `SettingsRootView`, `SetupStepViews` (client, address, sign in), `ReadyView`, `RecentLinksView`, and `SetupFlowModel` (step state and the draft config). |
| `MagnetRelay/Models/ServerConfig.swift` | Saved server settings, plus the draft used by "Change server". |
| `MagnetRelay/Backends/` | One file per client behind the `RemoteClient` protocol, plus shared URL and form helpers in `HTTP.swift`. |
| `MagnetRelay/Services/` | `MagnetHandler` (send flow), `MagnetLink`, `Notifier`, `ConnectionError`, `NetworkAddress`, `KeychainService`, `LaunchAtLogin`, `RecentMagnets`. |
| `MagnetRelayTests/` | Unit tests. Backends are tested against a stubbed `URLSession`. |
| `Tests/` | `visual_tests.sh`, `screenshot.sh`, `window_capture.py`, and `mock_synology.py`. |
| `assets/` | `brand/` (source SVG), `readme/` (hero), `screenshots/` (README), `social/` (GitHub social card), `appstore/`. |
| `tools/render_brand.swift` | Renders the app icon, README hero, social card and App Store screenshots. |
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
| Rebuild icon, README hero and social card | `swift tools/render_brand.swift .` |
| Rebuild App Store screenshots | `swift tools/render_brand.swift --appstore .` |

Visual tests need Screen Recording, Accessibility and Automation permission for your terminal. Run them against a signed build: an unsigned build reads a different defaults file, so the tests would not see the settings they set up. Tests: `first_launch`, `client_qbittorrent`, `client_transmission`, `client_deluge`, `client_rtorrent`, `client_synology`, `signin_deluge`, `signin_error`, `ready`, `ready_unchecked`, `ready_dark`.

## Screenshots and brand art

Every picture shows the settings panel alone: no title bar, no window buttons, 16pt continuous corners.

- **Raw captures.** `Tests/visual_tests.sh` writes them to `Tests/screenshots/` (gitignored) without the system shadow, so the area outside the corners is transparent. `ready.png` and `ready_dark.png` feed `tools/render_brand.swift`, which draws the panel shape, one soft shadow and a hairline itself.
- **README screenshots** (`assets/screenshots/`): `client`, `address`, `signin`, `ready`, `ready-dark` and `recent-links` (Ready with the Recent links popover open). They are 2x, the panel on a transparent canvas with a 28pt margin and one soft shadow. Use real-looking values (address `192.168.0.100`, port `8080`, user `admin`, a filled password) so Continue and Connect show enabled, the current version in the footer (the capture needs an Info.plist for it to show), and open-source names (Linux ISOs, Blender films) in Recent links.
- **Hero** (`assets/readme/hero-*.png`, 1600×560), **social card** (`assets/social/social-preview.png`, 1280×640) and **App Store** images come from `swift tools/render_brand.swift`. The social card is uploaded by hand under the repo's Settings → Social preview.
- **App icon.** `render_brand.swift` also writes the icon PNGs; they should come out byte-identical unless the mark changes. Check with `git status` after a render.

## Gotchas

- **XcodeGen clears entitlements.** Keep them in `project.yml` under `entitlements.properties` (app sandbox and `com.apple.security.network.client`), or a regenerate empties the file.
- **Register the URL handler early.** It is set up in `applicationWillFinishLaunching`, not `applicationDidFinishLaunching`, or a magnet link that launches the app cold is lost.
- **No `Settings {}` scene.** In a menu bar app it opens a blank window. The settings window is a `SettingsPanel` created by hand with `NSHostingController`.
- **The panel closes on click-away, on Ready only.** Anything that makes MagnetRelay inactive while Ready is showing (a browser opening the Privacy Policy, a visual test activating another app) closes it. Esc closes it too, except while the Recent links popover is open: then Esc closes the popover first.
- **Keychain prompts while developing.** Ad-hoc signed builds ask for Keychain access after every rebuild. Release builds with a stable signature do not.
- **Signing.** `CODE_SIGN_IDENTITY` is "Apple Development". If Xcode asks for "Mac Development", regenerate and check `project.yml`.
- **Name.** The app is `MagnetRelay`, one word. `CFBundleName` must match it because `Tests/window_capture.py` finds the window by that name.
- **URL paths.** Never pass a leading slash to `URL.appendingPathComponent`; it produces a double slash. Use the helpers in `HTTP.swift`.
- **Wording.** Keep the word "torrent" out of anything the user sees, except client names (qBittorrent, rTorrent). App Review cares.

## Releasing

Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml` (the Info.plist reads them), run `xcodegen generate`, archive in Xcode and upload. Review notes: the app forwards magnet links to a remote download client and does not download any content itself.
