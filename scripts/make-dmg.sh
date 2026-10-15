#!/bin/bash
# Builds a signed, notarized and stapled build/StayAwake-VERSION.dmg.
#
#   SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" \
#   NOTARY_PROFILE=stayawake-notary \
#   scripts/make-dmg.sh 1.0.0
#
# Notary credentials: either NOTARY_PROFILE (a keychain profile created with
# `xcrun notarytool store-credentials`), or an App Store Connect API key via
# NOTARY_KEY_PATH, NOTARY_KEY_ID and NOTARY_ISSUER_ID (used in CI).
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: make-dmg.sh VERSION}"
DMG="build/StayAwake-$VERSION.dmg"
STAGING="build/dmg"

if [ -n "${NOTARY_PROFILE:-}" ]; then
  NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
elif [ -n "${NOTARY_KEY_PATH:-}" ]; then
  NOTARY_ARGS=(--key "$NOTARY_KEY_PATH" --key-id "${NOTARY_KEY_ID:?}" --issuer "${NOTARY_ISSUER_ID:?}")
else
  echo "Set NOTARY_PROFILE, or NOTARY_KEY_PATH/NOTARY_KEY_ID/NOTARY_ISSUER_ID." >&2
  exit 1
fi

scripts/build-app.sh --release "$VERSION"

echo "▸ Creating $DMG..."
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R build/StayAwake.app "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "StayAwake $VERSION" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGING"
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"

echo "▸ Notarizing (this usually takes a few minutes)..."
xcrun notarytool submit "$DMG" "${NOTARY_ARGS[@]}" --wait
# The ticket can take a moment to propagate and the CloudKit lookup is flaky, so retry stapling.
for attempt in 1 2 3 4 5; do
  xcrun stapler staple "$DMG" && break
  [ "$attempt" = 5 ] && exit 1
  echo "Stapling failed, retrying in $((attempt * 15))s..."
  sleep $((attempt * 15))
done

echo "▸ Verifying..."
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature --verbose "$DMG"
shasum -a 256 "$DMG"
echo "✔ $DMG is ready to upload."
