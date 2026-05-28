# PhotoSweep ✦ Premium Native macOS Photo Cleaner

**PhotoSweep** is a native macOS application designed to help photographers rapidly inspect, clean up, and organize directories. Built with **100% pure Swift and SwiftUI**, it offers peak machine-code performance, instant launches, and ultra-low system overhead compared to traditional web-wrapped tools.

![PhotoSweep App Icon](file:///Users/ahmedberuny/.gemini/antigravity-ide/brain/bfda76f9-ddad-4057-89e4-49b95d485e75/photosweep_app_icon_1779960666440.png)

---

## Key Features

* 🚀 **Pure Swift & SwiftUI**: Native macOS binary with zero Electron/Node.js dependencies. Fast, efficient, and lightweight.
* 📷 **Camera RAW + preview pairing**: Sony Alpha Raw (`.arw`) files are linked with standard JPEG/HEIC counterparts. Review standard files for speed, and PhotoSweep will automatically delete or preserve both files together!
* ♻️ **Native Trash Recycling**: Integrates directly with standard macOS system Trash (`FileManager.default.trashItem`) so files are never deleted permanently without a backup.
* 🔄 **Natively Undo Delete**: Changed your mind? Press `Cmd + Z` or `↑` to instantly move the standard image and its RAW pair back from the macOS Trash folder and restore your stats!
* 💾 **Removable Volume Auto-Discovery**: Removable SD cards and camera cards appear instantly in your sidebar with dedicated icons (`sdcard`), updating dynamically as you connect or eject them.
* 🤏 **Liquid Trackpad Gestures**: Pinch-to-zoom directly on your trackpad to inspect fine details, panning smoothly with your trackpad/mouse when zoomed.
* ⌨️ **Robust Keyboard Shortcuts**: Swift local AppKit keystroke monitors let you control the app globally:
  - <kbd>A</kbd> / <kbd>←</kbd>: Trash Photo
  - <kbd>D</kbd> / <kbd>→</kbd> / <kbd>Space</kbd>: Keep Photo & Advance
  - <kbd>Cmd + Z</kbd> / <kbd>W</kbd> / <kbd>↑</kbd>: Undo / Go Back
  - <kbd>Escape</kbd>: Navigate Up in File Explorer
  - <kbd>⌥ + O</kbd>: Reveal in macOS Finder
* 📁 **Autofocus Sidebar Navigation**: The sidebar automatically centers and scrolls your active loaded photos folder (badged `"ACTIVE"`) or the folder you just returned from into view using automated scroll triggers.

---

## Technical Overview

* **Source File**: `main.swift` (contains the complete SwiftUI application architecture, state engine, and event monitor).
* **Bundle Creator**: `package_app.sh` (packages the compiled binary into a standard `.app` bundle, generates a Retina-ready `.icns` iconset from PNG, configures plist metadata, and ad-hoc signs).
* **DMG Packager**: `package_dmg.sh` (builds the signed app bundle and compiles it into a standard compressed macOS `PhotoSweep.dmg` installer with drag-and-drop links).

---

## Compilation and Build Instructions

You can easily compile, sign, and launch or package the application natively from your terminal:

### 1. Compile and Run Local Binary (For Testing)
```bash
# Compile main.swift into a native binary
swiftc -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -parse-as-library -O main.swift -o PhotoSweep

# Ad-hoc sign (Required on Apple Silicon)
codesign --force --deep --sign - PhotoSweep

# Launch the app
./PhotoSweep
```

### 2. Package as a Native macOS Application (`.app`)
```bash
# This creates PhotoSweep.app, builds AppIcon.icns, signs it, and installs it in /Applications/
bash ./package_app.sh path/to/icon.png
```

### 3. Generate the DMG Installer Disk Image
```bash
# This builds, signs, and generates a drag-and-drop PhotoSweep.dmg installer in your root folder
bash ./package_dmg.sh
```

---

## Licensing & Workspace Info

* **Developer Workspace**: `/Users/ahmedberuny/Dev/myProjects/FastPhoteCleaner`
* **Target Build**: Apple Silicon / Intel macOS (Universal)
* **Minimum macOS Target**: macOS 12.0 Monterey
