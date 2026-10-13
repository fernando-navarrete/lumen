#!/usr/bin/env bash
# Renders the hicolor PNGs from the app icon SVG (needs rsvg-convert).
set -euo pipefail
cd "$(dirname "$0")/.."
id=io.github.fernando_navarrete.Lumen
base=linux/packaging/icons/hicolor
for size in 48 64 128 256 512; do
  mkdir -p "$base/${size}x${size}/apps"
  rsvg-convert -w "$size" -h "$size" "$base/scalable/apps/$id.svg" \
    -o "$base/${size}x${size}/apps/$id.png"
done
