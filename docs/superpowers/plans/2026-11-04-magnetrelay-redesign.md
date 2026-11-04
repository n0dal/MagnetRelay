# MagnetRelay Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild MagnetRelay's settings window as a native, guided three-step setup with a "Ready" screen and a new magnet mark. Fix the backend and handler bugs from the review, bring the repo docs up to the Inkroot standard, and move the repo and its history from `pgpillar` to `n0dal` with no Claude co-author trailers.

**Architecture:** Backends move to a single `ServerEndpoint` value (base URL including an optional path, plus credentials) and an injectable `URLSession`, so every request shape can be unit-tested with a stub `URLProtocol`. The settings UI becomes `SettingsRootView`, which switches between `SetupFlowView` (driven by a testable `SetupFlowModel` that edits a `ConnectionDraft`) and `ReadyView`. The new design tokens live in a new `Relay` namespace; the old `MR` design system and components are deleted once the new UI replaces them.

**Tech Stack:** Swift 5.9, SwiftUI + AppKit, macOS 13+, xcodegen, XCTest, `git filter-repo`.

**Spec:** `docs/superpowers/specs/2026-11-04-magnetrelay-redesign-design.md`. Read it first. Section numbers below (§) refer to it. Approved mockup: `docs/superpowers/specs/assets/2026-11-04-guided-flow.html`.

## Global Constraints

- macOS deployment target 13.0; Swift 5.9; App Sandbox + `com.apple.security.network.client`. Keep both in `project.yml` `entitlements.properties`.
- `DEVELOPMENT_TEAM: "CY37XHX499"` in `project.yml` (owner decision).
- Run `xcodegen generate` after adding or removing any Swift file.
- Build/test unsigned: append `CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO` to `xcodebuild`.
- Test command (referred to below as **`$TEST`**): `xcodebuild test -project MagnetRelay.xcodeproj -scheme MagnetRelay -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -quiet`.
- No user-visible "torrent" text except client product names (qBittorrent, rTorrent).
- Never pass a leading slash to `URL.appendingPathComponent`.
- The URL event handler stays registered in `applicationWillFinishLaunching`. No `Settings {}` scene.
- `CFBundleName` stays `MagnetRelay` (`Tests/window_capture.py` depends on it).
- Palette (§3), copied exactly:
  - `background` `#F6F5F3` / dark `#1C1C1E`
  - `card` `#FFFFFF` / `#2C2C2E`
  - `ink` `#1D1D1F` / `#F5F5F7`
  - `secondary` `#6E6E73` / `#98989D`
  - `hairline` black 9% / white 10%
  - `accent` `#E5484D` / `#FF6369`
  - `ready` `#2DA44E` / `#3FB950`
- Cards: 10pt continuous radius, 0.5pt hairline, no shadows. Heading 22pt semibold, tracking −0.02em. Body 13pt. No springs and no scale-on-press. Respect Reduce Motion.
- **Commits:** author email `81403084+n0dal@users.noreply.github.com`, name "Henry Cuevas". **No `Co-Authored-By` trailer on any commit.** This overrides any default attribution instruction.
- All work happens on branch `redesign`. Merge to `main` only in Task 13.

## Review Focus

1. **Magnets with many trackers or non-ASCII `dn=` values** (`&`, `+`, `%`, emoji) reach every client intact, nothing truncated and nothing double-encoded. Tests: Task 3, `testAddMagnetPreservesAllParameters` for each backend.
2. **Host typed with a scheme, trailing slash or port** (`http://nas.local:8080/`) still builds a correct URL rather than `http://http://…`. Test: Task 2, `testHostNormalisation`.
3. **Path with or without slashes** (`RPC2`, `/RPC2`, `/qbt/`) joins without `//`. Test: Task 2, `testPathJoining`.
4. **A magnet arrives while the window is mid-"Change server"**: it goes to the old, working config. Test: Task 8, `testChangeServerDoesNotTouchLiveConfigUntilConnect`.
5. **Server unreachable at the moment a magnet is clicked, with "Notify when sent" switched off**: the user still gets a failure notification. Test: Task 5, `testFailureNotifiesEvenWhenSuccessNotificationsOff`.

---

## File Map

| File | Responsibility | Task |
|---|---|---|
| `project.yml` | team, test target `MagnetRelayTests` | 1 |
| `MagnetRelayTests/StubURLProtocol.swift` | records requests, returns canned responses | 1 |
| `MagnetRelay/Backends/HTTP.swift` | `FormEncoding`, `ServerEndpoint`, URL joining | 2 |
| `MagnetRelay/Models/ServerConfig.swift` | adds `serverPath`, `ConnectionDraft`, `endpoint(password:)`; removes `serverURL`, `launchAtLogin`, `bannerDismissed`, experimental flags | 2 |
| `MagnetRelay/Backends/*.swift` | new protocol signature, injected session, fixes | 3 |
| `MagnetRelay/Services/NetworkAddress.swift` | `isLocal(host:)` | 3 |
| `MagnetRelay/Services/ConnectionError.swift` | error → sentence mapping (moved out of `Components.swift`) | 4 |
| `MagnetRelay/Services/MagnetLink.swift` | `isMagnet`, `displayName` | 5 |
| `MagnetRelay/Services/MagnetHandler.swift`, `RecentMagnets.swift`, `Notifier.swift` | send flow, notifications | 5 |
| `MagnetRelay/Services/LaunchAtLogin.swift`, `KeychainService.swift` | real status, checked writes | 6 |
| `MagnetRelay/Design/Theme.swift`, `MagnetMark.swift`, `Controls.swift` | new `Relay` design system + mark | 7 |
| `MagnetRelay/Settings/SetupFlowModel.swift` | step state, draft, connect/cancel | 8 |
| `MagnetRelay/Settings/SettingsRootView.swift`, `SetupStepViews.swift`, `ReadyView.swift`, `RecentLinksView.swift` | UI | 9 |
| delete `SettingsView.swift`, `DesignSystem.swift`, `Components.swift` | | 9 |
| `tools/render_brand.swift`, `assets/brand/*`, `AppIcon.appiconset/*` | icon + README hero | 10 |
| `Tests/visual_tests.sh`, `assets/screenshots/*` | new screens | 11 |
| `README.md`, `docs/DEVELOPMENT.md`, `PRIVACY.md`, `LICENSE`, `CLAUDE.md` | docs | 12 |
| git history | rewrite + force-push | 13 |

