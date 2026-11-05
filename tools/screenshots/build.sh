#!/bin/zsh
# Builds and runs the screenshot harness: compiles the real app sources (minus the @main app) with
# main.swift, hosts the real settings panel with throwaway settings (never com.magnetrelay.app
# defaults or the Keychain), and writes raw captures plus the README shots.
#   ./tools/screenshots/build.sh            -> raw: Tests/screenshots/  README: assets/screenshots/
# Then re-render the hero/social/App Store art: swift tools/render_brand.swift . (and --appstore)
set -e
HERE="${0:A:h}"
ROOT="${HERE:h:h}"
BUILD="$(mktemp -d)"
srcs=(${(f)"$(find "$ROOT/MagnetRelay" -name '*.swift' ! -name MagnetRelayApp.swift)"})
swiftc -O -target "$(uname -m)-apple-macos13.0" -o "$BUILD/shots" "$HERE/main.swift" $srcs \
  -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker "$HERE/Info.plist"
mkdir -p "$ROOT/Tests/screenshots" "$ROOT/assets/screenshots"
"$BUILD/shots" "$ROOT/Tests/screenshots" "$ROOT/assets/screenshots"
rm -rf "$BUILD"
