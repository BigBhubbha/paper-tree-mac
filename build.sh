#!/bin/bash
# Builds "Paper Tree.app" without Xcode. Needs the Command Line Tools (xcode-select --install).
#   ./build.sh            build a release app into ./build/Paper Tree.app
#   ./build.sh --run      build, then open it
#   ./build.sh --install  build, then copy it to /Applications
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Paper Tree"
EXEC="PaperTree"
BUNDLE_ID="com.papertree.mac"
OUT="build"
APP="$OUT/$APP_NAME.app"

if [[ "$(uname)" != "Darwin" ]]; then
  echo "This builds a Mac app, so run it on a Mac." >&2
  exit 1
fi
if ! command -v swift >/dev/null 2>&1; then
  echo "Swift is missing. Run: xcode-select --install" >&2
  exit 1
fi

# UNIVERSAL=1 ./build.sh builds one app for both Apple Silicon and Intel (used by GitHub Actions).
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  ARCH_FLAGS=(--arch arm64 --arch x86_64)
  echo "==> Compiling (universal: arm64 + x86_64, release)"
else
  ARCH_FLAGS=(--arch "$(uname -m)")   # arm64 on Apple Silicon, x86_64 on Intel
  echo "==> Compiling ($(uname -m), release)"
fi
swift build -c release "${ARCH_FLAGS[@]}"
BIN_DIR="$(swift build -c release "${ARCH_FLAGS[@]}" --show-bin-path)"

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Fonts" "$APP/Contents/Frameworks"
cp "$BIN_DIR/$EXEC" "$APP/Contents/MacOS/$EXEC"
cp Resources/Info.plist "$APP/Contents/Info.plist"
# CI passes BUILD_NUMBER so every release has a higher CFBundleVersion (Sparkle compares this number).
if [[ -n "${BUILD_NUMBER:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
fi

# Sparkle (the updater) ships as a prebuilt framework. SwiftPM links it but does not embed it,
# so copy it into Contents/Frameworks (ditto keeps its internal symlinks) and add that folder to the rpath.
SPARKLE_FW=""
for candidate in \
    "$BIN_DIR/Sparkle.framework" \
    "$BIN_DIR/PackageFrameworks/Sparkle.framework" \
    $(find .build/artifacts -type d -path "*Sparkle.xcframework/macos-*/Sparkle.framework" 2>/dev/null); do
  if [[ -d "$candidate" ]]; then SPARKLE_FW="$candidate"; break; fi
done
if [[ -z "$SPARKLE_FW" ]]; then
  echo "Could not find Sparkle.framework after the build." >&2
  exit 1
fi
echo "==> Embedding $SPARKLE_FW"
ditto "$SPARKLE_FW" "$APP/Contents/Frameworks/Sparkle.framework"
if ! otool -l "$APP/Contents/MacOS/$EXEC" | grep -q "@executable_path/../Frameworks"; then
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/$EXEC"
fi
cp Resources/Fonts/*.ttf "$APP/Contents/Resources/Fonts/"
cp Resources/Fonts/*.txt Resources/Fonts/*.md "$APP/Contents/Resources/Fonts/" 2>/dev/null || true

# App icon: rebuild from the iconset with Apple's iconutil if possible, else use the prebuilt file.
if command -v iconutil >/dev/null 2>&1 && [[ -d Resources/AppIcon.iconset ]]; then
  iconutil -c icns Resources/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns" 2>/dev/null \
    || cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
else
  cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi
printf "APPL????" > "$APP/Contents/PkgInfo"

# Signing. CI sets SIGN_IDENTITY to the SHA-1 of the long-lived "Paper Tree Signing" certificate
# (imported into a temporary keychain). The app then gets a fixed designated requirement
# (bundle id + that certificate), so macOS keeps Accessibility permission across updates.
# Without SIGN_IDENTITY (a local build) everything is signed ad hoc, like before.
SIGN="${SIGN_IDENTITY:--}"
KEYCHAIN_ARGS=()
if [[ -n "${SIGN_KEYCHAIN:-}" ]]; then KEYCHAIN_ARGS=(--keychain "$SIGN_KEYCHAIN"); fi
if [[ "$SIGN" == "-" ]]; then
  echo "==> Signing (ad hoc)"
else
  echo "==> Signing with certificate $SIGN"
fi
# Inside out: Sparkle's helpers, then the framework, then the app.
SP="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
for item in "$SP/XPCServices/Installer.xpc" "$SP/XPCServices/Downloader.xpc" "$SP/Autoupdate" "$SP/Updater.app"; do
  if [[ -e "$item" ]]; then
    codesign --force --sign "$SIGN" ${KEYCHAIN_ARGS[@]+"${KEYCHAIN_ARGS[@]}"} --timestamp=none --preserve-metadata=identifier,entitlements "$item"
  fi
done
codesign --force --sign "$SIGN" ${KEYCHAIN_ARGS[@]+"${KEYCHAIN_ARGS[@]}"} --timestamp=none "$APP/Contents/Frameworks/Sparkle.framework"
if [[ "$SIGN" == "-" ]]; then
  codesign --force --sign - --identifier "$BUNDLE_ID" --timestamp=none "$APP"
else
  REQ="designated => identifier \"$BUNDLE_ID\" and certificate leaf = H\"$SIGN\""
  codesign --force --sign "$SIGN" ${KEYCHAIN_ARGS[@]+"${KEYCHAIN_ARGS[@]}"} --identifier "$BUNDLE_ID" --timestamp=none \
    --requirements "=$REQ" "$APP"
fi
codesign --verify --verbose=1 "$APP" || true

echo ""
echo "Built: $(pwd)/$APP"
if [[ "$SIGN" == "-" ]]; then
  echo "Note: ad hoc builds look like a new app to macOS after every rebuild. If highlights stop working,"
  echo "open System Settings > Privacy & Security > Accessibility, remove Paper Tree (minus), and add it again."
fi

case "${1:-}" in
  --run)
    pkill -x "$EXEC" 2>/dev/null || true
    open "$APP"
    ;;
  --install)
    pkill -x "$EXEC" 2>/dev/null || true
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP" "/Applications/"
    echo "Installed to /Applications/$APP_NAME.app"
    open "/Applications/$APP_NAME.app"
    ;;
esac
