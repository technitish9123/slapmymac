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

python3 -c "
from AppKit import (NSImage, NSColor, NSBezierPath, NSFont, NSString,
                    NSMakeRect, NSBitmapImageRep, NSFontManager,
                    NSMakePoint, NSGradient)
import Foundation

W, H = 660, 400
img = NSImage.alloc().initWithSize_((W, H))
img.lockFocus()

# Dark earthy gradient background
grad = NSGradient.alloc().initWithColors_([
    NSColor.colorWithRed_green_blue_alpha_(0.10, 0.12, 0.08, 1.0),
    NSColor.colorWithRed_green_blue_alpha_(0.16, 0.18, 0.12, 1.0),
])
grad.drawInRect_angle_(NSMakeRect(0, 0, W, H), 90)

# Subtle grid lines
NSColor.colorWithRed_green_blue_alpha_(0.25, 0.30, 0.15, 0.1).setStroke()
for x in range(0, W, 40):
    p = NSBezierPath.bezierPath()
    p.moveToPoint_((x, 0))
    p.lineToPoint_((x, H))
    p.setLineWidth_(0.5)
    p.stroke()
for y in range(0, H, 40):
    p = NSBezierPath.bezierPath()
    p.moveToPoint_((0, y))
    p.lineToPoint_((W, y))
    p.setLineWidth_(0.5)
    p.stroke()

# Arrow pointing right
NSColor.colorWithRed_green_blue_alpha_(0.55, 0.62, 0.18, 0.6).setFill()
arrow = NSBezierPath.bezierPath()
# Arrow body
arrow.moveToPoint_((260, 140))
arrow.lineToPoint_((360, 140))
arrow.lineToPoint_((360, 120))
arrow.lineToPoint_((400, 155))
arrow.lineToPoint_((360, 190))
arrow.lineToPoint_((360, 170))
arrow.lineToPoint_((260, 170))
arrow.closePath()
arrow.fill()

# Title text
attrs = {
    'NSFont': NSFont.boldSystemFontOfSize_(16),
    'NSColor': NSColor.colorWithRed_green_blue_alpha_(0.78, 0.85, 0.29, 0.9),
}
s = NSString.stringWithString_('Drag SlapMyMac to Applications')
s.drawAtPoint_withAttributes_((180, 80), attrs)

# Subtitle
attrs2 = {
    'NSFont': NSFont.systemFontOfSize_(11),
    'NSColor': NSColor.colorWithRed_green_blue_alpha_(1.0, 1.0, 1.0, 0.4),
}
s2 = NSString.stringWithString_('Requires macOS 14+ with Apple Silicon')
s2.drawAtPoint_withAttributes_((210, 55), attrs2)

img.unlockFocus()

rep = NSBitmapImageRep.imageRepWithData_(img.TIFFRepresentation())
data = rep.representationUsingType_properties_(4, {})
data.writeToFile_atomically_('${BG_PATH}', True)
print('    Created DMG background')
"

# ── Step 5: Create DMG staging area ──
echo "==> Staging DMG contents..."
rm -rf "${DMG_DIR}"
mkdir -p "${DMG_DIR}"

# Copy app
cp -R "${APP_BUNDLE}" "${DMG_DIR}/"

# Create Applications symlink
ln -s /Applications "${DMG_DIR}/Applications"

# Copy background
mkdir -p "${DMG_DIR}/.background"
if [ -f "${BG_PATH}" ]; then
    cp "${BG_PATH}" "${DMG_DIR}/.background/background.png"
fi

# ── Step 6: Create DMG ──
echo "==> Creating DMG..."
rm -f "${DMG_TEMP}" "${DMG_FINAL}"

# Create temporary writable DMG
hdiutil create \
    -srcfolder "${DMG_DIR}" \
    -volname "${APP_NAME}" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size 200m \
    "${DMG_TEMP}" \
    -quiet

# Mount it
MOUNT_DIR=$(hdiutil attach -readwrite -noverify -noautoopen "${DMG_TEMP}" -quiet | grep "/Volumes/" | sed 's/.*\/Volumes/\/Volumes/')
echo "    Mounted at: ${MOUNT_DIR}"

# Wait for mount
sleep 2

# Apply visual settings via AppleScript
echo "==> Configuring DMG window appearance..."
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "${APP_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 760, 500}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 100
        try
            set background picture of viewOptions to file ".background:background.png"
        end try
        set position of item "${APP_NAME}.app" of container window to {170, 200}
        set position of item "Applications" of container window to {490, 200}
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
APPLESCRIPT

# Ensure changes are flushed
sync

# Unmount
hdiutil detach "${MOUNT_DIR}" -quiet

# Convert to compressed read-only DMG
echo "==> Compressing DMG..."
hdiutil convert "${DMG_TEMP}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${DMG_FINAL}" \
    -quiet

rm -f "${DMG_TEMP}"

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