---

### Task 1: Branch, identity, team, unit-test target

**Files:**
- Modify: `project.yml`, `.gitignore`
- Create: `MagnetRelayTests/StubURLProtocol.swift`, `MagnetRelayTests/SmokeTests.swift`

**Interfaces:**
- Produces:
  - `final class StubURLProtocol: URLProtocol` with `static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?`, `static private(set) var requests: [URLRequest]`, `static func reset()`, and `static func session() -> URLSession`, which returns an ephemeral session whose `protocolClasses = [StubURLProtocol.self]`.
  - Recorded requests must keep their body: copy `httpBodyStream` into `httpBody` when recording.
  - Helper `extension URLRequest { var bodyString: String }`.

- [ ] **Step 1:** Run `git checkout -b redesign`, then `git config user.email 81403084+n0dal@users.noreply.github.com`, then `git remote set-url origin https://github.com/n0dal/MagnetRelay.git`.
- [ ] **Step 2:** In `project.yml`, set `DEVELOPMENT_TEAM: "CY37XHX499"`. Add a target `MagnetRelayTests` (`type: bundle.unit-test`, `platform: macOS`, `sources: [MagnetRelayTests]`, `dependencies: [{target: MagnetRelay}]`, `settings: {TEST_HOST: "$(BUILT_PRODUCTS_DIR)/MagnetRelay.app/Contents/MacOS/MagnetRelay", BUNDLE_LOADER: "$(TEST_HOST)"}`). Add a `schemes.MagnetRelay` entry with `build.targets` and `test.targets: [MagnetRelayTests]`. Add `.superpowers/` to `.gitignore`.
- [ ] **Step 3:** Write `StubURLProtocol.swift`, plus `SmokeTests.testStubRecordsBody`: POST `"a=1"` through `StubURLProtocol.session()` and assert `StubURLProtocol.requests.first?.bodyString == "a=1"`.
- [ ] **Step 4:** Run `xcodegen generate && $TEST`. Expected: `** TEST SUCCEEDED **` with one test.
- [ ] **Step 5:** Commit `project.yml .gitignore MagnetRelayTests MagnetRelay.xcodeproj` with the message "Add unit-test target and set development team".

### Task 2: Endpoint, URL joining, form encoding, config model

**Files:**
- Create: `MagnetRelay/Backends/HTTP.swift`
- Modify: `MagnetRelay/Models/ServerConfig.swift`
- Test: `MagnetRelayTests/HTTPTests.swift`

**Interfaces:**
- Produces:
  - `struct ServerEndpoint: Equatable { let baseURL: URL; let username: String; let password: String; func url(_ components: String...) -> URL }`. `url("api","v2","auth","login")` joins segments onto `baseURL`, including its path, with single slashes.
  - `enum FormEncoding { static func encode(_ pairs: [(String, String)]) -> String }`. Uses `application/x-www-form-urlencoded` rules: unreserved characters `A-Z a-z 0-9 - . _ ~` are kept, and everything else is percent-encoded, including `&` `=` `+` `?` `:` `/` and space as `%20`.
  - `struct ConnectionDraft: Equatable { var clientType: ClientType; var host: String; var port: String; var useHTTPS: Bool; var path: String; var username: String; var password: String; func endpoint() -> ServerEndpoint? }`. `endpoint()` returns `nil` if the normalised host is empty or the URL is invalid.
  - `protocol PasswordStoring: AnyObject { func password() -> String?; @discardableResult func setPassword(_ p: String) -> Bool }`. `final class KeychainPasswordStore: PasswordStoring` wraps `KeychainService`. Tests use an in-memory fake.
  - `ServerConfig.init(store: UserDefaults = .standard, passwords: PasswordStoring = KeychainPasswordStore())` is internal, not private. Each `@AppStorage` is initialised in `init` with `store:`, so tests can pass `UserDefaults(suiteName: "MagnetRelayTests-\(UUID())")` and never touch the developer's real settings or Keychain. `static let shared = ServerConfig()`.
  - `@AppStorage` inside an `ObservableObject` doesn't publish changes, so `ServerConfig` subscribes to `UserDefaults.didChangeNotification` for its store and calls `objectWillChange.send()` on the main queue.
  - `ClientType.defaultPort` becomes `func defaultPort(https: Bool) -> String`. Synology returns `5001` with HTTPS and `5000` without; every other client ignores the flag.
  - `ServerConfig` gains `@AppStorage("serverPath") var serverPath: String = ""`, `func draft() -> ConnectionDraft` (password from `passwords`), `func apply(_ draft: ConnectionDraft)` (writes the fields and calls `passwords.setPassword`), `var isConfigured: Bool { !serverHost.trimmed.isEmpty }`, and `func endpoint() -> ServerEndpoint?`.
  - `currentConfigHash` now includes `serverPath`.
  - Remove `serverURL`, `launchAtLogin`, `bannerDismissed`, `isExperimental`, `experimentalWarning` and `icon`.
  - `shortName` stays for now; Task 9 removes it if unused.
  - Host normalisation in `endpoint()`: trim whitespace; if the host contains `://`, take scheme, host, port and path from it, so a pasted URL wins over the separate fields; strip any trailing `/`.
