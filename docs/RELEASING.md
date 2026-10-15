# Releasing

Releases are distributed as a DMG signed with a Developer ID certificate and notarized by Apple,
so it opens without Gatekeeper warnings.

## One-time setup

### 1. Developer ID Application certificate

Only the Apple Developer account holder can create this certificate.

1. Xcode → Settings → Accounts → select your team → **Manage Certificates…**
2. Click **+** → **Developer ID Application**.
3. Check it: `security find-identity -v -p codesigning` should list
   `Developer ID Application: <Name> (<TEAMID>)`.

### 2. Notarization credentials

Create an App Store Connect API key: [App Store Connect](https://appstoreconnect.apple.com) → Users and Access →
Integrations → App Store Connect API → Team Keys → **+** with the **Developer** role.
Download the `.p8` file (it can only be downloaded once) and note the **Key ID** and **Issuer ID**.

For local releases, store it in the keychain:

```sh
xcrun notarytool store-credentials stayawake-notary \
  --key AuthKey_XXXXXXXXXX.p8 --key-id XXXXXXXXXX --issuer xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

### 3. GitHub secrets (for the release workflow)

Export the certificate and its private key from Keychain Access as a `.p12` file with a password, then add these
secrets under the repository's Settings → Secrets and variables → Actions:

| Secret | Value |
|---|---|
| `DEVELOPER_ID_CERTIFICATE_P12` | `base64 -i certificate.p12 \| pbcopy` |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | Password of the `.p12` file |
| `DEVELOPER_ID_IDENTITY` | `Developer ID Application: <Name> (<TEAMID>)` |
| `NOTARY_API_KEY_P8` | `base64 -i AuthKey_XXXXXXXXXX.p8 \| pbcopy` |
| `NOTARY_API_KEY_ID` | Key ID |
| `NOTARY_API_ISSUER_ID` | Issuer ID |

## Making a release

To check signing and notarization without publishing anything, run the **Release** workflow manually
(Actions → Release → Run workflow, or `gh workflow run release.yml -f version=1.0.0`).
The notarized DMG is attached to the run as an artifact.

1. Move the changes in `CHANGELOG.md` under a new version heading, e.g. `## [1.1.0] - 2026-11-01`.
2. Commit, then tag and push:

   ```sh
   git tag v1.1.0
   git push origin main v1.1.0
   ```

3. The **Release** workflow tests, builds a universal (Apple silicon + Intel) app, signs, notarizes and staples the DMG,
   and publishes a GitHub release with the changelog section as release notes.

### Releasing from your Mac instead

```sh
SIGN_IDENTITY="Developer ID Application: <Name> (<TEAMID>)" NOTARY_PROFILE=stayawake-notary \
  scripts/make-dmg.sh 1.1.0
gh release create v1.1.0 build/StayAwake-1.1.0.dmg --title "StayAwake 1.1.0" --notes "..."
```
