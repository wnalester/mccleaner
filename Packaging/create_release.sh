#!/bin/bash
# Zips the built app bundle and publishes it as a GitHub Release asset on
# wnalester/system-data-cleaner, so the landing page has a real download URL.
#
# Prerequisite: run build_app.sh first, and ideally with a Developer ID
# signature + notarization (an ad-hoc signed build will be hard-blocked by
# Gatekeeper for anyone who isn't this machine).
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="McCleaner"
OUT_DIR="$PROJECT_DIR/dist"
APP_BUNDLE="$OUT_DIR/$APP_NAME.app"
VERSION="${1:-}"

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>   e.g. $0 v1.0.0" >&2
    exit 1
fi

if [ ! -d "$APP_BUNDLE" ]; then
    echo "No app bundle at $APP_BUNDLE — run build_app.sh first." >&2
    exit 1
fi

if ! codesign -dv "$APP_BUNDLE" 2>&1 | grep -q "Authority=Developer ID Application"; then
    echo "WARNING: $APP_BUNDLE is not Developer ID signed (ad-hoc or unsigned)." >&2
    echo "Anyone who downloads this will hit a hard Gatekeeper block, not just a" >&2
    echo "right-click-to-open warning. Recommended: get a cert, re-run build_app.sh," >&2
    echo "then this script. Continuing anyway since you asked to run this directly." >&2
fi

ZIP_PATH="$OUT_DIR/$APP_NAME-$VERSION.zip"
echo "Zipping $APP_BUNDLE -> $ZIP_PATH"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "Publishing GitHub release $VERSION on wnalester/system-data-cleaner…"
gh release create "$VERSION" "$ZIP_PATH" \
    --repo wnalester/system-data-cleaner \
    --title "McCleaner $VERSION" \
    --notes "McCleaner (System Data Cleaner) $VERSION." \
    --latest

echo ""
echo "Download URL:"
echo "  https://github.com/wnalester/system-data-cleaner/releases/download/$VERSION/$APP_NAME-$VERSION.zip"
