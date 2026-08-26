#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="Darter.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/Darter" "$APP/Contents/MacOS/Darter"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"
cp "Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# Signed with a stable local self-signed identity (see mac-app/signing/ and
# the README) so the app's code identity stays constant across rebuilds --
# unlike ad-hoc signing (-s -), which hashes the binary itself and
# invalidates the Accessibility TCC grant on every rebuild.
#
# Prefers the Darter identity, falls back to the pre-rename one, and finally
# to ad-hoc so a fresh clone still builds (at the cost of re-granting
# Accessibility after each rebuild).
SIGNING_IDENTITY=""
for candidate in "Darter Local Dev" "AndrewKeys Local Dev"; do
  if security find-identity -v -p codesigning | grep -q "$candidate"; then
    SIGNING_IDENTITY="$candidate"
    break
  fi
done

if [ -n "$SIGNING_IDENTITY" ]; then
  codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP"
  echo "Signed with: $SIGNING_IDENTITY"
else
  codesign --force --deep --sign - "$APP"
  echo "Signed ad-hoc (no local dev identity found -- see README)"
fi

echo "Built $APP"
