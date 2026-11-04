# MagnetRelay — redesign

*2026-11-04 · status: settings design approved by owner in conversation (mockup "C · Guided, then gone" with the magnet mark); builder-check questions resolved. Approved mockup: `docs/superpowers/specs/assets/2026-11-04-guided-flow.html`.*

## 1. Intent

MagnetRelay was built a while ago. Its look (indigo `#6366F1`, rounded cards, soft shadows, spring
animations, an SF Symbol on every label) reads as a generic template, and the owner's taste has moved
on. Inkroot (`~/Projects/inkroot`, live at `github.com/n0dal/inkroot`) is the owner's reference for
polish: a small, strict design system derived from what the product *is*, short warm copy, and a
GitHub page that looks like a product.

**What carries over from Inkroot is the discipline, not the look.** Inkroot's 1-bit ink/dither style
fits an e-ink tablet tool; it does **not** fit MagnetRelay. MagnetRelay's style comes from what it is:
a small, native Mac utility that quietly passes links to a server at home.

**The feeling the owner wants:** *effortless, it just works. Clean.*

**Where it matters most:** the settings window. It's the one thing every user sets up; afterwards the
app sits in the menu bar in the background.

## 2. Goals, non-goals, anti-goals

**Goals**
1. Rebuild the settings window as the approved guided flow (§4) with the new visual system (§3).
2. New app icon and menu bar icon from the magnet mark.
3. Fix the correctness bugs found in the review (§5).
4. Bring the repo up to Inkroot's standard: README, docs, privacy policy, screenshots (§6).
5. Move everything from the old `pgpillar` handle to `n0dal`, and remove every
   `Co-Authored-By: Claude …` trailer from git history (§7).

**Non-goals**
- New download clients, or auto-detecting the client from an address (considered, not chosen).
- A website / GitHub Pages site (Inkroot has one; not in scope here).
- Changing bundle ID, App Store listing, or distribution.

**Anti-goals** (failure even if it technically works)
- Looking like Inkroot (ink, dither, paper, mono-everything, hard 2px borders).
- Looking like a template again: gradients, multiple accent colours, decorative icons on every row,
  bouncy animation.
- Custom-drawn controls that feel less native than the real macOS ones.
- Any user-visible "torrent" wording beyond client product names (App Store rule, see CLAUDE.md).

## 3. Visual system

Native macOS first: system font (SF Pro via `.system`), real `TextField`/`SecureField`/`Toggle`,
standard window chrome. Identity comes from restraint plus one mark and one colour.

**Palette** (replace all of `Color.MR` with these; delete the rest):

| Token | Light | Dark | Use |
|---|---|---|---|
| `background` | `#F6F5F3` (warm grey) | `#1C1C1E` | window |
| `card` | `#FFFFFF` | `#2C2C2E` | grouped rows, tiles |
| `ink` | `#1D1D1F` | `#F5F5F7` | primary text, primary button fill |
| `secondary` | `#6E6E73` | `#98989D` | secondary text |
| `hairline` | `black 9%` | `white 10%` | card outlines, row separators (0.5pt) |
| `accent` | `#E5484D` (magnet red) | `#FF6369` | **only** the active/selected thing: selected tile outline, step progress, error dot, mark pole tips |
| `ready` | `#2DA44E` | `#3FB950` | **only** the connected dot and "on" switch tint |

Dark mode follows the system. Primary button in dark mode: `ink` fill (near-white) with dark text.

**Shape & type:** cards 10pt continuous radius, 0.5pt hairline, no drop shadows inside the window.
Heading 22pt semibold, tracking −0.02em. Body 13pt regular. Secondary 13/12pt in `secondary`.
No uppercase section labels with SF Symbols (remove `MRFieldRow`).

**Motion:** step changes use a short cross-fade/slide (≈0.2s ease). No springs, no scale-on-press.
Respect Reduce Motion.

**The mark:** a dark tile (`#1D1D1F`, continuous corner radius) holding a white horseshoe magnet
(U shape, thick round stroke) with the two pole tips in `accent` red. Reference SVG (24×24 viewBox):

```svg
<path d="M6 4v8a6 6 0 0 0 12 0V4" stroke="#fff" stroke-width="2.6" stroke-linecap="round" fill="none"/>
<path d="M6 4h3M15 4h3" stroke="#E5484D" stroke-width="2.6" stroke-linecap="round"/>
```

- **App icon:** replaces the current purple/blue icon in `Assets.xcassets/AppIcon.appiconset`
  (all sizes 16–1024). Follow macOS icon grid proportions (tile inset within the canvas) so it sits
  right in the Dock/Finder/App Store. Keep a source SVG in `assets/brand/`.
- **In-window:** 30pt mark + "MagnetRelay" (13pt semibold) top-left on setup steps; 56pt mark centred
  on the Ready screen. Draw it in SwiftUI or ship it as a vector asset — builder's choice.
- **Menu bar icon:** a monochrome template version of the magnet (no tile, no red) replacing the
  SF Symbol `link`.

## 4. Settings window

