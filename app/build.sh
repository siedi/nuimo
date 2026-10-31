#!/bin/zsh
# Builds NuimoBar.app: compile, assemble the bundle, sign.
# Usage: ./build.sh            → build/NuimoBar.app
#        ./build.sh install    → additionally copy to /Applications
set -euo pipefail

cd "${0:A:h}"

APP_NAME="NuimoBar"
APP="build/$APP_NAME.app"

echo "Baue $APP_NAME (release) …"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

echo "Setze $APP zusammen …"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/default-config.toml "$APP/Contents/Resources/default-config.toml"

# Sign with the first "Apple Development" identity so the Accessibility permission survives a rebuild.
IDENTITY_LINE="$(security find-identity -v -p codesigning | grep -m1 '"Apple Development' || true)"
if [[ -n "$IDENTITY_LINE" ]]; then
    IDENTITY_HASH="$(awk '{ print $2 }' <<< "$IDENTITY_LINE")"
    IDENTITY_NAME="$(awk -F'"' '{ print $2 }' <<< "$IDENTITY_LINE")"
    echo "Signiere mit „$IDENTITY_NAME“ …"
    codesign --force --timestamp=none --sign "$IDENTITY_HASH" "$APP"
else
    echo "Warnung: Keine Identität „Apple Development“ gefunden, signiere ad hoc." >&2
    echo "         Die Freigabe für Bedienungshilfen muss dann nach jedem Neubau neu erteilt werden." >&2
    codesign --force --sign - "$APP"
fi
codesign --verify --strict "$APP"

# Place for Developer ID signing and notarization later on.

echo "Fertig: $APP"

if [[ "${1:-}" == "install" ]]; then
    TARGET="/Applications/$APP_NAME.app"
    if pgrep -xq "$APP_NAME"; then
        echo "Beende laufende $APP_NAME …"
        osascript -e "quit app \"$APP_NAME\"" || pkill -x "$APP_NAME" || true
        sleep 1
    fi
    echo "Installiere nach $TARGET …"
    rm -rf "$TARGET"
    ditto "$APP" "$TARGET"
    echo "Installiert: $TARGET"
fi
