#!/usr/bin/env bash
# scripts/package_app.sh
# Packages "Mole for Mac" native macOS application bundle into dist/Mole for Mac.app
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$REPO_ROOT/dist"
APP_NAME="Mole for Mac"
BUNDLE_DIR="$DIST_DIR/$APP_NAME.app"
TMP_BUILD_HOME="${TMPDIR:-/tmp}/mole_package_home"
mkdir -p "$TMP_BUILD_HOME"

echo "=== Packaging $APP_NAME ==="

# 1. Compile Swift packages in Release mode
echo "==> Compiling native Swift binaries in Release mode..."
HOME="$TMP_BUILD_HOME" TMPDIR="${TMPDIR:-/tmp}" CLANG_MODULE_CACHE_PATH="/tmp/clang-cache" \
    swift build -c release --disable-sandbox --package-path "$REPO_ROOT/App"

BIN_DIR="$REPO_ROOT/App/.build/release"
if [[ ! -f "$BIN_DIR/MoleApp" ]]; then
    echo "ERROR: MoleApp binary not found at $BIN_DIR/MoleApp" >&2
    exit 1
fi

if [[ ! -f "$BIN_DIR/MoleHelperDaemon" ]]; then
    echo "ERROR: MoleHelperDaemon binary not found at $BIN_DIR/MoleHelperDaemon" >&2
    exit 1
fi

# 2. Ensure AppIcon.icns exists
if [[ ! -f "$REPO_ROOT/App/Resources/AppIcon.icns" ]]; then
    echo "==> Generating AppIcon.icns from docs/img/big-mole.png..."
    ICONSET_DIR="/tmp/mole_iconset_$$"
    mkdir -p "$ICONSET_DIR" "$REPO_ROOT/App/Resources"
    sips -z 16 16     "$REPO_ROOT/docs/img/big-mole.png" --out "$ICONSET_DIR/icon_16x16.png" > /dev/null
    sips -z 32 32     "$REPO_ROOT/docs/img/big-mole.png" --out "$ICONSET_DIR/icon_16x16@2x.png" > /dev/null
    sips -z 32 32     "$REPO_ROOT/docs/img/big-mole.png" --out "$ICONSET_DIR/icon_32x32.png" > /dev/null
    sips -z 64 64     "$REPO_ROOT/docs/img/big-mole.png" --out "$ICONSET_DIR/icon_32x32@2x.png" > /dev/null
    sips -z 128 128   "$REPO_ROOT/docs/img/big-mole.png" --out "$ICONSET_DIR/icon_128x128.png" > /dev/null
    sips -z 256 256   "$REPO_ROOT/docs/img/big-mole.png" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null
    sips -z 256 256   "$REPO_ROOT/docs/img/big-mole.png" --out "$ICONSET_DIR/icon_256x256.png" > /dev/null
    sips -z 512 512   "$REPO_ROOT/docs/img/big-mole.png" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null
    sips -z 512 512   "$REPO_ROOT/docs/img/big-mole.png" --out "$ICONSET_DIR/icon_512x512.png" > /dev/null
    sips -z 1024 1024 "$REPO_ROOT/docs/img/big-mole.png" --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null
    iconutil -c icns "$ICONSET_DIR" -o "$REPO_ROOT/App/Resources/AppIcon.icns"
    rm -rf "$ICONSET_DIR" # SAFE: Clean up temporary iconset staging directory in /tmp
fi

# 3. Assemble .app bundle directory structure
echo "==> Assembling .app bundle at $BUNDLE_DIR..."
rm -rf "$BUNDLE_DIR" # SAFE: Remove previous build bundle before fresh packaging in dist/
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"
mkdir -p "$BUNDLE_DIR/Contents/Library/LaunchDaemons"
mkdir -p "$BUNDLE_DIR/Contents/Library/LaunchServices"

cp "$REPO_ROOT/App/Info.plist" "$BUNDLE_DIR/Contents/Info.plist"
cp "$BIN_DIR/MoleApp" "$BUNDLE_DIR/Contents/MacOS/MoleApp"
cp "$BIN_DIR/MoleHelperDaemon" "$BUNDLE_DIR/Contents/Library/LaunchServices/com.mole.helper"
cp "$REPO_ROOT/App/Sources/MoleHelper/LaunchDaemons/com.mole.helper.plist" "$BUNDLE_DIR/Contents/Library/LaunchDaemons/com.mole.helper.plist"
cp "$REPO_ROOT/App/Resources/AppIcon.icns" "$BUNDLE_DIR/Contents/Resources/AppIcon.icns"

# Copy CLI engine assets into Contents/Resources/mole-engine
ENGINE_DEST="$BUNDLE_DIR/Contents/Resources/mole-engine"
mkdir -p "$ENGINE_DEST"
cp -R "$REPO_ROOT/lib" "$ENGINE_DEST/lib"
cp -R "$REPO_ROOT/adapters" "$ENGINE_DEST/adapters"
mkdir -p "$ENGINE_DEST/bin"
cp "$REPO_ROOT/bin"/*.sh "$ENGINE_DEST/bin/"
if [[ -f "$REPO_ROOT/bin/analyze-go" ]]; then
    cp "$REPO_ROOT/bin/analyze-go" "$ENGINE_DEST/bin/"
fi
if [[ -f "$REPO_ROOT/bin/status-go" ]]; then
    cp "$REPO_ROOT/bin/status-go" "$ENGINE_DEST/bin/"
fi
if [[ -f "$REPO_ROOT/mole" ]]; then
    cp "$REPO_ROOT/mole" "$ENGINE_DEST/mole"
    chmod +x "$ENGINE_DEST/mole"
fi
chmod -R +x "$ENGINE_DEST/bin" "$ENGINE_DEST/adapters"

chmod +x "$BUNDLE_DIR/Contents/MacOS/MoleApp"
chmod +x "$BUNDLE_DIR/Contents/Library/LaunchServices/com.mole.helper"

# 4. Sign with ad-hoc code signature
echo "==> Applying ad-hoc code signature..."
codesign --force --options runtime --sign - "$BUNDLE_DIR/Contents/Library/LaunchServices/com.mole.helper"
codesign --force --options runtime --sign - "$BUNDLE_DIR"

# 5. Verify signature
codesign --verify --deep --strict "$BUNDLE_DIR"
echo "✔ Code signature verified."

# 6. Create distribution zip archive
echo "==> Creating distribution zip archive..."
VERSION="$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^V//' || echo "1.62.1")"
ZIP_NAME="Mole-for-Mac-${VERSION}.zip"
(cd "$DIST_DIR" && rm -f "$ZIP_NAME" && zip -q -r -y "$ZIP_NAME" "$APP_NAME.app")

echo "✔ Application package complete: $BUNDLE_DIR"
echo "✔ Distribution archive: $DIST_DIR/$ZIP_NAME"
ls -lh "$DIST_DIR/$ZIP_NAME"
