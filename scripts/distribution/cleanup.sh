#!/bin/bash
set -euo pipefail
work="$RUNNER_TEMP/lidar-signing"
if [[ -f "$work/installed-profile-path" ]]; then
  profile_path=$(cat "$work/installed-profile-path")
  case "$profile_path" in
    "$HOME/Library/MobileDevice/Provisioning Profiles/"*.mobileprovision) rm -f "$profile_path" ;;
  esac
fi
security delete-keychain "$work/signing.keychain-db" >/dev/null 2>&1 || true
rm -rf "$work"