Fixed size, about 460×430pt, non-resizable, titled "MagnetRelay" (keep the existing NSHostingController
window management in `AppDelegate`). Two modes:

### 4.1 First run: three steps
Shown when setup hasn't completed, or after **Change server**. Header on every step: mark + name on
the left, a 3-segment progress bar on the right (filled segments in `accent`). Footer: "Step 1 of 3"
or **Back** on the left, primary button on the right. Return triggers the primary button.

1. **Client** — "Which app runs your downloads?" / "Pick the one on your server or NAS. You can change
   it later." 3×2 grid of tiles (qBittorrent, Transmission, Deluge, rTorrent, Synology), name only,
   no icons. Selected tile: 2pt `accent` outline. → **Continue**.
2. **Address** — "Where is {client}?" / "The address you'd type in a browser to open its web page."
   Grouped card: Address, Port (pre-filled with the client's default; keep the existing rule of
   swapping defaults when the client changes), Use HTTPS switch. Below: "Behind a reverse proxy?
   **Add a path**" reveals an optional Path row (e.g. `/qbittorrent`, `/RPC2`). For rTorrent, show the
   Path row by default pre-filled `/RPC2`. For Synology, HTTPS defaults on. **(My call)** Plain HTTP is
   allowed for local addresses — `localhost`, `127.0.0.0/8`, private ranges `10/8`, `172.16/12`,
   `192.168/16`, link-local, and `*.local` hostnames — with a one-line note that the password travels
   unencrypted on your network. Any other address requires HTTPS, and Connect fails with a sentence
   saying so. Update `SynologyBackend.validateSecureConnection` to match. → **Continue** (disabled until address is non-empty).
3. **Sign in** — "Sign in to {client}" / "The same login you use on its web page. Saved in your
   Keychain." Username + Password (with show/hide). For Deluge: hide Username and say "Deluge only
   asks for a password." → **Connect** runs the connection test. While testing: button shows a
   spinner and "Connecting…", Back becomes **Cancel**. On failure: red dot + one full plain sentence
   that says what happened and what to try (§5.4), user stays on step 3. On success: go to Ready.

**First run:** settings are persisted as the user moves through steps (as today); setup is only
"complete" after a successful Connect.

**Change server (my call):** the steps edit a *draft* copy, pre-filled from the live config. Nothing
is written to `ServerConfig`/Keychain until Connect succeeds, so incoming magnets keep going to the
working server meanwhile. On step 1 the left footer button is **Cancel** (discard draft → Ready);
closing the window mid-flow also discards the draft. Reopening shows Ready with the old, still-working
config.

### 4.2 Ready
Shown every time the window opens once setup is complete.
- Centred 56pt mark, "You're all set.", "Click any magnet link and it goes to your server."
- Status pill: green dot · "{client} · {host}:{port}" · "checked {relative time}". If the saved config
  no longer matches the last tested one, show a neutral dot and "not checked yet".
- Grouped card: **Open at login** switch, **Notify when a link is sent** switch.
- Footer: **Recent links ›** on the left (opens a small sheet/popover: up to 5 links by name, click to
  resend, **Clear**), **Change server** secondary button on the right (re-enters step 1 with current
  values pre-filled).
- Small footer links somewhere unobtrusive: Privacy Policy (→ `n0dal` URL), version number.

The old Preferences sheet, welcome banner, gear button, and `bannerDismissed` flag are removed.

### 4.3 Menu bar
Unchanged structure: recent links (up to 5), **Settings…**, **Quit MagnetRelay**. New template icon.

## 5. Correctness fixes (from the review)

1. **qBittorrent form encoding.** Percent-encode form values properly (encode `&`, `+`, `=`, etc.) for
   both `urls=` and the login body. Today `.urlQueryAllowed` leaves `&` alone, so magnets lose
   `dn`/`tr` after the hash, and passwords with `&+=` fail.
2. **"Not configured" check.** `MagnetHandler` must check `serverHost`, not `serverURL` (never empty).
   When not configured, notify *and* open the settings window.
3. **Base URL with path.** Add `serverPath` to `ServerConfig`; build URLs with `URLComponents`, joining
   path segments without double slashes. All backends use it.
4. **Error messages.** Replace localized-string matching in `ConnectionError.userFriendlyMessage` with
   `URLError.Code` / HTTP status / `BackendError` mapping. Full sentences, no 40-char truncation,
   client name included where useful. Fix the SSL hint: for a certificate error say the server's
   certificate isn't trusted, don't advise turning HTTPS off (wrong for Synology).
5. **rTorrent.** Rename `RRemoteClient` → `RTorrentBackend` (file already has that name). Treat an
   XML-RPC `<fault>` response as failure.
6. **Deluge.** If the Web UI isn't connected to a daemon, `core.add_torrent_magnet` fails — check
   `web.connected` after login and, if false, connect to the first host (`web.get_hosts` →
   `web.connect`), or fail with a clear message. Builder decides which after checking the API.
7. **Keychain.** Save the password on Connect / on leaving step 3, not every keystroke. Check
   `SecItemAdd` status.
