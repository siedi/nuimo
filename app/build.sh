#!/bin/zsh
# Builds NuimoBar.app: compile, assemble the bundle, sign.
# Usage: ./build.sh            → build/NuimoBar.app
#        ./build.sh install    → additionally copy to /Applications
set -euo pipefail

cd "${0:A:h}"

APP_NAME="NuimoBar"
APP="build/$APP_NAME.app"

echo "Building $APP_NAME (release) …"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

echo "Assembling $APP …"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/default-config.toml "$APP/Contents/Resources/default-config.toml"

# Localization: add new strings from the source to the catalog, warn about missing translations, compile into
# the bundle. The compiler writes the strings it finds in String(localized:) to .stringsdata files.
echo "Localizing …"
STRINGSDATA=("${(@f)$(grep -rl --include='*.stringsdata' "\"source\": \"$PWD/Sources/$APP_NAME/" .build/out/Intermediates.noindex/*/Release 2>/dev/null || true)}")
STRINGSDATA=(${STRINGSDATA:#})
if (( ${#STRINGSDATA} )); then
    xcrun xcstringstool sync Resources/Localizable.xcstrings ${STRINGSDATA/#/--stringsdata=}
else
    echo "Warning: no .stringsdata found, Localizable.xcstrings was not synced with the source." >&2
fi
/usr/bin/python3 - Resources/*.xcstrings <<'PY'
import json, sys
for path in sys.argv[1:]:
    catalog = json.load(open(path))
    for key, entry in catalog["strings"].items():
        if entry.get("shouldTranslate") is False:
            continue
        state = entry.get("localizations", {}).get("de", {}).get("stringUnit", {}).get("state")
        if entry.get("extractionState") == "stale":
            print(f"Warning: {path}: no longer used: {key!r}", file=sys.stderr)
        elif state != "translated":
            print(f"Warning: {path}: no German translation: {key!r}", file=sys.stderr)
PY
for CATALOG in Resources/*.xcstrings; do
    xcrun xcstringstool compile "$CATALOG" --output-directory "$APP/Contents/Resources"
done

# Sign with the first "Apple Development" identity so the Accessibility permission survives a rebuild.
IDENTITY_LINE="$(security find-identity -v -p codesigning | grep -m1 '"Apple Development' || true)"
if [[ -n "$IDENTITY_LINE" ]]; then
    IDENTITY_HASH="$(awk '{ print $2 }' <<< "$IDENTITY_LINE")"
    IDENTITY_NAME="$(awk -F'"' '{ print $2 }' <<< "$IDENTITY_LINE")"
    echo "Signing with “$IDENTITY_NAME” …"
    codesign --force --timestamp=none --sign "$IDENTITY_HASH" "$APP"
else
    echo "Warning: no “Apple Development” identity found, signing ad hoc." >&2
    echo "         The Accessibility permission then has to be granted again after every build." >&2
    codesign --force --sign - "$APP"
fi
codesign --verify --strict "$APP"

# Place for Developer ID signing and notarization later on.

echo "Done: $APP"

if [[ "${1:-}" == "install" ]]; then
    TARGET="/Applications/$APP_NAME.app"
    if pgrep -xq "$APP_NAME"; then
        echo "Quitting running $APP_NAME …"
        osascript -e "quit app \"$APP_NAME\"" || pkill -x "$APP_NAME" || true
        sleep 1
    fi
    echo "Installing to $TARGET …"
    rm -rf "$TARGET"
    ditto "$APP" "$TARGET"
    echo "Installed: $TARGET"
fi
