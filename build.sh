#!/bin/zsh
# Builds ShuttleX.app as a pure arm64 binary (Apple Silicon, not a universal app).
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --arch arm64

# Ask the toolchain where it put the binary instead of hard-coding the path.
# Swift 6.4 moved the output from .build/<triple>/release to .build/out/Products/
# — with a hard-coded path, a stale binary from an older toolchain gets packaged
# silently, which is far worse than a build error.
BIN_DIR="$(swift build -c release --arch arm64 --show-bin-path)"
BIN="$BIN_DIR/ShuttleX"
if [[ ! -x "$BIN" ]]; then
  echo "error: no ShuttleX binary at $BIN" >&2
  exit 1
fi

APP="build/ShuttleX.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/ShuttleX"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"

# Pick the app icon by release channel so prerelease builds carry a BETA badge
# (distinguishes Beta from Stable in Finder / the Applications folder).
CHANNEL=$(/usr/libexec/PlistBuddy -c "Print :ShuttleXChannel" "Resources/Info.plist" 2>/dev/null || echo stable)
if { [ "$CHANNEL" = "beta" ] || [ "$CHANNEL" = "alpha" ]; } && [ -f "Resources/AppIcon-Beta.icns" ]; then
    ICON="Resources/AppIcon-Beta.icns"
else
    ICON="Resources/AppIcon.icns"
fi
cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"
echo "Icon: $ICON (channel: $CHANNEL)"

codesign --force --sign - "$APP"

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
ditto -c -k --keepParent "$APP" "ShuttleX-$VERSION-arm64.zip"

echo ""
echo "Done: $PWD/$APP"
echo "Zip:  $PWD/ShuttleX-$VERSION-arm64.zip"
lipo -info "$APP/Contents/MacOS/ShuttleX"