- Consumes: nothing.

- [ ] **Step 1: Write failing tests** in `HTTPTests`:
  - `testFormEncodingEscapesReserved`: `FormEncoding.encode([("urls","magnet:?xt=urn:btih:AB&dn=a b+c&tr=udp://t:1/x")])` equals `"urls=magnet%3A%3Fxt%3Durn%3Abtih%3AAB%26dn%3Da%20b%2Bc%26tr%3Dudp%3A%2F%2Ft%3A1%2Fx"`.
  - `testFormEncodingPassword`: `encode([("username","me"),("password","p&s=+w")])` equals `"username=me&password=p%26s%3D%2Bw"`.
  - `testPathJoining`: for each `path` in `["RPC2","/RPC2","/RPC2/"]`, a draft with host `nas` and port `8080` gives `endpoint()!.url().absoluteString == "http://nas:8080/RPC2"`. A path of `/qbt/` with `url("api","v2")` gives `"http://nas:8080/qbt/api/v2"`. An empty path with `url("json")` gives `"http://nas:8080/json"`.
  - `testHostNormalisation`: host `" http://nas.local:9091/ "`, port `"8080"`, `useHTTPS` false gives `"http://nas.local:9091"`. Host `"https://box"` with port `5001` gives `"https://box:5001"`. Host `""` gives `nil`.
  - `testHTTPSFlag`: host `nas`, `useHTTPS` true, port `5001` gives `"https://nas:5001"`.
  - `testConfigApplyRoundTrip`: using a temporary suite and a fake password store, `apply(draft)` then `draft()` returns an equal draft, and the fake received the password.
- [ ] **Step 2:** Run `$TEST`. Expected: compile FAIL (`ServerEndpoint` undefined).
- [ ] **Step 3:** Implement `HTTP.swift` and the `ServerConfig` changes. Build URLs with `URLComponents` and join path segments from split, non-empty pieces.
- [ ] **Step 4:** Do not fix the old callers of `serverURL` here (`SettingsView`, `MagnetHandler`). Add a temporary `var serverURL: String { endpoint()?.baseURL.absoluteString ?? "" }` marked `// TEMP: removed in Task 3`. Run `$TEST`. Expected: PASS.
- [ ] **Step 5:** Commit with the message "Add ServerEndpoint, form encoding and optional server path".

### Task 3: Backends on `ServerEndpoint`, with request-shape tests and fixes

**Files:**
- Modify: `MagnetRelay/Backends/RemoteClient.swift`, `QBittorrentBackend.swift`, `TransmissionBackend.swift`, `DelugeBackend.swift`, `RTorrentBackend.swift`, `SynologyBackend.swift`, `MagnetRelay/Services/MagnetHandler.swift` (call site only), `MagnetRelay/SettingsView.swift` (call site only)
- Create: `MagnetRelay/Services/NetworkAddress.swift`
- Test: `MagnetRelayTests/BackendTests.swift`, `MagnetRelayTests/NetworkAddressTests.swift`

**Interfaces:**
- Consumes: `ServerEndpoint`, `FormEncoding`, `StubURLProtocol`.
- Produces:
  - `protocol RemoteClient { func testConnection(_ endpoint: ServerEndpoint) async throws; func addMagnet(_ magnet: String, to endpoint: ServerEndpoint) async throws }`
  - Every backend has `init(session: URLSession = BackendSession.shared)`.
  - `BackendFactory.create(for: ClientType, session: URLSession = BackendSession.shared) -> RemoteClient`.
  - `RRemoteClient` is renamed `RTorrentBackend`.
  - `BackendError` gains `case daemonNotConnected` (Deluge) and `case httpStatus(Int)`. `insecureConnection` takes no payload. `connectionFailed`/`serverError` keep a `String`.
  - `enum NetworkAddress { static func isLocal(host: String) -> Bool }`. True for `localhost`, `*.local`, `127.0.0.0/8`, `10/8`, `172.16/12`, `192.168/16`, `169.254/16`, `::1` and `fe80::/10`.
  - Remove the TEMP `serverURL` from Task 2. Callers use `config.endpoint()`, or a draft endpoint for the settings test.

- [ ] **Step 1: Write failing tests.** All of them use `StubURLProtocol.session()`, a canned handler per URL path, and the magnet `M = "magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&dn=Ubuntu%2024.04&tr=udp%3A%2F%2Ft.example%3A1337"`.
  - `testQBittorrentLoginAndAdd`:
    - login gets `POST …/api/v2/auth/login` with body `username=admin&password=p%26w` when the password is `p&w`;
    - the canned login response is `"Ok."` with `Set-Cookie: SID=abc; path=/`;
    - add gets `POST …/api/v2/torrents/add` with `Cookie: SID=abc`;
    - the add body is `FormEncoding.encode([("urls", M)])`.
  - `testQBittorrentBadLoginThrowsAuth`: a `"Fails."` response throws `BackendError.authenticationFailed`.
  - `testTransmissionSessionHandshake`:
    - the first POST to `…/transmission/rpc` gets 409 with `X-Transmission-Session-Id: s1`;
    - the add request carries `X-Transmission-Session-Id: s1`;
    - its JSON `arguments.filename == M`.
  - `testTransmission401ThrowsAuth`.
  - `testDelugeConnectsDaemonWhenNeeded`:
    - `auth.login` returns `true`;
    - `web.connected` returns `false`;
    - `web.get_hosts` returns `[["h1","127.0.0.1",58846,"Online"]]`;
    - the methods called, in order, are `auth.login`, `web.connected`, `web.get_hosts`, `web.connect("h1")`, `core.add_torrent_magnet(M, {})`.
  - `testDelugeNoHostsThrowsDaemonNotConnected`.
  - `testRTorrentFaultThrows`: a 200 response with body `<methodResponse><fault>…</fault></methodResponse>` throws `serverError`.
  - `testRTorrentPostsToPath`: a draft path `/RPC2` sends the request to `http://nas:8080/RPC2`, and the XML contains `M` with `&` escaped as `&amp;`.
  - `testSynologyRejectsHTTPForPublicHost`: host `example.com` over http throws `insecureConnection` without making any request.
  - `testSynologyAllowsHTTPOnLAN`: host `192.168.1.5` over http makes the `auth.cgi` request.
  - `testAddMagnetPreservesAllParameters`: for every `ClientType`, the payload the server receives contains `M` exactly once, decoded back to the original. This is Review Focus 1. Also run a variant with `dn=Caf%C3%A9%20%F0%9F%8E%B5`.
  - `NetworkAddressTests.testLocal`:
    - true for `localhost`, `NAS.local`, `10.0.0.2`, `172.20.1.1`, `192.168.0.100`, `127.0.0.1`;
    - false for `172.32.0.1`, `8.8.8.8`, `example.com`, `nas.example.com`.
