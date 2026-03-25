#!/usr/bin/env bash
# ============================================================
#  SlapMyMac — DMG Installer Builder
#  Creates a professional drag-to-Applications DMG installer
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="SlapMyMac"
VERSION="1.0.0"
DMG_NAME="${APP_NAME}-${VERSION}"
APP_BUNDLE="${SCRIPT_DIR}/${APP_NAME}.app"
DMG_DIR="${SCRIPT_DIR}/dmg-staging"
DMG_TEMP="${SCRIPT_DIR}/${DMG_NAME}-temp.dmg"
DMG_FINAL="${SCRIPT_DIR}/${DMG_NAME}.dmg"
SOUNDS_DIR="${SCRIPT_DIR}/Sources/${APP_NAME}/Resources/Sounds"
PLIST="${SCRIPT_DIR}/Sources/${APP_NAME}/Resources/Info.plist"
ICNS_FILE="${SCRIPT_DIR}/AppIcon.icns"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║     SlapMyMac DMG Installer Builder          ║"
echo "║     Version ${VERSION}                            ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ── Step 1: Generate icon if missing ──
if [ ! -f "${ICNS_FILE}" ]; then
    echo "==> Generating app icon..."
    bash "${SCRIPT_DIR}/create-icon.sh"
fi

# ── Step 2: Build release binary ──
echo "==> Building ${APP_NAME} (release)..."
cd "${SCRIPT_DIR}"
swift build -c release

BINARY="${SCRIPT_DIR}/.build/release/${APP_NAME}"
if [ ! -f "${BINARY}" ]; then
    echo "ERROR: Binary not found at ${BINARY}"
    exit 1
fi

# ── Step 3: Create .app bundle ──
echo "==> Creating ${APP_NAME}.app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy binary
cp "${BINARY}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Copy Info.plist
cp "${PLIST}" "${APP_BUNDLE}/Contents/Info.plist"

# Copy icon
if [ -f "${ICNS_FILE}" ]; then
    cp "${ICNS_FILE}" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
    echo "    ✓ App icon"
fi

# Copy sounds
if [ -d "${SOUNDS_DIR}" ]; then
    cp -R "${SOUNDS_DIR}" "${APP_BUNDLE}/Contents/Resources/Sounds"
    SOUND_COUNT=$(find "${APP_BUNDLE}/Contents/Resources/Sounds" -type f | wc -l | tr -d ' ')
    echo "    ✓ ${SOUND_COUNT} sound files"
fi

# Copy SwiftPM resource bundle
RESOURCE_BUNDLE="${SCRIPT_DIR}/.build/release/SlapMyMac_SlapMyMac.bundle"
if [ -d "${RESOURCE_BUNDLE}" ]; then
    cp -R "${RESOURCE_BUNDLE}" "${APP_BUNDLE}/Contents/Resources/"
    echo "    ✓ SwiftPM resource bundle"
fi

# Create launcher script that requests sudo
cat > "${APP_BUNDLE}/Contents/MacOS/SlapMyMac-Launcher" <<'LAUNCHER'
#!/bin/bash
# SlapMyMac needs root access for the accelerometer
DIR="$(cd "$(dirname "$0")" && pwd)"
BINARY="${DIR}/SlapMyMac"

# Check if already root
if [ "$(id -u)" = "0" ]; then
    exec "${BINARY}"
else
    # Use osascript to get admin privileges
    osascript -e "do shell script \"'${BINARY}' &\" with administrator privileges"
fi
LAUNCHER
chmod +x "${APP_BUNDLE}/Contents/MacOS/SlapMyMac-Launcher"

echo "    ✓ App bundle created"

# ── Step 4: Create DMG background ──
echo "==> Creating DMG background..."
BG_PATH="/tmp/slapmac_dmg_bg.png"
BG_SWIFT="/tmp/slapmac_dmg_bg.swift"

cat > "${BG_SWIFT}" <<'BGSWIFT'
import AppKit

let W: CGFloat = 660
let H: CGFloat = 400
let img = NSImage(size: NSSize(width: W, height: H))
img.lockFocus()

