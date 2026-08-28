#!/bin/bash
# Builds SystemDataCleaner and packages it into a real double-clickable .app bundle.
# We can't use xcodebuild here (only Xcode Command Line Tools are installed, no full
# Xcode), so this does by hand what Xcode would otherwise do for us.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SDC"
BUNDLE_ID="com.lesterclaude.systemdatacleaner"
OUT_DIR="$PROJECT_DIR/dist"
APP_BUNDLE="$OUT_DIR/$APP_NAME.app"

echo "Building release binary…"
cd "$PROJECT_DIR"
swift build -c release

BIN_PATH="$PROJECT_DIR/.build/release/SystemDataCleaner"
if [ ! -f "$BIN_PATH" ]; then
    echo "Build failed: binary not found at $BIN_PATH" >&2
    exit 1
fi

echo "Assembling app bundle at: $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/SystemDataCleaner"
cp "$PROJECT_DIR/Packaging/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$PROJECT_DIR/Packaging/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

echo "Ad-hoc code signing (no Apple Developer account needed for local use)…"
codesign --force --deep --sign - "$APP_BUNDLE"

echo ""
echo "Done. App bundle created at:"
echo "  $APP_BUNDLE"
echo ""
echo "First launch: macOS will block it because it's not from an identified developer."
echo "Right-click (or Control-click) the app in Finder → Open → Open, once. After that"
echo "it opens normally by double-clicking, like any other app."
