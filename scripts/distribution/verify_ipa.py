"""Check packaged identity/version and device target before upload."""
import os
import pathlib
import plistlib
import subprocess
import sys
import tempfile
import zipfile

with tempfile.TemporaryDirectory(dir=os.environ['RUNNER_TEMP']) as tmp:
    with zipfile.ZipFile(sys.argv[1]) as z:
        z.extractall(tmp)
    apps = list(pathlib.Path(tmp).glob('Payload/*.app'))
    if len(apps) != 1:
        sys.exit('IPA must contain exactly one app')
    app = apps[0]
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    for key, expected in [('CFBundleIdentifier', os.environ['APP_BUNDLE_ID']),
                          ('CFBundleShortVersionString', os.environ['APP_VERSION']),
                          ('CFBundleVersion', os.environ['BUILD_NUMBER']),
                          ('UIDeviceFamily', [2])]:
        if info.get(key) != expected:
            sys.exit('Packaged metadata mismatch: ' + key)
    if not (app / 'Assets.car').is_file() or not info.get('CFBundleIcons~ipad', info.get('CFBundleIcons')):
        sys.exit('Packaged app icon missing')
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
    ent = subprocess.run(['codesign', '-d', '--entitlements', ':-', str(app)],
                         capture_output=True, check=True).stdout
    ent = plistlib.loads(ent)
    if ent.get('get-task-allow', False):
        sys.exit('Debug entitlement found in distribution app')
    if ent.get('com.apple.developer.team-identifier') != os.environ['APPLE_TEAM_ID']:
        sys.exit('Signed app team mismatch')
print('IPA metadata and signature verified; device behavior remains unverified.')
