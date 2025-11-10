#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <source_1024_png> <output_directory>"
  echo "Example: $0 ServerWatcherIcon-1024.png ./AppIcon.appiconset"
  exit 1
fi

SRC="$1"
OUT="$2"

if ! command -v sips >/dev/null 2>&1; then
  echo "Error: 'sips' not found. This script requires macOS (sips is built-in)."
  exit 1
fi

mkdir -p "$OUT"

# sizes: point size and scale -> pixel size
declare -a SIZES=(
  "16 1 16"
  "16 2 32"
  "32 1 32"
  "32 2 64"
  "128 1 128"
  "128 2 256"
  "256 1 256"
  "256 2 512"
  "512 1 512"
  "512 2 1024"
)

# Generate icons
for entry in "${SIZES[@]}"; do
  read -r pt scale px <<<"$entry"
  filename="icon_${pt}x${pt}@${scale}x.png"
  echo "Generating $filename (${px}x${px})"
  sips -s format png -z "$px" "$px" "$SRC" --out "$OUT/$filename" >/dev/null
done

# Create Contents.json
cat >"$OUT/Contents.json" <<'JSON'
{
  "images": [
    { "size": "16x16",   "idiom": "mac", "filename": "icon_16x16@1x.png",   "scale": "1x" },
    { "size": "16x16",   "idiom": "mac", "filename": "icon_16x16@2x.png",   "scale": "2x" },
    { "size": "32x32",   "idiom": "mac", "filename": "icon_32x32@1x.png",   "scale": "1x" },
    { "size": "32x32",   "idiom": "mac", "filename": "icon_32x32@2x.png",   "scale": "2x" },
    { "size": "128x128", "idiom": "mac", "filename": "icon_128x128@1x.png", "scale": "1x" },
    { "size": "128x128", "idiom": "mac", "filename": "icon_128x128@2x.png", "scale": "2x" },
    { "size": "256x256", "idiom": "mac", "filename": "icon_256x256@1x.png", "scale": "1x" },
    { "size": "256x256", "idiom": "mac", "filename": "icon_256x256@2x.png", "scale": "2x" },
    { "size": "512x512", "idiom": "mac", "filename": "icon_512x512@1x.png", "scale": "1x" },
    { "size": "512x512", "idiom": "mac", "filename": "icon_512x512@2x.png", "scale": "2x" }
  ],
  "info": { "version": 1, "author": "xcode" }
}
JSON

echo "Done. Drag '$OUT' into Assets.xcassets and set it as the App Icon in your target settings."