- [ ] **Step 2:** Run `$TEST`. Expected: compile FAIL.
- [ ] **Step 3:** Implement. Every URL comes from `endpoint.url(...)`. Remove all `appendingPathComponent("/…")` calls. Basic auth uses a shared helper `URLRequest.setBasicAuth(username:password:)` in `HTTP.swift`. For rTorrent, a body containing `<fault>` throws `serverError` with the fault string. Synology `validateSecureConnection` uses `NetworkAddress.isLocal`.
- [ ] **Step 4:** Run `$TEST`. Expected: PASS.
- [ ] **Step 5:** Commit with the message "Backends: shared endpoint, correct form encoding, Deluge daemon connect, rTorrent faults, LAN-aware Synology HTTPS".

### Task 4: Error messages as full sentences

**Files:**
- Create: `MagnetRelay/Services/ConnectionError.swift` (move the enum out of `Components.swift` and rewrite it)
- Test: `MagnetRelayTests/ConnectionErrorTests.swift`

**Interfaces:**
- Produces: `enum ConnectionError { static func message(for error: Error, client: ClientType) -> String }`. The old `userFriendlyMessage(from:)` is deleted and callers move to the new function. Matching is on `URLError.Code`, `BackendError` and `BackendError.httpStatus`, never on `localizedDescription`.

- [ ] **Step 1: Write failing tests.** Each asserts the exact string. `{c}` is `client.displayName`.

| Input | Expected |
|---|---|
| `URLError(.cannotConnectToHost)` | `"Couldn't reach {c}. Check the address and port, and that it's running."` |
| `URLError(.cannotFindHost)` | `"Couldn't find that address. Check it for typos."` |
| `URLError(.timedOut)` | `"{c} didn't answer in time. Check that it's running and reachable from this Mac."` |
| `URLError(.serverCertificateUntrusted)` (also `.serverCertificateHasUnknownRoot`, `.secureConnectionFailed`) | `"The server's certificate isn't trusted by this Mac. Use a trusted certificate, or HTTPS may not be set up on this port."` |
| `URLError(.notConnectedToInternet)` | `"This Mac isn't connected to a network."` |
| `BackendError.authenticationFailed` | `"{c} said the username or password is wrong. Check them on its web page and try again."` |
| `BackendError.insecureConnection` | `"Synology needs HTTPS for addresses outside your home network."` |
| `BackendError.daemonNotConnected` | `"Deluge's web page isn't connected to Deluge. Open it in a browser and connect to a host first."` |
| `BackendError.httpStatus(404)` | `"{c} isn't at that address. Check the port and path."` |
| `BackendError.httpStatus(403)` | `"{c} refused the connection. Check its web UI security settings."` |
| `BackendError.serverError("x")` | `"{c} couldn't add the link: x"` |
| any other error `e` | `"Something went wrong: \(e.localizedDescription)"` |

There is no truncation.
- [ ] **Step 2:** Run `$TEST`. Expected: FAIL.
- [ ] **Step 3:** Implement the mapping. Backends throw `httpStatus` for unexpected non-2xx codes instead of generic strings.
- [ ] **Step 4:** Run `$TEST`. Expected: PASS.
- [ ] **Step 5:** Commit with the message "Map connection errors by code to plain sentences".

### Task 5: Magnet links, send flow, notifications

**Files:**
- Create: `MagnetRelay/Services/MagnetLink.swift`, `MagnetRelay/Services/Notifier.swift`
- Modify: `MagnetRelay/Services/MagnetHandler.swift`, `RecentMagnets.swift`, `MagnetRelay/AppDelegate.swift`
- Test: `MagnetRelayTests/MagnetLinkTests.swift`, `MagnetRelayTests/MagnetHandlerTests.swift`

