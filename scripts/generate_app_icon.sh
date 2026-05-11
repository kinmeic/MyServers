#!/bin/zsh
set -euo pipefail

INPUT_PNG="${1:-/Users/eugene/Downloads/MyServers.png}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_ICNS="${2:-$ROOT_DIR/Resources/MyServers.icns}"
WORK_DIR="$(mktemp -d)"
ICONSET_DIR="$WORK_DIR/AppIcon.iconset"

if [[ ! -f "$INPUT_PNG" ]]; then
  echo "Input image not found: $INPUT_PNG" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_ICNS")"
mkdir -p "$ICONSET_DIR"

create_icon() {
  local size="$1"
  local filename="$2"
  sips -z "$size" "$size" "$INPUT_PNG" --out "$ICONSET_DIR/$filename" >/dev/null
}

create_icon 16 icon_16x16.png
create_icon 32 icon_16x16@2x.png
create_icon 32 icon_32x32.png
create_icon 64 icon_32x32@2x.png
create_icon 128 icon_128x128.png
create_icon 256 icon_128x128@2x.png
create_icon 256 icon_256x256.png
create_icon 512 icon_256x256@2x.png
create_icon 512 icon_512x512.png
create_icon 1024 icon_512x512@2x.png

iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"
rm -rf "$WORK_DIR"

echo "Generated app icon:"
echo "  $OUTPUT_ICNS"
