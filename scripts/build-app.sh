#!/bin/bash
# Builds build/StayAwake.app.
#   scripts/build-app.sh                    Host architecture, ad-hoc signature
#   scripts/build-app.sh --release VERSION  Universal binary, version stamped, signed with $SIGN_IDENTITY
set -euo pipefail
cd "$(dirname "$0")/.."

BUNDLE="build/StayAwake.app"
VERSION=""
ARCH_FLAGS=()

if [ "${1:-}" = "--release" ]; then
  VERSION="${2:?usage: build-app.sh --release VERSION}"
  : "${SIGN_IDENTITY:?Set SIGN_IDENTITY to your \"Developer ID Application: ...\" certificate}"
  ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

swift build -c release "${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}"
BIN="$(swift build -c release "${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}" --show-bin-path)/StayAwake"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
cp "$BIN" "$BUNDLE/Contents/MacOS/StayAwake"
cp Support/Info.plist "$BUNDLE/Contents/Info.plist"
if [ -n "$VERSION" ]; then
  plutil -replace CFBundleShortVersionString -string "$VERSION" "$BUNDLE/Contents/Info.plist"
  plutil -replace CFBundleVersion -string "$VERSION" "$BUNDLE/Contents/Info.plist"
fi
plutil -lint -s "$BUNDLE/Contents/Info.plist"

if [ -n "$VERSION" ]; then
  # Hardened runtime and a secure timestamp are required for notarization.
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$BUNDLE"
else
  codesign --force --sign - "$BUNDLE"
fi
codesign --verify --strict "$BUNDLE"
echo "✔ Built $BUNDLE"
