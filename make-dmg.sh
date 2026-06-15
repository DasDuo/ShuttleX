#!/bin/zsh
# Packages the built ShuttleX.app into a drag-to-install DMG.
# Run ./build.sh first; then ./make-dmg.sh.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/ShuttleX.app"
[[ -d "$APP" ]] || { echo "Build first — $APP is missing. Run ./build.sh" >&2; exit 1; }

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG="ShuttleX-$VERSION-arm64.dmg"

STAGING=$(mktemp -d)
cp -R "$APP" "$STAGING/ShuttleX.app"
ln -s /Applications "$STAGING/Applications"   # drag-to-install target

rm -f "$DMG"
hdiutil create -volname "ShuttleX $VERSION" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGING"

echo "DMG:  $PWD/$DMG"
