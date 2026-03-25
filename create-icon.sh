#!/usr/bin/env bash
# Generate AppIcon.icns for SlapMyMac using Swift
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ICONSET_DIR="${SCRIPT_DIR}/AppIcon.iconset"
ICNS_FILE="${SCRIPT_DIR}/AppIcon.icns"
ICON_1024="/tmp/slapmac_icon_1024.png"
SWIFT_GEN="/tmp/slapmac_icongen.swift"

echo "==> Generating app icon..."

cat > "${SWIFT_GEN}" <<'SWIFTEOF'
import AppKit

let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()

// Olive green gradient background
let bg = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size), xRadius: 200, yRadius: 200)
let gradient = NSGradient(colors: [
    NSColor(red: 0.22, green: 0.28, blue: 0.08, alpha: 1),
    NSColor(red: 0.32, green: 0.40, blue: 0.14, alpha: 1)
])!
gradient.draw(in: bg, angle: -45)

// Inner glow border
let inner = NSBezierPath(roundedRect: NSRect(x: 8, y: 8, width: size - 16, height: size - 16), xRadius: 196, yRadius: 196)
NSColor(red: 0.55, green: 0.62, blue: 0.18, alpha: 0.25).setStroke()
inner.lineWidth = 4
inner.stroke()

// Hand emoji
let handAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 480)
]
let hand = NSAttributedString(string: "\u{1F91A}", attributes: handAttrs)
hand.draw(at: NSPoint(x: 210, y: 220))

// "SLAP!" text
let textAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.boldSystemFont(ofSize: 120),
    .foregroundColor: NSColor(red: 0.78, green: 0.85, blue: 0.29, alpha: 1.0)
]
let slap = NSAttributedString(string: "SLAP!", attributes: textAttrs)
slap.draw(at: NSPoint(x: 265, y: 50))

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    print("ERROR: Failed to generate PNG")
    exit(1)
}

let url = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/slapmac_icon_1024.png")
try! png.write(to: url)
print("Created icon at \(url.path)")
SWIFTEOF

swiftc "${SWIFT_GEN}" -framework AppKit -o /tmp/slapmac_icongen
/tmp/slapmac_icongen "${ICON_1024}"

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
