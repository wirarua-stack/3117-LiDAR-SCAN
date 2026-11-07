"""Validate a decoded App Store profile and produce manual export options."""
import datetime
import os
import pathlib
import plistlib
import re
import sys


def validate(profile, team, bundle, now=None):
    now = now or datetime.datetime.now(datetime.timezone.utc)
    expiry = profile.get('ExpirationDate')
    if not isinstance(expiry, datetime.datetime):
        raise ValueError('Profile expiry missing')
    if expiry.replace(tzinfo=datetime.timezone.utc) <= now:
        raise ValueError('Provisioning profile expired')
    ent = profile.get('Entitlements', {})
    prefixes = profile.get('ApplicationIdentifierPrefix', [])
    if (profile.get('TeamIdentifier') != [team]
            or ent.get('com.apple.developer.team-identifier') != team):
        raise ValueError('Profile team mismatch')
    if not prefixes or ent.get('application-identifier') != prefixes[0] + '.' + bundle:
        raise ValueError('Profile bundle identifier mismatch (wildcards not accepted)')
    if ent.get('get-task-allow', True) or profile.get('ProvisionedDevices') is not None or profile.get('ProvisionsAllDevices'):
        raise ValueError('An App Store distribution profile is required')
    if not ent.get('beta-reports-active') or not profile.get('DeveloperCertificates'):
        raise ValueError('Profile is not ready for TestFlight distribution')
    uuid = profile.get('UUID', '')
    if not re.fullmatch(r'[0-9A-Fa-f-]{36}', uuid):
        raise ValueError('Invalid provisioning profile UUID')
    return uuid


if __name__ == '__main__':
    profile = plistlib.loads(pathlib.Path(sys.argv[1]).read_bytes())
    try:
        uuid = validate(profile, os.environ['APPLE_TEAM_ID'], os.environ['APP_BUNDLE_ID'])
    except ValueError as error:
        sys.exit(str(error))
    out = pathlib.Path(sys.argv[2])
    out.write_bytes(plistlib.dumps({
        'method': 'app-store-connect', 'destination': 'export',
        'signingStyle': 'manual', 'signingCertificate': 'Apple Distribution',
        'teamID': os.environ['APPLE_TEAM_ID'],
        'provisioningProfiles': {os.environ['APP_BUNDLE_ID']: uuid},
        'manageAppVersionAndBuildNumber': False, 'uploadSymbols': True,
    }))
    print(uuid)