**Interfaces:**
- Produces:
  - `enum MagnetLink { static func isMagnet(_ s: String) -> Bool; static func displayName(from s: String, maxLength: Int = 45) -> String }`. `isMagnet` is true when the scheme is `magnet` (case-insensitive) and an `xt=` parameter is present. `displayName` parses with `URLComponents`. It prefers `dn` (decoded, `+` becomes space), falls back to the first 8 characters of the btih hash plus `…`, and otherwise returns `"Unknown link"`. It truncates to `maxLength` with `…`.
  - `protocol Notifying { func post(title: String, body: String) async }`. `final class Notifier: NSObject, Notifying, UNUserNotificationCenterDelegate` is set as the centre's delegate in `AppDelegate.applicationDidFinishLaunching` and presents `.banner, .sound` while in the foreground.
  - `MagnetHandler.init(config: ServerConfig = .shared, recent: RecentMagnets = .shared, notifier: Notifying, clientFactory: (ClientType) -> RemoteClient = { BackendFactory.create(for: $0) }, openSettings: @escaping () -> Void)`.
  - `MagnetHandler.handleMagnet(_:) async`:
    - not a magnet: ignored;
    - not configured: posts `("MagnetRelay", "Set up MagnetRelay to start sending links.")` and calls `openSettings()`;
    - success: adds to recent, and posts `("Sent to {client}", displayName)` only if `showNotifications`;
    - failure: always posts `("Couldn't send link", ConnectionError.message(...))`.
  - `RecentMagnets` exposes `init(defaults: UserDefaults)` for tests; `shared` uses `.standard`. Its item `displayName` comes from `MagnetLink`.
- [ ] **Step 1: Write failing tests.**
  - `MagnetLinkTests`:
    - `isMagnet("MAGNET:?xt=urn:btih:AB")` is true;
    - `isMagnet("https://x")` is false;
    - `isMagnet("magnet:?dn=x")` is false;
    - `displayName` of `?xt=urn:btih:0123456789&dn=Ubuntu+24.04` is `"Ubuntu 24.04"`;
    - without `dn` it is `"01234567…"`;
    - a 60-character `dn` gives a result of 45 characters ending in `…`.
  - `MagnetHandlerTests`, using a fake `Notifying` that records posts, a fake `RemoteClient`, `ServerConfig(store: <temp suite>, passwords: <fake>)` and `RecentMagnets(defaults: <temp suite>)`.
    - `testIgnoresNonMagnet`;
    - `testNotConfiguredOpensSettings`;
    - `testSuccessAddsRecentAndNotifies`;
    - `testSuccessSilentWhenNotificationsOff`;
    - `testFailureNotifiesEvenWhenSuccessNotificationsOff` (Review Focus 5).
- [ ] **Step 2:** Run `$TEST`. Expected: FAIL.
- [ ] **Step 3:** Implement. `AppDelegate.handleURLEvent` passes the string straight through; `MagnetHandler` filters it. `AppDelegate` builds `MagnetHandler(notifier: notifier, openSettings: { [weak self] in self?.openSettings() })`. Keep the URL handler in `willFinishLaunching`.
- [ ] **Step 4:** Run `$TEST`. Expected: PASS. Manual check: `open "magnet:?xt=urn:btih:TEST&dn=x"` with no server set opens the window.
- [ ] **Step 5:** Commit with the message "Validate magnet URLs, always report failures, open setup when unconfigured".

### Task 6: Launch at login and Keychain correctness

**Files:**
- Modify: `MagnetRelay/Services/LaunchAtLogin.swift`, `MagnetRelay/Services/KeychainService.swift`

**Interfaces:**
- Produces:
  - `final class LaunchAtLogin: ObservableObject { static let shared; @Published private(set) var isEnabled: Bool; func set(_ enabled: Bool) }`. It reads `SMAppService.mainApp.status == .enabled`; after register or unregister it re-reads the status, so a failure reverts the switch.
  - `KeychainService.setPassword(_:) -> Bool` returns whether `SecItemAdd` succeeded (or `SecItemUpdate`, if the item already exists). Remove the `LocalAuthentication` import.
- [ ] **Step 1:** Implement both. These wrap system services, so there are no unit tests; verification is manual.
- [ ] **Step 2:** Build with `$TEST`. Expected: PASS, with the earlier tests still green.
- [ ] **Step 3:** Commit with the message "Read launch-at-login from SMAppService; check Keychain writes".

### Task 7: The `Relay` design system and magnet mark

**Files:**
- Create: `MagnetRelay/Design/Theme.swift`, `MagnetRelay/Design/MagnetMark.swift`, `MagnetRelay/Design/Controls.swift`
- (Old `DesignSystem.swift` / `Components.swift` stay until Task 9.)

**Interfaces:**
- Produces:
  - `extension Color { enum Relay { static let background, card, ink, secondary, hairline, accent, ready } }`, with the values from Global Constraints. It uses the existing `Color(light:dark:)` initialiser; move that and `NSColor(hex:)` into `Theme.swift` and delete them from `DesignSystem.swift`.
  - `extension Font { enum Relay { static let heading (22 semibold), body (13), secondary (12), label (13 semibold) } }`; heading tracking is applied with `.tracking(-0.44)`.
  - `enum RelayMetrics { static let gutter: CGFloat = 24; cardRadius: CGFloat = 10; rowHeight: CGFloat = 40; windowSize = CGSize(width: 460, height: 430) }`.
  - `struct MagnetShape: Shape` for the U path (24×24 design space, scaled to rect), and `struct PoleTipsShape: Shape` for the two tips.
  - `struct MagnetMark: View { var size: CGFloat }`: a `#1D1D1F` tile in both modes, corner radius `size * 0.24` continuous, white `MagnetShape` and accent `PoleTipsShape`, line width `size * 2.6/24 * 0.58` (the glyph fills about 58% of the tile, as in the mockup). Round caps.
  - `enum MagnetMarkImage { static func menuBarImage() -> NSImage }`: 18×18pt, `isTemplate = true`, the U and tips both drawn in black with no tile.
  - `Controls.swift`:
    - `RelayCard<Content>` is a grouped card with 0.5pt separators between rows; `RelayRow<Trailing>(title:trailing:)` is a 40pt row.
    - `RelayPrimaryButtonStyle` uses an `ink` fill with `background`-coloured text, a 32pt height, radius 8, and 50% opacity when disabled. `RelaySecondaryButtonStyle` uses a `card` fill and a hairline border.
    - `StepProgress(current: Int, total: Int)` draws 3pt segments, each 30pt wide with 6pt gaps, `accent` when filled and hairline-coloured when empty.
    - `ClientTile(name:isSelected:action:)` is 62pt tall with the name bottom-left (13 medium) and a 2pt `accent` stroke when selected; it carries the accessibility traits `.isButton` and `.isSelected`.
    - `StatusPill(isReady: Bool, text: String)` is a capsule with a 7pt dot (`ready` or `secondary`).
    - `InlineError(text:)` is a 7pt `accent` dot plus text in `ink`, at 12.5pt.
