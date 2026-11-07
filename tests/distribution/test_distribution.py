import copy
import datetime
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
def module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts/distribution' / (name + '.py'))
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result

preflight = module('preflight')
profile = module('profile')

class AuthorizationTests(unittest.TestCase):
    def setUp(self):
        self.env = dict(DISTRIBUTION_MODE='build-only', GITHUB_REF='refs/heads/main',
                        EXPECTED_SHA='a'*40, GITHUB_SHA='a'*40, AUTHORIZE_SIGNING='true',
                        APPLE_TEAM_ID='ABCDE12345', APP_BUNDLE_ID='com.example.scan',
                        APP_VERSION='0.2.0', BUILD_NUMBER='3',
                        IOS_DISTRIBUTION_P12_BASE64='fixture',
                        IOS_DISTRIBUTION_P12_PASSWORD='fixture',
                        IOS_APP_STORE_PROFILE_BASE64='fixture')
    def test_build_only_needs_no_upload_key(self):
        self.assertEqual(preflight.validate(self.env), [])
    def test_unapproved_wrong_ref_and_wrong_sha_rejected(self):
        for key, value in [('AUTHORIZE_SIGNING','false'), ('GITHUB_REF','refs/pull/1/merge'),
                           ('EXPECTED_SHA','b'*40), ('DISTRIBUTION_MODE','invalid')]:
            with self.subTest(key=key):
                self.assertTrue(preflight.validate(dict(self.env, **{key:value})))
    def test_upload_requires_both_confirmation_and_credentials(self):
        self.env['DISTRIBUTION_MODE'] = 'testflight'
        self.assertTrue(preflight.validate(self.env))
        self.env.update(UPLOAD_CONFIRMATION='UPLOAD_TO_TESTFLIGHT', ASC_KEY_ID='ABCDE12345',
                        ASC_ISSUER_ID='12345678-1234-1234-1234-123456789abc', ASC_PRIVATE_KEY='fixture')
        self.assertEqual(preflight.validate(self.env), [])
        del self.env['UPLOAD_CONFIRMATION']
        self.assertTrue(preflight.validate(self.env))
    def test_invalid_build_numbers_and_injection_rejected(self):
        for value in ['0', '10000', '1.100', '1.2.3.4', '3;echo secret', '$(env)']:
            with self.subTest(value=value):
                self.assertTrue(preflight.validate(dict(self.env, BUILD_NUMBER=value)))
    def test_missing_secrets_reports_names_only(self):
        self.env['IOS_DISTRIBUTION_P12_PASSWORD'] = ''
        errors = preflight.validate(self.env)
        self.assertIn('Missing secret: IOS_DISTRIBUTION_P12_PASSWORD', errors)
        self.assertNotIn('fixture', '\n'.join(errors))

class ProfileTests(unittest.TestCase):
    def setUp(self):
        self.profile = dict(UUID='12345678-1234-1234-1234-123456789abc',
            ExpirationDate=datetime.datetime(2030,1,1), TeamIdentifier=['ABCDE12345'],
            ApplicationIdentifierPrefix=['OLDPREFIX1'], DeveloperCertificates=[b'fixture'],
            Entitlements={'com.apple.developer.team-identifier':'ABCDE12345',
                          'application-identifier':'OLDPREFIX1.com.example.scan',
                          'get-task-allow':False, 'beta-reports-active':True})
    def check(self, p):
        return profile.validate(p,'ABCDE12345','com.example.scan',datetime.datetime(2026,1,1,tzinfo=datetime.timezone.utc))
    def test_app_store_profile_and_legacy_prefix(self):
        self.assertEqual(self.check(self.profile), self.profile['UUID'])
    def test_expired_wrong_team_ad_hoc_enterprise_profiles(self):
        for key,value in [('ExpirationDate',datetime.datetime(2020,1,1)),
                          ('TeamIdentifier',['WRONG12345']), ('ProvisionedDevices',['device']),
                          ('ProvisionsAllDevices',True), ('UUID','../../escape')]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.check(dict(self.profile, **{key:value}))
    def test_debug_wildcard_and_wrong_bundle_rejected(self):
        for key,value in [('get-task-allow',True), ('application-identifier','OLDPREFIX1.*'),
                          ('application-identifier','OLDPREFIX1.com.other.scan'), ('beta-reports-active',False)]:
            p=copy.deepcopy(self.profile)
            p['Entitlements'][key]=value
            with self.subTest(key=key,value=value), self.assertRaises(ValueError):
                self.check(p)

if __name__ == '__main__':
    unittest.main()
