#!/usr/bin/env bash
# Generate AppIcon.icns for SlapMyMac
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ICONSET_DIR="${SCRIPT_DIR}/AppIcon.iconset"
ICNS_FILE="${SCRIPT_DIR}/AppIcon.icns"
ICON_1024="/tmp/slapmac_icon_1024.png"

echo "==> Generating app icon..."

# Create icon using AppKit (native macOS)
python3 -c "
from AppKit import NSImage, NSColor, NSBezierPath, NSFont, NSString, NSMakeRect, NSGraphicsContext, NSBitmapImageRep
import Foundation

size = 1024
img = NSImage.alloc().initWithSize_((size, size))
img.lockFocus()

# Olive green background
path = NSBezierPath.bezierPathWithRoundedRect_xRadius_yRadius_(NSMakeRect(0, 0, size, size), 200, 200)
NSColor.colorWithRed_green_blue_alpha_(0.29, 0.35, 0.12, 1.0).setFill()
path.fill()

# Inner border glow
inner = NSBezierPath.bezierPathWithRoundedRect_xRadius_yRadius_(NSMakeRect(20, 20, size-40, size-40), 190, 190)
NSColor.colorWithRed_green_blue_alpha_(0.55, 0.62, 0.18, 0.3).setStroke()
inner.setLineWidth_(3)
inner.stroke()

# Hand emoji
attrs = {
    'NSFont': NSFont.systemFontOfSize_(450),
}
s = NSString.stringWithString_('\\U0001f91a')
s.drawAtPoint_withAttributes_((230, 250), attrs)

# SLAP! text
attrs2 = {
    'NSFont': NSFont.boldSystemFontOfSize_(110),
    'NSColor': NSColor.colorWithRed_green_blue_alpha_(0.78, 0.85, 0.29, 1.0),
}
s2 = NSString.stringWithString_('SLAP!')
s2.drawAtPoint_withAttributes_((290, 70), attrs2)

img.unlockFocus()

rep = NSBitmapImageRep.imageRepWithData_(img.TIFFRepresentation())
data = rep.representationUsingType_properties_(4, {})
data.writeToFile_atomically_('${ICON_1024}', True)
print('Created icon')
"

if [ ! -f "$ICON_1024" ]; then
    echo "ERROR: Could not create icon PNG"
    exit 1
fi

# Create iconset with all required sizes
rm -rf "${ICONSET_DIR}"
mkdir -p "${ICONSET_DIR}"

for size in 16 32 128 256 512; do
    sips -z $size $size "$ICON_1024" --out "${ICONSET_DIR}/icon_${size}x${size}.png" >/dev/null 2>&1
    double=$((size * 2))
    sips -z $double $double "$ICON_1024" --out "${ICONSET_DIR}/icon_${size}x${size}@2x.png" >/dev/null 2>&1
done

# Generate .icns
iconutil -c icns "${ICONSET_DIR}" -o "${ICNS_FILE}"
rm -rf "${ICONSET_DIR}"

echo "==> Created ${ICNS_FILE}"
