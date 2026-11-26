#!/bin/bash
# Builds StatusMonitor and assembles build/StatusMonitor.app.
# Usage: ./compile.sh            (release build)
#        CONFIG=debug ./compile.sh
set -euo pipefail

cd "$(dirname "$0")"
CONFIG="${CONFIG:-release}"

swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

APP="build/StatusMonitor.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/StatusMonitor" "$APP/Contents/MacOS/StatusMonitor"
cp Support/Info.plist "$APP/Contents/Info.plist"
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
plutil -lint "$APP/Contents/Info.plist" >/dev/null

# Ad-hoc signature so the bundle launches locally. No entitlements are needed.
codesign --force --sign - "$APP" >/dev/null

echo "Built: $(pwd)/$APP"
echo "Run:   open \"$(pwd)/$APP\""
