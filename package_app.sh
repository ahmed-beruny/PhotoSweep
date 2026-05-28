#!/bin/bash
set -e

APP_NAME="PhotoSweep"
BUNDLE_DIR="${APP_NAME}.app"
ICON_SOURCE_PNG="$1" # Pass the source PNG path as the first argument

echo "=== Packaging ${APP_NAME} into a native macOS Application ==="

# 1. Compile the main.swift file
echo "-> Compiling main.swift..."
swiftc -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -parse-as-library -O main.swift -o "${APP_NAME}_bin"

# 2. Create the directory structures
echo "-> Creating application bundle folder..."
mkdir -p "${BUNDLE_DIR}/Contents/MacOS"
mkdir -p "${BUNDLE_DIR}/Contents/Resources"

# 3. Move the binary into the bundle
mv "${APP_NAME}_bin" "${BUNDLE_DIR}/Contents/MacOS/${APP_NAME}"

# 4. Generate AppIcon.icns if PNG is provided
if [ -n "${ICON_SOURCE_PNG}" ] && [ -f "${ICON_SOURCE_PNG}" ]; then
    echo "-> Generating native AppIcon.icns from ${ICON_SOURCE_PNG}..."
    ICONSET_DIR="AppIcon.iconset"
    mkdir -p "${ICONSET_DIR}"
    
    # Generate all Apple standard resolution icons using native sips forcing png output
    sips -s format png -z 16 16     "${ICON_SOURCE_PNG}" --out "${ICONSET_DIR}/icon_16x16.png" > /dev/null
    sips -s format png -z 32 32     "${ICON_SOURCE_PNG}" --out "${ICONSET_DIR}/icon_16x16@2x.png" > /dev/null
    sips -s format png -z 32 32     "${ICON_SOURCE_PNG}" --out "${ICONSET_DIR}/icon_32x32.png" > /dev/null
    sips -s format png -z 64 64     "${ICON_SOURCE_PNG}" --out "${ICONSET_DIR}/icon_32x32@2x.png" > /dev/null
    sips -s format png -z 128 128   "${ICON_SOURCE_PNG}" --out "${ICONSET_DIR}/icon_128x128.png" > /dev/null
    sips -s format png -z 256 256   "${ICON_SOURCE_PNG}" --out "${ICONSET_DIR}/icon_128x128@2x.png" > /dev/null
    sips -s format png -z 256 256   "${ICON_SOURCE_PNG}" --out "${ICONSET_DIR}/icon_256x256.png" > /dev/null
    sips -s format png -z 512 512   "${ICON_SOURCE_PNG}" --out "${ICONSET_DIR}/icon_256x256@2x.png" > /dev/null
    sips -s format png -z 512 512   "${ICON_SOURCE_PNG}" --out "${ICONSET_DIR}/icon_512x512.png" > /dev/null
    sips -s format png -z 1024 1024 "${ICON_SOURCE_PNG}" --out "${ICONSET_DIR}/icon_512x512@2x.png" > /dev/null
    
    # Run native iconutil compiler
    iconutil -c icns "${ICONSET_DIR}" --o "${BUNDLE_DIR}/Contents/Resources/AppIcon.icns"
    rm -rf "${ICONSET_DIR}"
    echo "✓ AppIcon.icns successfully built!"
fi

# 5. Create the Info.plist with AppIcon key
echo "-> Generating Info.plist..."
cat <<EOF > "${BUNDLE_DIR}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.beruny.${APP_NAME}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

# 6. Ad-hoc codesign the entire bundle
echo "-> Applying ad-hoc code-signing to the bundle..."
codesign --force --deep --sign - "${BUNDLE_DIR}"

# 7. Copy to /Applications
echo "-> Copying to /Applications folder..."
cp -R "${BUNDLE_DIR}" /Applications/

# 8. Clean up local app bundle output to avoid cluttering local indexes
rm -rf "${BUNDLE_DIR}"

echo "=== SUCCESS! ${APP_NAME}.app with native App Icon is now in your /Applications list! ==="
