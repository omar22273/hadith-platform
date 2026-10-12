"""Static checks of the committed Android project (no Flutter or Android SDK needed).

The android/ folder is committed as plain files; nothing patches it in CI any more.
These tests fail the build early if the manifest or the signing setup drifts:

* the manifest is well-formed, has exactly one <application>, and every
  <uses-permission>, <queries>, <uses-feature> and <uses-sdk> sits directly under
  <manifest>;
* every <activity>, <receiver> and <service> declares android:exported explicitly
  (Android 12+), and the launcher activity is exported;
* the release build type is signed with the debug signing config, which uses the
  committed stable keystore with the v1, v2 and v3 schemes all enabled;
* the workflow no longer generates or patches the Android scaffold dynamically.
"""

import os
import re
import unittest
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ANDROID_NS = 'http://schemas.android.com/apk/res/android'
MANIFEST = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'AndroidManifest.xml')
GRADLE = os.path.join(ROOT, 'android', 'app', 'build.gradle.kts')
WORKFLOW = os.path.join(ROOT, '.github', 'workflows', 'build_apk.yml')
KEYSTORE = os.path.join(ROOT, 'tools', 'android', 'hadith-stable.keystore')
TOP_LEVEL = ('uses-permission', 'uses-permission-sdk-23', 'uses-feature', 'uses-sdk', 'queries', 'permission')
COMPONENTS = ('activity', 'activity-alias', 'service', 'receiver', 'provider')
EXPLICIT_EXPORT = ('activity', 'activity-alias', 'service', 'receiver')


def attr(element: ET.Element, name: str):
    return element.get('{%s}%s' % (ANDROID_NS, name))


def read(path: str) -> str:
    with open(path, encoding='utf-8') as handle:
        return handle.read()


class ManifestTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.root = ET.parse(MANIFEST).getroot()
        cls.parents = {child: parent for parent in cls.root.iter() for child in parent}

    def test_root_and_single_application(self) -> None:
        self.assertEqual(self.root.tag, 'manifest')
        self.assertEqual(len([c for c in self.root if c.tag == 'application']), 1)

    def test_package_level_elements_are_direct_children_of_manifest(self) -> None:
        for element in self.root.iter():
            if element.tag in TOP_LEVEL:
                self.assertIs(self.parents[element], self.root, '<%s> must be directly under <manifest>' % element.tag)

    def test_components_live_inside_application(self) -> None:
        for element in self.root.iter():
            if element.tag in COMPONENTS:
                self.assertEqual(self.parents[element].tag, 'application', '<%s> must be inside <application>' % element.tag)

    def test_every_activity_receiver_and_service_declares_exported(self) -> None:
        found = 0
        for element in self.root.iter():
            if element.tag in EXPLICIT_EXPORT:
                found += 1
                self.assertIn(attr(element, 'exported'), ('true', 'false'), '%s %s' % (element.tag, attr(element, 'name')))
        self.assertGreaterEqual(found, 3)

    def test_launcher_is_exported(self) -> None:
        launchers = [
            activity
            for activity in self.root.iter('activity')
            if any(attr(action, 'name') == 'android.intent.action.MAIN' for action in activity.iter('action'))
        ]
        self.assertEqual(len(launchers), 1)
        self.assertEqual(attr(launchers[0], 'exported'), 'true')

    def test_permissions_are_unique_and_include_the_ones_the_app_needs(self) -> None:
        names = [attr(e, 'name') for e in self.root if e.tag == 'uses-permission']
        self.assertEqual(len(names), len(set(names)))
        for needed in ('INTERNET', 'VIBRATE', 'POST_NOTIFICATIONS', 'RECEIVE_BOOT_COMPLETED'):
            self.assertIn('android.permission.' + needed, names)

    def test_referenced_resources_exist(self) -> None:
        application = next(c for c in self.root if c.tag == 'application')
        self.assertEqual(attr(application, 'networkSecurityConfig'), '@xml/network_security_config')
        self.assertTrue(os.path.exists(os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res', 'xml', 'network_security_config.xml')))
        self.assertTrue(os.path.exists(os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res', 'mipmap-mdpi', 'ic_launcher.png')))
        ET.parse(os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res', 'xml', 'network_security_config.xml'))


class SigningTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.gradle = read(GRADLE)

    def test_debug_config_uses_the_stable_keystore_with_all_schemes(self) -> None:
        self.assertTrue(os.path.exists(KEYSTORE))
        self.assertIn('tools/android/hadith-stable.keystore', self.gradle)
        for flag in ('enableV1Signing', 'enableV2Signing', 'enableV3Signing'):
            self.assertRegex(self.gradle, flag + r'\s*=\s*true')

    def test_release_is_signed_with_the_debug_config(self) -> None:
        release = re.search(r'release\s*\{(.*?)\n        \}', self.gradle, flags=re.DOTALL)
        self.assertIsNotNone(release)
        self.assertIn('signingConfig = signingConfigs.getByName("debug")', release.group(1))

    def test_min_sdk_is_pinned_to_the_flutter_floor(self) -> None:
        self.assertRegex(self.gradle, r'minSdk\s*=\s*24\b')

    def test_no_todo_placeholders(self) -> None:
        self.assertNotIn('TODO', self.gradle)


class WorkflowTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.workflow = read(WORKFLOW)

    def test_the_scaffold_is_not_generated_or_patched_in_ci(self) -> None:
        self.assertNotIn('flutter create', self.workflow)
        self.assertNotIn('patch_manifest', self.workflow)
        self.assertFalse(os.path.exists(os.path.join(ROOT, 'tools', 'android', 'patch_manifest.py')))

    def test_the_apk_is_split_inspected_and_signed_before_upload(self) -> None:
        for needle in ('flutter build apk --release --split-per-abi', 'aapt dump badging', 'apksigner', 'verify_apk.py'):
            self.assertIn(needle, self.workflow)
        self.assertLess(self.workflow.index('verify_apk.py'), self.workflow.index('upload-artifact'))
        self.assertLess(self.workflow.index('dump badging'), self.workflow.index('upload-artifact'))


if __name__ == '__main__':
    unittest.main()
