#!/bin/zsh
# Build Recall.app, sign it with the Apple Development identity, install to /Applications and launch.
# A stable signature keeps the Accessibility permission across rebuilds.
set -euo pipefail
cd "${0:A:h}/.."

swift build -c release
APP=build/Recall.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/Recall" "$APP/Contents/MacOS/Recall"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp assets/AppIcon.icns assets/MenuBarIcon.png assets/MenuBarIcon@2x.png "$APP/Contents/Resources/"
codesign --force --options runtime --sign "Apple Development" "$APP"

# Drag-to-install disk image: the app plus an Applications shortcut.
STAGE=build/dmg
rm -rf "$STAGE" build/Recall.dmg
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname Recall -srcfolder "$STAGE" -ov -format UDZO build/Recall.dmg >/dev/null
rm -rf "$STAGE"
echo "Disk image: $PWD/build/Recall.dmg"

pkill -x Recall 2>/dev/null && sleep 1 || true
rm -rf /Applications/Recall.app
cp -R "$APP" /Applications/Recall.app
open /Applications/Recall.app
echo "Installed /Applications/Recall.app"
