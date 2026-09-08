#!/bin/bash
# Builds a LOCAL-ONLY test copy of McCleaner with the payment gate bypassed (every clean
# reports as "lifetime", no Stripe involved) so you can verify scan+clean actually works
# without spending real money each time. Compiled with the QA_BUILD flag, which only this
# script ever passes — build_app.sh (the real, shippable build) never does, so the public
# download can never accidentally ship with the paywall bypassed.
#
# Ad-hoc signed only, never notarized — this is for running on this Mac, not distributing.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="McCleaner-QA"
OUT_DIR="$PROJECT_DIR/dist"
APP_BUNDLE="$OUT_DIR/$APP_NAME.app"

echo "Building QA binary (payment gate bypassed)…"
cd "$PROJECT_DIR"
swift build -c release -Xswiftc -DQA_BUILD

BIN_PATH="$PROJECT_DIR/.build/release/McCleaner"
if [ ! -f "$BIN_PATH" ]; then
    echo "Build failed: binary not found at $BIN_PATH" >&2
    exit 1
fi

echo "Assembling app bundle at: $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$PROJECT_DIR/Packaging/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$PROJECT_DIR/Packaging/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
cp "$PROJECT_DIR/Sources/McCleaner/Resources/AppIcon.png" "$APP_BUNDLE/Contents/Resources/AppIcon.png"
cp "$PROJECT_DIR/Sources/McCleaner/Resources/Fonts/BricolageGrotesque.ttf" "$APP_BUNDLE/Contents/Resources/BricolageGrotesque.ttf"
cp "$PROJECT_DIR/Sources/McCleaner/Resources/Fonts/HankenGrotesk.ttf" "$APP_BUNDLE/Contents/Resources/HankenGrotesk.ttf"

# CFBundleExecutable in Info.plist says "McCleaner" — rename the binary to match so macOS
# can actually launch it, while the bundle+display name stay "McCleaner-QA" so it's never
# confused with the real app in Finder/Dock.
mv "$APP_BUNDLE/Contents/MacOS/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/McCleaner"
plutil -replace CFBundleName -string "$APP_NAME" "$APP_BUNDLE/Contents/Info.plist"
plutil -replace CFBundleDisplayName -string "$APP_NAME" "$APP_BUNDLE/Contents/Info.plist"

codesign --force --deep --sign - "$APP_BUNDLE"

echo ""
echo "Done. QA app bundle (payment gate bypassed) created at:"
echo "  $APP_BUNDLE"
echo ""
echo "First launch: right-click → Open → Open once (ad-hoc signed, not notarized)."
echo "This is for testing on this Mac only — never distribute this build."