8. **Launch at login.** Read state from `SMAppService.mainApp.status` instead of a separate
   `@AppStorage` flag; on error revert the switch.
9. **Notifications.** Failures always notify (they're the only signal something went wrong); the
   switch controls success notifications only. Set a `UNUserNotificationCenter` delegate so banners
   show while the settings window is frontmost.
10. **Recent links** list must update live in the UI (observe `RecentMagnets`).
11. **URL events:** ignore anything that isn't a `magnet:` URL.
12. **Delete dead code:** `MRSectionCard`, `MRTextField`, `MRPickerField`, `MREmptyState`, `MRInfoRow`,
    `isExperimental`/`experimentalWarning`, unused view modifiers and colours, `serverURL` setter,
    unused `isLoading` path, `LocalAuthentication` import.
13. **PRIVACY.md** says "last 10 links"; the app keeps 5. Make them agree (5).

**Tests:** add an XCTest unit-test target (via `project.yml`) covering: form encoding, URL building
with/without path, display-name extraction from magnets, error mapping, and each backend's request
shape against a stubbed `URLProtocol`. The visual test scripts in `Tests/` must be updated for the new
screens (`first_launch` → step 1, `normal_settings` → Ready, etc.).

## 6. Repo & docs (Inkroot standard, MagnetRelay style)

- **README**, rewritten in the Inkroot structure but MagnetRelay's own visuals and voice:
  hero image (light/dark via `<picture>`, built from the new palette and mark — not Inkroot's), one-line
  pitch, Download (App Store link + build from source), "How it works" in 3 steps with screenshots of
  the three setup steps and Ready, supported clients table, Privacy, FAQ, "For tinkerers" (build,
  test, mock server). No emoji, no shields-badge row, no "Made with ❤️".
- **Screenshots** retaken from the new UI (light, plus one dark), replacing `assets/screenshot-*.png`
  and `assets/appstore/*`. Store under `assets/screenshots/`, brand art under `assets/brand/`.
- **`docs/DEVELOPMENT.md`**: repo map, commands, gotchas — the content of CLAUDE.md written for
  humans (as Inkroot did).
- **PRIVACY.md**: update links and the 5-link fact; bump "Last Updated".
- **LICENSE**: `Copyright (c) 2025 n0dal`.
- Add `.superpowers/` to `.gitignore`. Stop tracking `.DS_Store` if any are tracked.

## 7. Identity & history

- `n0dal` is the same GitHub account renamed from `pgpillar` (user ID 81403084); `github.com/pgpillar/MagnetRelay`
  already redirects to `github.com/n0dal/MagnetRelay`, which exists and is public.
- Replace every `pgpillar` reference with `n0dal`: git remote URL
  (`https://github.com/n0dal/MagnetRelay.git`), README clone URL, PRIVACY contact, in-app privacy URL,
  LICENSE.
- Remove all `Co-Authored-By: Claude …` trailers (37 commits) with `git filter-repo`, after writing a
  backup bundle to `~/git-backups/magnetrelay-before-n0dal-scrub-<timestamp>.bundle` (same pattern as
  Inkroot). Then force-push `main`. **New commits made during this work carry no Claude co-author
  trailer.**
- **Owner decision:** in the same `filter-repo` pass, rewrite author and committer email
  `81403084+pgpillar@users.noreply.github.com` → `81403084+n0dal@users.noreply.github.com` (name stays
  "Henry Cuevas"). Set this repo's local `user.email` to the n0dal address before making any new commits.
- **Owner decision:** the Apple development team is `CY37XHX499`. Put it in `project.yml`
  (`DEVELOPMENT_TEAM`) so `xcodegen generate` keeps it.
- Do the history rewrite **last**, after all redesign commits, so it's one rewrite and one force-push.

## 8. Constraints

- macOS 13+, Swift 5.9, SwiftUI, xcodegen; App Store distribution with sandbox + network client
  entitlements (keep them in `project.yml`).
- All CLAUDE.md gotchas still apply (URL handler in `willFinishLaunching`, no `Settings {}` scene,
  no leading slash in `appendingPathComponent`, CFBundleName matches `Tests/window_capture.py`).
- Visual verification via `Tests/visual_tests.sh` / `screenshot.sh` against the mockup.

## 9. Left to the builder

Component breakdown and file layout of the new SwiftUI views; whether the mark is drawn in code or
an asset; exact spacing values within the system above; how the step transition is animated; the
icon rendering pipeline; test structure; how Deluge daemon connection is handled (§5.6).

## 10. Calls I made (not discussed with the owner)

- Exact palette values and dark-mode values (§3).
- Window size ~460×430, fixed.
- Optional path field + rTorrent `/RPC2` default (from the review, shown in mockup).
- Failures always notify; switch controls success only.
- Unit-test target added.
- Privacy/version links on the Ready screen.
- Menu bar icon becomes a template magnet.
- Change server edits a draft that's only saved on a successful Connect (§4.1).
- Synology allows plain HTTP on local/private addresses, HTTPS required elsewhere (§4.1).
