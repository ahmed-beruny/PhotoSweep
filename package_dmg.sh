#!/bin/bash
set -e

APP_NAME="PhotoSweep"
DMG_NAME="PhotoSweep"
DIST_DIR="dmg_dist"

echo "=== Creating macOS DMG Installer for ${APP_NAME} ==="

# 1. First, build the fresh PhotoSweep.app bundle
echo "-> Re-packaging fresh App bundle..."
bash ./package_app.sh /Users/ahmedberuny/.gemini/antigravity-ide/brain/bfda76f9-ddad-4057-89e4-49b95d485e75/photosweep_app_icon_1779960666440.png

# Copy the fully configured, signed App bundle from /Applications into our local distribution directory
echo "-> Staging App from /Applications..."
mkdir -p "${DIST_DIR}"
cp -R "/Applications/${APP_NAME}.app" "${DIST_DIR}/"

# 2. Remove the app from /Applications (satisfying "remove it from my system")
echo "-> Cleaning up installed App from /Applications system folder..."
rm -rf "/Applications/${APP_NAME}.app"

# 3. Create a symbolic link to /Applications inside the distribution folder
echo "-> Adding /Applications symbolic link for drag-and-drop install..."
ln -s /Applications "${DIST_DIR}/Applications"

# 4. Generate the DMG file
echo "-> Building DMG Disk Image using hdiutil..."
rm -f "${DMG_NAME}.dmg"
hdiutil create -volname "${APP_NAME} Installer" -srcfolder "${DIST_DIR}" -ov -format UDZO "${DMG_NAME}.dmg"

# 5. Clean up temporary staging directory
echo "-> Cleaning up temporary distribution folders..."
rm -rf "${DIST_DIR}"

echo "=== SUCCESS! ${DMG_NAME}.dmg has been created in your workspace! ==="
