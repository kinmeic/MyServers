#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_NAME="MyServers"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE="$BUILD_DIR/$APP_NAME"
PLIST_PATH="$CONTENTS_DIR/Info.plist"
ICON_SOURCE="/Users/eugene/Downloads/MyServers.png"
ICON_OUTPUT="$ROOT_DIR/Resources/MyServers.icns"

echo "Building release binary..."
cd "$ROOT_DIR"
swift build -c release

if [[ -f "$ICON_SOURCE" ]]; then
  "$ROOT_DIR/scripts/generate_app_icon.sh" "$ICON_SOURCE" "$ICON_OUTPUT"
fi

echo "Packaging app bundle at $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE" "$MACOS_DIR/$APP_NAME"
if [[ -f "$ICON_OUTPUT" ]]; then
  cp "$ICON_OUTPUT" "$RESOURCES_DIR/MyServers.icns"
fi

cat > "$PLIST_PATH" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>MyServers</string>
    <key>CFBundleIdentifier</key>
    <string>com.myservers.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleIconFile</key>
    <string>MyServers</string>
    <key>CFBundleName</key>
    <string>MyServers</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "App bundle ready:"
echo "  $APP_DIR"
echo
echo "Run it with:"
echo "  open \"$APP_DIR\""
