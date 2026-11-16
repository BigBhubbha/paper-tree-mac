#!/bin/bash
# Fetches the prebuilt sherpa-onnx dylibs (Kokoro voices) into Vendor/sherpa-onnx/lib.
# Universal (arm64 + x86_64), v2.0.1, Apache 2.0. Checked against a pinned SHA-256.
# This build has no espeak-ng inside; Paper Tree does its own phonemes.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="2.0.1"
NAME="sherpa-onnx-v$VERSION-osx-universal2-shared-lib"
SHA="a3aa3e8a6c78bc06d98f8a5792a924e3d2a7c308c76db68aef358b9278366ac7"
DEST="Vendor/sherpa-onnx"
if [[ -f "$DEST/lib/libsherpa-onnx-c-api.dylib" && -f "$DEST/lib/libonnxruntime.dylib" && "$(cat "$DEST/VERSION" 2>/dev/null)" == "$VERSION" ]]; then
  exit 0
fi
mkdir -p "$DEST"
TMP="$(mktemp -d)"
curl -fsSL --retry 3 -o "$TMP/$NAME.tar.bz2" "https://github.com/k2-fsa/sherpa-onnx/releases/download/v$VERSION/$NAME.tar.bz2"
GOT="$(shasum -a 256 "$TMP/$NAME.tar.bz2" | cut -d' ' -f1)"
if [[ "$GOT" != "$SHA" ]]; then echo "sherpa-onnx download has the wrong checksum ($GOT)" >&2; exit 1; fi
tar -xjf "$TMP/$NAME.tar.bz2" -C "$TMP"
rm -rf "$DEST/lib"
mkdir -p "$DEST/lib"
cp "$TMP/$NAME/lib/libsherpa-onnx-c-api.dylib" "$TMP/$NAME/lib/libonnxruntime.dylib" "$DEST/lib/"
echo "$VERSION" > "$DEST/VERSION"
rm -rf "$TMP"
echo "==> sherpa-onnx $VERSION in $DEST/lib"
