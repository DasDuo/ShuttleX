#!/bin/zsh
# Baut ShuttleX.app als reines arm64-Binary (Apple Silicon, keine Universal App).
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --arch arm64

APP="build/ShuttleX.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp ".build/arm64-apple-macosx/release/ShuttleX" "$APP/Contents/MacOS/ShuttleX"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"

codesign --force --sign - "$APP"

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
ditto -c -k --keepParent "$APP" "ShuttleX-$VERSION-arm64.zip"

echo ""
echo "Fertig: $PWD/$APP"
echo "Zip:    $PWD/ShuttleX-$VERSION-arm64.zip"
lipo -info "$APP/Contents/MacOS/ShuttleX"
