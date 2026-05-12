#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_NAME="MyServers"
APP_BUNDLE_ID="${APP_BUNDLE_ID:-com.myservers.app}"
APP_VERSION="${APP_VERSION:-0.1.6}"
APP_BUILD="${APP_BUILD:-6}"
LOCAL_NETWORK_USAGE_DESCRIPTION="${LOCAL_NETWORK_USAGE_DESCRIPTION:-MyServers needs access to devices on your local network so it can connect to servers by LAN IP or hostname.}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
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

cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>MyServers</string>
    <key>CFBundleIdentifier</key>
    <string>${APP_BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleIconFile</key>
    <string>MyServers</string>
    <key>CFBundleName</key>
    <string>MyServers</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${APP_BUILD}</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSLocalNetworkUsageDescription</key>
    <string>${LOCAL_NETWORK_USAGE_DESCRIPTION}</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "Signing app bundle with identity: $SIGNING_IDENTITY"
codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP_DIR"

echo "App bundle ready:"
echo "  $APP_DIR"
echo
echo "Run it with:"
echo "  open \"$APP_DIR\""