- [ ] **Step 1:** Implement, with a `#Preview` per control showing light and dark side by side.
- [ ] **Step 2:** Run `xcodegen generate && $TEST`. Expected: PASS.
- [ ] **Step 3:** Render the previews; Xcode canvas is fine. Compare them against `docs/superpowers/specs/assets/2026-11-04-guided-flow.html` opened in a browser: same proportions, a red-tip mark, no shadows.
- [ ] **Step 4:** Commit with the message "Add Relay design system and magnet mark".

### Task 8: `SetupFlowModel` — steps, draft, connect

**Files:**
- Create: `MagnetRelay/Settings/SetupFlowModel.swift`
- Test: `MagnetRelayTests/SetupFlowModelTests.swift`

**Interfaces:**
- Consumes: `ConnectionDraft`, `ServerConfig.draft()/apply(_:)`, `ConnectionError.message`, the `BackendFactory.create` signature.
- Produces:
  - `@MainActor final class SetupFlowModel: ObservableObject`.
  - `enum Step: Int { case client = 1, address, signIn }`, `enum Mode { case firstRun, changeServer }`.
  - `@Published var step: Step`, `@Published var draft: ConnectionDraft`, `@Published private(set) var isConnecting = false`, `@Published private(set) var errorMessage: String?`, `@Published var showsPath: Bool`.
  - `init(mode: Mode, config: ServerConfig, clientFactory: (ClientType) -> RemoteClient)`.
  - `func selectClient(_ c: ClientType)`: if `draft.port` is empty or equals any client's `defaultPort(https:)` for either flag value, set `c.defaultPort(https: draft.useHTTPS)`. rTorrent: if the path is empty, set `"/RPC2"` and `showsPath = true`. Synology: set `useHTTPS = true` and port `"5001"`. Toggling HTTPS while on Synology swaps `5000` and `5001` under the same "still a default" rule.
  - `init` takes `config: ServerConfig` (Task 2 injectable), so tests use a temporary suite and a fake password store.
  - `var canContinue: Bool` is true on client; on address, true when `draft.endpoint() != nil`; on sign in, true when not connecting and, unless the client is Deluge, the username is non-empty.
  - `func next()`, `func back()`. `back()` on step 1 in `.changeServer` calls `onFinish(.cancelled)`.
  - `func connect() async`: runs the test, then applies the draft to `config`, calls `config.markConfigAsTested()`, sets `hasCompletedSetup = true` and calls `onFinish(.connected)`. On error it sets `errorMessage` and stays on the step.
  - `func cancelConnect()` cancels the in-flight test, clears `isConnecting`, and shows no error.
  - `var onFinish: (Result) -> Void` where `enum Result { case connected, cancelled }`.
  - In `.firstRun` mode, each `next()` also calls `config.apply(draft)` except for the password. In `.changeServer` mode, nothing is written before `connect()` succeeds.
- [ ] **Step 1: Write failing tests.**
  - `testFirstRunPersistsAsYouGo`;
  - `testChangeServerDoesNotTouchLiveConfigUntilConnect` (Review Focus 4): change host to `other`, then `next()`; `config.serverHost` is unchanged; after a successful `connect()` it is `other`;
  - `testChangeServerCancelFromStepOne`;
  - `testPortSwapsOnlyWhenDefault`: port `8080` becomes Transmission's `9091`; a custom `1234` stays `1234`;
  - `testRTorrentPrefillsRPC2`;
  - `testSynologyDefaultsHTTPS5001`;
  - `testConnectFailureShowsMessageAndStays`;
  - `testCancelConnectShowsNoError`;
  - `testDelugeNeedsNoUsername`.
- [ ] **Step 2:** Run `$TEST`. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run `$TEST`. Expected: PASS.
- [ ] **Step 5:** Commit with the message "Add setup flow model with draft editing".

### Task 9: Settings UI, menu bar icon, old UI removed

**Files:**
- Create: `MagnetRelay/Settings/SettingsRootView.swift`, `SetupStepViews.swift`, `ReadyView.swift`, `RecentLinksView.swift`
- Modify: `MagnetRelay/AppDelegate.swift`
- Delete: `MagnetRelay/SettingsView.swift`, `MagnetRelay/DesignSystem.swift`, `MagnetRelay/Components.swift`

**Interfaces:**
- Consumes: Task 7 controls, Task 8 model, `LaunchAtLogin.shared`, `RecentMagnets.shared`, `ServerConfig.shared`.
- Produces:
  - `SettingsRootView` shows `SetupFlowView(model:)` when `!hasCompletedSetup` or while changing the server, and `ReadyView` otherwise. It is fixed at `RelayMetrics.windowSize` on a `Color.Relay.background` fill. The step switch uses a 0.2s ease cross-fade, or none under Reduce Motion.
  - Closing the window while in change-server mode resets to Ready and drops the draft: recreate the model on `onAppear`.

**Copy is fixed by the spec (§4) and the mockup. Use it verbatim:**

| Step | Heading | Sub |
|---|---|---|
| Client | Which app runs your downloads? | Pick the one on your server or NAS. You can change it later. |
| Address | Where is {client}? | The address you'd type in a browser to open its web page. |
| Sign in | Sign in to {client} | The same login you use on its web page. Saved in your Keychain. |
| Ready | You're all set. | Click any magnet link and it goes to your server. |