// Dark earthy gradient
let grad = NSGradient(colors: [
    NSColor(red: 0.10, green: 0.12, blue: 0.08, alpha: 1),
    NSColor(red: 0.16, green: 0.18, blue: 0.12, alpha: 1)
])!
grad.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: 90)

// Subtle grid
NSColor(red: 0.25, green: 0.30, blue: 0.15, alpha: 0.1).setStroke()
for x in stride(from: 0, to: Int(W), by: 40) {
    let p = NSBezierPath()
    p.move(to: NSPoint(x: x, y: 0))
    p.line(to: NSPoint(x: x, y: Int(H)))
    p.lineWidth = 0.5
    p.stroke()
}
for y in stride(from: 0, to: Int(H), by: 40) {
    let p = NSBezierPath()
    p.move(to: NSPoint(x: 0, y: y))
    p.line(to: NSPoint(x: Int(W), y: y))
    p.lineWidth = 0.5
    p.stroke()
}

// Arrow
NSColor(red: 0.55, green: 0.62, blue: 0.18, alpha: 0.6).setFill()
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 260, y: 140))
arrow.line(to: NSPoint(x: 360, y: 140))
arrow.line(to: NSPoint(x: 360, y: 120))
arrow.line(to: NSPoint(x: 400, y: 155))
arrow.line(to: NSPoint(x: 360, y: 190))
arrow.line(to: NSPoint(x: 360, y: 170))
arrow.line(to: NSPoint(x: 260, y: 170))
arrow.close()
arrow.fill()

// Title
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.boldSystemFont(ofSize: 16),
    .foregroundColor: NSColor(red: 0.78, green: 0.85, blue: 0.29, alpha: 0.9)
]
NSAttributedString(string: "Drag SlapMyMac to Applications", attributes: attrs)
    .draw(at: NSPoint(x: 180, y: 80))

// Subtitle
let attrs2: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 11),
    .foregroundColor: NSColor(red: 1, green: 1, blue: 1, alpha: 0.4)
]
NSAttributedString(string: "Requires macOS 14+ with Apple Silicon", attributes: attrs2)
    .draw(at: NSPoint(x: 210, y: 55))

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { exit(1) }

let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/slapmac_dmg_bg.png"
try! png.write(to: URL(fileURLWithPath: path))
print("    Created DMG background")
BGSWIFT

swiftc "${BG_SWIFT}" -framework AppKit -o /tmp/slapmac_bggen
/tmp/slapmac_bggen "${BG_PATH}"

# (old python block removed - using Swift above)

# ── Step 5: Create DMG directly ──
echo "==> Staging DMG contents..."
rm -rf "${DMG_DIR}"
mkdir -p "${DMG_DIR}"

# Copy app
cp -R "${APP_BUNDLE}" "${DMG_DIR}/"

# Create Applications symlink
ln -s /Applications "${DMG_DIR}/Applications"

# ── Step 6: Create compressed DMG ──
echo "==> Creating DMG..."
rm -f "${DMG_FINAL}"

hdiutil create \
    -srcfolder "${DMG_DIR}" \
    -volname "${APP_NAME}" \
    -fs HFS+ \
    -format UDZO \
    -imagekey zlib-level=9 \
    "${DMG_FINAL}"

# ── Step 7: Cleanup ──
rm -rf "${DMG_DIR}"

# Get file size
DMG_SIZE=$(du -sh "${DMG_FINAL}" | cut -f1)

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  ✅  DMG Created Successfully!               ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  File: ${DMG_NAME}.dmg"
echo "║  Size: ${DMG_SIZE}"
echo "║  Path: ${DMG_FINAL}"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "To install:"
echo "  1. Double-click ${DMG_NAME}.dmg"
echo "  2. Drag SlapMyMac to Applications"
echo "  3. Run: sudo /Applications/${APP_NAME}.app/Contents/MacOS/${APP_NAME}"
echo ""
echo "Note: The app requires sudo for accelerometer access."
echo "First launch will request admin password."
echo ""
