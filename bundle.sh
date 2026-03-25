#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="SlapMyMac"
APP_BUNDLE="${SCRIPT_DIR}/${APP_NAME}.app"
BUILD_DIR="${SCRIPT_DIR}/.build/release"
BINARY="${BUILD_DIR}/${APP_NAME}"
PLIST="${SCRIPT_DIR}/Sources/${APP_NAME}/Resources/Info.plist"
SOUNDS_DIR="${SCRIPT_DIR}/Sources/${APP_NAME}/Resources/Sounds"

echo "==> Building ${APP_NAME} (release)..."
cd "${SCRIPT_DIR}"
swift build -c release

if [ ! -f "${BINARY}" ]; then
    echo "ERROR: Binary not found at ${BINARY}"
    exit 1
fi

echo "==> Creating app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

echo "==> Copying binary..."
cp "${BINARY}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

echo "==> Copying Info.plist..."
cp "${PLIST}" "${APP_BUNDLE}/Contents/Info.plist"

echo "==> Copying sound resources..."
if [ -d "${SOUNDS_DIR}" ]; then
    cp -R "${SOUNDS_DIR}" "${APP_BUNDLE}/Contents/Resources/Sounds"
    echo "    Copied $(find "${APP_BUNDLE}/Contents/Resources/Sounds" -type f | wc -l | tr -d ' ') sound files"
else
    echo "    No sounds directory found, skipping"
fi

# Also copy the SwiftPM resource bundle (needed for Bundle.module to work)
RESOURCE_BUNDLE="${BUILD_DIR}/SlapMyMac_SlapMyMac.bundle"
if [ -d "${RESOURCE_BUNDLE}" ]; then
    cp -R "${RESOURCE_BUNDLE}" "${APP_BUNDLE}/Contents/Resources/"
    echo "    Copied SwiftPM resource bundle"
fi

echo ""
echo "==> Build complete!"
echo "    ${APP_BUNDLE}"
echo ""
echo "To run (requires sudo for accelerometer access):"
echo "    sudo open ${APP_BUNDLE}"
echo ""
echo "Or to run directly:"
echo "    sudo ${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
