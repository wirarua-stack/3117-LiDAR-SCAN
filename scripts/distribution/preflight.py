"""Validate inputs without echoing values; safe on runners with no Apple account."""
import os
import re
import sys


def validate(env):
    errors = []
    mode = env.get('DISTRIBUTION_MODE', '')
    if mode not in ('build-only', 'testflight'):
        errors.append('Invalid distribution mode')
    if env.get('GITHUB_REF') != 'refs/heads/main':
        errors.append('Distribution is restricted to main')
    sha = env.get('EXPECTED_SHA', '')
    if not re.fullmatch(r'[0-9a-f]{40}', sha) or sha != env.get('GITHUB_SHA'):
        errors.append('Expected SHA must equal the full dispatch commit SHA')
    if env.get('AUTHORIZE_SIGNING') != 'true':
        errors.append('Explicit signing authorization required')
    if mode == 'testflight' and env.get('UPLOAD_CONFIRMATION') != 'UPLOAD_TO_TESTFLIGHT':
        errors.append('Explicit TestFlight upload confirmation required')
    patterns = {
        'APPLE_TEAM_ID': r'[A-Z0-9]{10}',
        'APP_BUNDLE_ID': r'[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+',
        'APP_VERSION': r'[0-9]{1,4}\.[0-9]{1,2}\.[0-9]{1,2}',
        'BUILD_NUMBER': r'[1-9][0-9]{0,3}(?:\.[0-9]{1,2}){0,2}',
    }
    for name, pattern in patterns.items():
        if not re.fullmatch(pattern, env.get(name, '')):
            errors.append('Missing or invalid: ' + name)
    required = ['IOS_DISTRIBUTION_P12_BASE64', 'IOS_DISTRIBUTION_P12_PASSWORD',
                'IOS_APP_STORE_PROFILE_BASE64']
    if mode == 'testflight':
        required += ['ASC_KEY_ID', 'ASC_ISSUER_ID', 'ASC_PRIVATE_KEY']
        if not re.fullmatch(r'[A-Z0-9]{10}', env.get('ASC_KEY_ID', '')):
            errors.append('Invalid ASC_KEY_ID')
        if not re.fullmatch(r'[0-9a-fA-F-]{36}', env.get('ASC_ISSUER_ID', '')):
            errors.append('Invalid ASC_ISSUER_ID')
    for name in required:
        if not env.get(name):
            errors.append('Missing secret: ' + name)
    return errors


if __name__ == '__main__':
    errors = validate(os.environ)
    for error in errors:
        print(error, file=sys.stderr)
    if errors:
        sys.exit(1)
    print('Distribution configuration validated (values withheld).')
