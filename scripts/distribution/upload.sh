#!/bin/bash
set -euo pipefail
umask 077
python3 scripts/distribution/preflight.py
[[ "$DISTRIBUTION_MODE" == 'testflight' && "$UPLOAD_CONFIRMATION" == 'UPLOAD_TO_TESTFLIGHT' ]]
key_dir="$RUNNER_TEMP/lidar-signing/private_keys"
mkdir -p "$key_dir"
printf '%s' "$ASC_PRIVATE_KEY" > "$key_dir/AuthKey_$ASC_KEY_ID.p8"
export API_PRIVATE_KEYS_DIR="$key_dir"
xcrun altool --validate-app --type ios --file build/distribution/LiDARScan.ipa \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
xcrun altool --upload-app --type ios --file build/distribution/LiDARScan.ipa \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
python3 - <<'PY'
import json, pathlib
p = pathlib.Path('build/distribution/evidence.json')
e = json.loads(p.read_text())
e['testflight_upload'] = 'accepted_by_upload_tool; Apple processing pending'
p.write_text(json.dumps(e, indent=2) + '\n')
PY
printf '\nUpload accepted by tool. Apple processing, tester assignment, installation and LiDAR acceptance remain pending.\n' >> "$GITHUB_STEP_SUMMARY"