- Address step rows are Address, Port, and Use HTTPS (switch). Below them is the link "Behind a reverse proxy? **Add a path**", which reveals a Path row. For Synology over HTTP to a local address, add the line "Your password is sent unencrypted on your home network." in secondary text.
- Sign in step rows are Username and Password, with a show/hide eye button labelled for accessibility. For Deluge there is no Username row; instead show the sub-line "Deluge only asks for a password." While connecting, the primary button reads "Connecting…" with a small `ProgressView` and the left button reads **Cancel**.
- The footer has "Step N of 3", or **Back**/**Cancel**, on the left, and **Continue** or **Connect** on the right (`.keyboardShortcut(.defaultAction)`).
- Ready has a 56pt mark and a `StatusPill`:
  - when tested: `"{client} · {host}:{port} · checked {relative}"`;
  - otherwise: `"{client} · {host}:{port} · not checked yet"`.
- Below it is a card with the rows "Open at login" (switch bound to `LaunchAtLogin.shared`) and "Notify when a link is sent" (switch bound to `showNotifications`).
- `RecentLinksView` observes `RecentMagnets.shared` (`@ObservedObject`), so the list and the Clear state update live (§5.10).
- The footer has **Recent links ›** (a popover with `RecentLinksView`: up to 5 names, click to resend through `AppDelegate`'s handler, and **Clear**; it shows "No links yet." when empty) and **Change server** (secondary).
- Bottom line, 11pt secondary: `"Privacy Policy · v{CFBundleShortVersionString}"`. The privacy link is `https://github.com/n0dal/MagnetRelay/blob/main/PRIVACY.md`.
- `AppDelegate`:
  - the window hosts `SettingsRootView`;
  - `statusItem.button.image = MagnetMarkImage.menuBarImage()`;
  - the menu header "Recent Magnets" becomes "Recent Links";
  - menu items "Settings…" (with a real ellipsis) and "Quit MagnetRelay" stay.
- Delete `ClientType.shortName` if it's unused.

- [ ] **Step 1:** Build the views. Delete the three old files. Run `xcodegen generate`.
- [ ] **Step 2:** Run `$TEST`. Expected: PASS, with no references left to `Color.MR`, `Font.MR`, `MRSpacing` or `MR*` views. `grep -rn "Color.MR\|MRSpacing\|MRLayout" MagnetRelay` prints nothing.
- [ ] **Step 3:** Build Debug and install per CLAUDE.md. Reset with `defaults delete com.magnetrelay.app` and launch. Capture each screen with `./Tests/screenshot.sh step1`, then `step2`, `step3_error` (use a wrong password against `python3 Tests/mock_synology.py`, host `localhost`, port `5000`), `ready`, and `ready_dark` (System Settings → Appearance → Dark). Compare against the mockup. The red appears only on the selected tile, the progress bar, the error dot and the mark tips.
- [ ] **Step 4:** Manual check: on Ready, Change server → edit host → close window → reopen shows the old host; a magnet sent meanwhile reaches the mock server.
- [ ] **Step 5:** Commit with the message "New guided settings window and Ready screen; remove old design system".

### Task 10: App icon and brand art

**Files:**
- Create: `tools/render_brand.swift`, `assets/brand/magnetrelay-mark.svg`, `assets/readme/hero-light.png`, `assets/readme/hero-dark.png`
- Modify: `MagnetRelay/Assets.xcassets/AppIcon.appiconset/*.png` (same filenames as today, so `Contents.json` is unchanged)

**Interfaces:**
- `swift tools/render_brand.swift <repo-root>` draws with AppKit/CoreGraphics. No SVG tooling is installed, so the drawing code is the source of truth and the SVG is a reference copy (§3 path).
- Icon:
  - 1024 canvas; the macOS icon grid tile is 824×824 centred (100px inset), corner radius 185, fill `#1D1D1F`;
  - a subtle 1px inner top highlight at 8% white is allowed, with no other gradients;
  - the glyph fills about 58% of the tile, with white U and `#E5484D` tips;
  - written at 16, 32, 64, 128, 256, 512 and 1024 to the existing filenames.
- Hero: 1600×560.
  - Left side: mark (120pt), "MagnetRelay" at 64pt semibold, and the pitch "Click a magnet link. It lands on your home server." at 24pt in `secondary`.
  - Right side: the Ready screenshot from Task 9 (`Tests/screenshots/ready*.png`) on `background`, with a dark variant using the dark tokens and `ready_dark`.
- [ ] **Step 1:** Write the script and run it.
- [ ] **Step 2:** Open `icon_512x512@2x.png` and `icon_16x16.png` and check that the 16px version still reads as a magnet. If it doesn't, thicken the stroke for sizes of 32px and below (allowed). Open both hero images.
- [ ] **Step 3:** Rebuild and install, then check the icon in Finder, the Dock (via ⌘-Tab while the window is open) and the menu bar.
- [ ] **Step 4:** Commit with the message "New magnet icon and README hero".

### Task 11: Visual tests and screenshots

**Files:**
- Modify: `Tests/visual_tests.sh`, `Tests/screenshot.sh` (only if needed)
- Create: `assets/screenshots/{client,address,signin,ready,ready-dark}.png`, replacing `assets/screenshot-main.png`, `assets/screenshot-configured.png` and `assets/appstore/*.png` (delete the old ones; App Store sizes 1280×800 and 1440×900 are regenerated into `assets/appstore/`)

- [ ] **Step 1:** Replace the test list with `first_launch` (step 1), `client_<each>` (step 2 for each client, showing port, path and HTTPS defaults), `signin_deluge`, `signin_error`, `ready`, `ready_unchecked` (config edited after test), and `ready_dark`. Drop `https_enabled`, `empty_config` and `normal_settings`. Set state with `defaults write com.magnetrelay.app …`, including `serverPath` and `hasCompletedSetup`.
- [ ] **Step 2:** Run `./Tests/visual_tests.sh`. Expected: one PNG per test in `Tests/screenshots/`, and each one matches the mockup on visual inspection.
- [ ] **Step 3:** Copy the chosen captures into `assets/screenshots/` and produce the two App Store sizes. Centre the window on `Color.Relay.background`; `render_brand.swift` can gain a `--appstore` mode.
- [ ] **Step 4:** Update CLAUDE.md's "Available tests" line. Commit with the message "Update visual tests and screenshots for new UI".

### Task 12: Docs, licence, identity strings

**Files:**
- Modify: `README.md`, `PRIVACY.md`, `LICENSE`, `CLAUDE.md`, `project.yml` (`MARKETING_VERSION: "1.1.0"`, `CURRENT_PROJECT_VERSION: "3"`), `MagnetRelay/Info.plist` (`CFBundleShortVersionString` `$(MARKETING_VERSION)`, `CFBundleVersion` `$(CURRENT_PROJECT_VERSION)`, `NSHumanReadableCopyright` `© 2025 n0dal`)
- Create: `docs/DEVELOPMENT.md`

- [ ] **Step 1: README**, following Inkroot's structure in MagnetRelay's style:
  - hero `<picture>` (light/dark, `assets/readme/`);
  - `# MagnetRelay`;
  - bold one-liner "Click a magnet link. It lands on your home server.";
  - a 2-sentence intro;
  - an anchor link row;
  - **Download**: an App Store link placeholder `https://apps.apple.com/app/magnetrelay` (marked `<!-- TODO: real App Store URL -->`) plus "build from source";
  - **How it works**: 3 numbered steps with the step screenshots, then the Ready screenshot;
  - **Supported clients** table with columns Client / Default port / Notes, including the Deluge daemon note, rTorrent `/RPC2`, and Synology's HTTPS rule;
  - **Privacy**: 4 plain bullets linking PRIVACY.md;
  - **FAQ**: "Does it download anything?" (no), "Where's my password stored?", "My client is behind a reverse proxy", "Synology says HTTPS is required";
  - **For tinkerers**: build, test, mock server, visual tests, linking `docs/DEVELOPMENT.md`;
  - License.
  - No emoji, no badge row, no "Made with ❤️". The clone URL is `https://github.com/n0dal/MagnetRelay.git`.
- [ ] **Step 2: `docs/DEVELOPMENT.md`**: a repo map table using the new file layout, everyday commands (generate, build, test, install, mock server, visual tests, render brand), and the gotchas from CLAUDE.md written for humans.
- [ ] **Step 3: PRIVACY.md**: "last 5 links"; mention the optional server path; set "Last Updated: November 2026"; the contact is `https://github.com/n0dal/MagnetRelay/issues`. **LICENSE**: `Copyright (c) 2025 n0dal`.
- [ ] **Step 4: CLAUDE.md**:
  - update the architecture tree;
  - the design-system section becomes the `Relay` tokens and the mark;
  - the menu bar icon becomes the template magnet;
  - remove Preferences sheet/banner references;
  - add an "Identity" note: GitHub `n0dal`, commit email `81403084+n0dal@users.noreply.github.com`, no Co-Authored-By trailers.
- [ ] **Step 5:** Verify the strings. `git grep -in "pgpillar"` prints nothing. `git grep -n "Co-Authored-By"` prints only this plan, the spec and the CLAUDE.md Identity note. Run `$TEST`; expected: PASS.
- [ ] **Step 6:** Commit with the message "Rewrite README, add DEVELOPMENT.md, move identity to n0dal, bump to 1.1.0".

### Task 13: Merge, rewrite history, force-push

**Files:** git only.

- [ ] **Step 1:** Run `git checkout main && git merge --ff-only redesign`. Confirm `git status` is clean, apart from the old local `project.pbxproj` diff, which `xcodegen` already superseded; it should be gone.
- [ ] **Step 2:** Back up first: `git bundle create ~/git-backups/magnetrelay-before-n0dal-scrub-$(date +%Y%m%d-%H%M%S).bundle --all`, then `git bundle verify <that file>`. Expected: "is okay".
- [ ] **Step 3:** Rewrite:

```bash
git filter-repo --force \
  --message-callback 'import re; return re.sub(rb"\n*^Co-Authored-By: Claude[^\n]*$", b"", message, flags=re.M|re.I).rstrip(b"\n") + b"\n"' \
  --email-callback 'return email.replace(b"81403084+pgpillar@users.noreply.github.com", b"81403084+n0dal@users.noreply.github.com")'
git remote add origin https://github.com/n0dal/MagnetRelay.git   # filter-repo removes origin
```

- [ ] **Step 4:** Verify:
  - `git log --format=%B | grep -ic "co-authored-by: claude"` prints `0`;
  - `git log --format='%ae %ce' | sort -u` prints only the n0dal address;
  - `git log --oneline | wc -l` equals the commit count before the rewrite;
  - `$TEST` passes.
- [ ] **Step 5: Stop and ask the owner** before pushing. Show them the verification output. On a yes, run `git push --force origin main`, then delete the remote `redesign` branch if it was pushed. Then run `gh repo edit n0dal/MagnetRelay --description "macOS menu bar app that sends magnet: links to your home download server (qBittorrent, Transmission, Deluge, rTorrent, Synology)."`. This drops "torrent clients" from the description, which the App Store rule doesn't require, but it matches the new voice. Confirm the wording with the owner as part of the same ask.
