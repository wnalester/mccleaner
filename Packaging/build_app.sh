#!/bin/bash
# Builds McCleaner and packages it into a real double-clickable .app bundle.
# We can't use xcodebuild here (only Xcode Command Line Tools are installed, no full
# Xcode), so this does by hand what Xcode would otherwise do for us.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="McCleaner"
BUNDLE_ID="com.lesterclaude.mccleaner"
OUT_DIR="$PROJECT_DIR/dist"
APP_BUNDLE="$OUT_DIR/$APP_NAME.app"

echo "Building release binary…"
cd "$PROJECT_DIR"
swift build -c release

BIN_PATH="$PROJECT_DIR/.build/release/McCleaner"
if [ ! -f "$BIN_PATH" ]; then
    echo "Build failed: binary not found at $BIN_PATH" >&2
    exit 1
fi

echo "Assembling app bundle at: $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/McCleaner"
cp "$PROJECT_DIR/Packaging/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$PROJECT_DIR/Packaging/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Copy the app's bundled resources (fonts + logo artwork) flat into Contents/Resources so
# Bundle.main can find them at runtime. These are read via Bundle.main rather than SPM's
# Bundle.module because Bundle.module's generated accessor falls back to a hardcoded path
# inside this machine's .build directory when the packaged McCleaner_*.bundle isn't found —
# fine on this Mac, but a guaranteed launch-time crash on anyone else's.
cp "$PROJECT_DIR/Sources/McCleaner/Resources/AppIcon.png" "$APP_BUNDLE/Contents/Resources/AppIcon.png"
cp "$PROJECT_DIR/Sources/McCleaner/Resources/Fonts/BricolageGrotesque.ttf" "$APP_BUNDLE/Contents/Resources/BricolageGrotesque.ttf"
cp "$PROJECT_DIR/Sources/McCleaner/Resources/Fonts/HankenGrotesk.ttf" "$APP_BUNDLE/Contents/Resources/HankenGrotesk.ttf"

DEVELOPER_ID="$(security find-identity -v -p codesigning 2>/dev/null | grep -m1 "Developer ID Application" | sed -E 's/.*"(.*)"/\1/')"

if [ -n "$DEVELOPER_ID" ]; then
    echo "Signing with Developer ID identity: $DEVELOPER_ID"
    codesign --force --deep --options runtime --timestamp --sign "$DEVELOPER_ID" "$APP_BUNDLE"

    if xcrun notarytool history --keychain-profile "mccleaner-notary" >/dev/null 2>&1; then
        echo "Zipping for notarization…"
        ZIP_PATH="$OUT_DIR/$APP_NAME-notarize.zip"
        ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

        echo "Submitting to Apple notary service (this can take a few minutes)…"
        xcrun notarytool submit "$ZIP_PATH" --keychain-profile "mccleaner-notary" --wait

        echo "Stapling notarization ticket…"
        xcrun stapler staple "$APP_BUNDLE"
        rm -f "$ZIP_PATH"

        echo ""
        echo "Done. Signed and notarized app bundle created at:"
        echo "  $APP_BUNDLE"
    else
        echo ""
        echo "Done. Signed (but NOT notarized — no 'mccleaner-notary' notarytool keychain profile"
        echo "found) app bundle created at:"
        echo "  $APP_BUNDLE"
        echo ""
        echo "To enable notarization, run once:"
        echo "  xcrun notarytool store-credentials mccleaner-notary --apple-id <you@example.com> \\"
        echo "    --team-id <TEAMID> --password <app-specific-password>"
        echo "Then re-run this script."
    fi
else
    echo "Ad-hoc code signing (no Developer ID Application certificate installed yet)…"
    codesign --force --deep --sign - "$APP_BUNDLE"

    echo ""
    echo "Done. App bundle created at:"
    echo "  $APP_BUNDLE"
    echo ""
    echo "First launch: macOS will block it because it's not from an identified developer."
    echo "Right-click (or Control-click) the app in Finder → Open → Open, once. After that"
    echo "it opens normally by double-clicking, like any other app."
fi
