#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-${XPI_VERSION:-0.0.02}}"
DIST_DIR="${DIST_DIR:-dist}"
APP_NAME="XPI"
EXECUTABLE_NAME="XPI"
ASSET_PREFIX="XPadInput-${VERSION}"
BUNDLE_ID="${XPI_BUNDLE_ID:-com.sp80808.xpi}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: macOS packaging requires a macOS host" >&2
  exit 1
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9]+)?$ ]]; then
  echo "error: version must look like 0.0.02 or 0.0.02-alpha" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

printf 'Building XPI %s in release mode...\n' "$VERSION"
swift build -c release --product XPI
BIN_DIR="$(swift build -c release --show-bin-path)"
BINARY="$BIN_DIR/$EXECUTABLE_NAME"

if [[ ! -x "$BINARY" ]]; then
  echo "error: release executable not found at $BINARY" >&2
  exit 1
fi

APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BINARY" "$MACOS_DIR/$EXECUTABLE_NAME"
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>XPI: Game Controller MIDI</string>
    <key>CFBundleExecutable</key>
    <string>XPI</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>XPI</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

plutil -lint "$CONTENTS/Info.plist"

# Early alphas are distributed without a Developer ID certificate. Ad-hoc
# signing keeps the bundle internally consistent without pretending it is
# notarized. A future release workflow can replace this with Developer ID +
# notarization when credentials are available.
codesign --force --deep --sign - --timestamp=none "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

ZIP_PATH="$DIST_DIR/${ASSET_PREFIX}.zip"
DMG_PATH="$DIST_DIR/${ASSET_PREFIX}.dmg"
CHECKSUM_PATH="$DIST_DIR/SHA256SUMS.txt"

ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

DMG_STAGE="$DIST_DIR/dmg-stage"
mkdir -p "$DMG_STAGE"
ditto "$APP_BUNDLE" "$DMG_STAGE/$APP_NAME.app"
ln -s /Applications "$DMG_STAGE/Applications"
hdiutil create \
  -volname "XPI ${VERSION}" \
  -srcfolder "$DMG_STAGE" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null
rm -rf "$DMG_STAGE"

(
  cd "$DIST_DIR"
  shasum -a 256 "$(basename "$DMG_PATH")" "$(basename "$ZIP_PATH")" > "$(basename "$CHECKSUM_PATH")"
)

printf '\nPackaged:\n'
printf '  %s\n' "$APP_BUNDLE"
printf '  %s\n' "$DMG_PATH"
printf '  %s\n' "$ZIP_PATH"
printf '  %s\n' "$CHECKSUM_PATH"
cat "$CHECKSUM_PATH"
