#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Rebuild the app fresh so the share folder never ships something stale.
(cd mac-app && ./scripts/build-app.sh)

# Version comes from the app's Info.plist so the zip name always tracks the
# actual build -- bump CFBundleShortVersionString there, not here.
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" mac-app/Resources/Info.plist)

SHARE="share"
rm -rf "$SHARE"
mkdir -p "$SHARE"
cp -R "mac-app/Darter.app" "$SHARE/Darter.app"
cp -R "lightroom-plugin/Darter.lrdevplugin" "$SHARE/Darter.lrdevplugin"
cp "scripts/README.txt" "$SHARE/README.txt"
find "$SHARE" -name '.DS_Store' -delete

ZIP="Darter-v${VERSION}.zip"
rm -f "$ZIP"
(cd "$SHARE" && zip -rq "../$ZIP" . -x '.*')

echo "Built $ZIP (version $VERSION)"
