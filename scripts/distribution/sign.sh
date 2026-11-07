#!/bin/bash
set -euo pipefail
umask 077
python3 scripts/distribution/preflight.py
work="$RUNNER_TEMP/lidar-signing"
mkdir -p "$work"
# GitHub-hosted ephemeral runner only. Never print decoded credentials.
python3 - "$work" <<'PY'
import base64, os, pathlib, sys
root = pathlib.Path(sys.argv[1])
for name, filename in [('IOS_DISTRIBUTION_P12_BASE64', 'certificate.p12'),
                       ('IOS_APP_STORE_PROFILE_BASE64', 'profile.mobileprovision')]:
    try:
        raw = base64.b64decode(''.join(os.environ[name].split()), validate=True)
    except ValueError:
        sys.exit('Invalid base64 secret: ' + name)
    (root / filename).write_bytes(raw)
PY
security cms -D -i "$work/profile.mobileprovision" > "$work/profile.plist"
profile_uuid=$(python3 scripts/distribution/profile.py "$work/profile.plist" "$work/ExportOptions.plist")
profile_dir="$HOME/Library/MobileDevice/Provisioning Profiles"
mkdir -p "$profile_dir"
cp "$work/profile.mobileprovision" "$profile_dir/$profile_uuid.mobileprovision"
printf '%s' "$profile_dir/$profile_uuid.mobileprovision" > "$work/installed-profile-path"
keychain="$work/signing.keychain-db"
keychain_password=$(openssl rand -hex 32)
security create-keychain -p "$keychain_password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
security import "$work/certificate.p12" -P "$IOS_DISTRIBUTION_P12_PASSWORD" -A -t cert -f pkcs12 -k "$keychain" >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -k "$keychain_password" "$keychain" >/dev/null
security list-keychains -d user -s "$keychain"
security find-identity -v -p codesigning "$keychain" > "$work/identities.txt"
if ! grep -q '"Apple Distribution:' "$work/identities.txt"; then
  echo 'No valid Apple Distribution identity with private key found' >&2
  exit 1
fi
xcodebuild archive -project ios/3117LiDARScan.xcodeproj -scheme LiDARScan \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath "$work/LiDARScan.xcarchive" -derivedDataPath "$work/DerivedData" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY='Apple Distribution' \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" PRODUCT_BUNDLE_IDENTIFIER="$APP_BUNDLE_ID" \
  PROVISIONING_PROFILE_SPECIFIER="$profile_uuid" \
  MARKETING_VERSION="$APP_VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  OTHER_CODE_SIGN_FLAGS="--keychain $keychain" > "$work/archive.log" 2>&1 || {
    echo 'Archive failed. Raw signing logs are intentionally not published; inspect profile/certificate compatibility and rerun unsigned CI.' >&2
    exit 1
  }
xcodebuild -exportArchive -archivePath "$work/LiDARScan.xcarchive" \
  -exportOptionsPlist "$work/ExportOptions.plist" -exportPath "$work/export" \
  > "$work/export.log" 2>&1 || {
    echo 'IPA export failed. Check App Store profile, certificate and bundle configuration.' >&2
    exit 1
  }
mkdir -p build/distribution
cp "$work/export/3117 LiDAR SCAN.ipa" build/distribution/LiDARScan.ipa
python3 scripts/distribution/verify_ipa.py build/distribution/LiDARScan.ipa
# Only non-secret evidence and the signed IPA are retained, never keychains/profiles/logs.
python3 - <<'PY'
import hashlib, json, os, pathlib
p = pathlib.Path('build/distribution/LiDARScan.ipa')
pathlib.Path('build/distribution/evidence.json').write_text(json.dumps({
    'commit': os.environ['GITHUB_SHA'], 'run_id': os.environ['GITHUB_RUN_ID'],
    'version': os.environ['APP_VERSION'], 'build': os.environ['BUILD_NUMBER'],
    'ipa_sha256': hashlib.sha256(p.read_bytes()).hexdigest(),
    'signed_ipa_verified': True, 'testflight_upload': 'not_attempted',
    'ipad_installation': 'unverified', 'physical_lidar_scan': 'unverified'
}, indent=2) + '\n')
PY
