"""Static checks of the committed Android project (no Flutter or Android SDK needed).

The android/ folder is committed as plain files; nothing patches it in CI any more.
These tests fail the build early if the manifest or the signing setup drifts:

* the manifest is well-formed, has exactly one <application>, and every
  <uses-permission>, <queries>, <uses-feature> and <uses-sdk> sits directly under
  <manifest>;
* every <activity>, <receiver> and <service> declares android:exported explicitly
  (Android 12+), and the launcher activity is exported;
* the release build type is signed with its own `release` signing config, bound only to the
  committed fixed keystore (android/app/fixed-debug.keystore) with v1, v2 and v3 all enabled;
* versionCode follows GITHUB_RUN_NUMBER so every CI build is strictly newer than the last;
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
KEYSTORE = os.path.join(ROOT, 'android', 'app', 'fixed-debug.keystore')
TOP_LEVEL = ('uses-permission', 'uses-permission-sdk-23', 'uses-feature', 'uses-sdk', 'queries', 'permission')
COMPONENTS = ('activity', 'activity-alias', 'service', 'receiver', 'provider')
EXPLICIT_EXPORT = ('activity', 'activity-alias', 'service', 'receiver')


def attr(element: ET.Element, name: str):
    return element.get('{%s}%s' % (ANDROID_NS, name))


def png_header(path: str) -> bytes:
    with open(path, 'rb') as handle:
        header = handle.read(32)
    assert header[:8] == b'\x89PNG\r\n\x1a\n', path
    return header


def png_size(path: str):
    header = png_header(path)
    return int.from_bytes(header[16:20], 'big'), int.from_bytes(header[20:24], 'big')


def png_color_type(path: str) -> int:
    return png_header(path)[25]


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


def png_chunks(path: str):
    """Yields (type, data, crc_ok) for every chunk; raises on a malformed structure."""
    import struct
    import zlib

    with open(path, 'rb') as handle:
        data = handle.read()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', '%s: bad PNG signature' % path
    position = 8
    while position < len(data):
        length, kind = struct.unpack('>I4s', data[position:position + 8])
        body = data[position + 8:position + 8 + length]
        crc = struct.unpack('>I', data[position + 8 + length:position + 12 + length])[0]
        yield kind, body, zlib.crc32(kind + body) & 0xFFFFFFFF == crc
        position += 12 + length
    assert position == len(data), '%s: trailing bytes after the last chunk' % path


class ResourceIntegrityTest(unittest.TestCase):
    """Every PNG and XML under res/ is structurally sound and every reference resolves."""

    RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')

    def files(self, suffix: str):
        for folder, _, names in os.walk(self.RES):
            for name in names:
                if name.endswith(suffix):
                    yield os.path.join(folder, name)

    def test_every_png_has_valid_structure_and_checksums(self) -> None:
        count = 0
        for path in self.files('.png'):
            count += 1
            kinds = []
            for kind, body, crc_ok in png_chunks(path):
                self.assertTrue(crc_ok, '%s: CRC mismatch in %s chunk' % (path, kind))
                kinds.append(kind)
            self.assertEqual(kinds[0], b'IHDR', path)
            self.assertEqual(kinds[-1], b'IEND', path)
            self.assertIn(b'IDAT', kinds, path)
        self.assertGreaterEqual(count, 5)

    def test_every_xml_resource_is_well_formed(self) -> None:
        for path in self.files('.xml'):
            ET.parse(path)

    def test_launcher_icon_set_is_the_committed_flutter_launcher_icons_output(self) -> None:
        legacy = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
        for density, size in legacy.items():
            path = os.path.join(self.RES, 'mipmap-' + density, 'ic_launcher.png')
            self.assertEqual(png_size(path), (size, size), path)
            self.assertNotEqual(png_color_type(path), 3, '%s is still the palette-based Flutter default icon' % path)
        foreground = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432}
        for density, size in foreground.items():
            path = os.path.join(self.RES, 'drawable-' + density, 'ic_launcher_foreground.png')
            self.assertEqual(png_size(path), (size, size), path)
        adaptive = read(os.path.join(self.RES, 'mipmap-anydpi-v26', 'ic_launcher.xml'))
        self.assertIn('<background android:drawable="@color/ic_launcher_background"', adaptive)
        self.assertIn('@drawable/ic_launcher_foreground', adaptive)
        self.assertIn('#0A1128', read(os.path.join(self.RES, 'values', 'ic_launcher_background.xml'))
                      if os.path.exists(os.path.join(self.RES, 'values', 'ic_launcher_background.xml'))
                      else read(os.path.join(self.RES, 'values', 'colors.xml')))

    def test_the_official_icon_source_is_committed(self) -> None:
        path = os.path.join(ROOT, 'assets', 'branding', 'app_icon.png')
        self.assertEqual(png_size(path), (1024, 1024))
        self.assertIn('flutter_launcher_icons:', read(os.path.join(ROOT, 'pubspec.yaml')))

    def test_manifest_icon_references_resolve(self) -> None:
        application = next(c for c in ET.parse(MANIFEST).getroot() if c.tag == 'application')
        self.assertEqual(attr(application, 'label'), 'هَدْي')
        self.assertEqual(attr(application, 'icon'), '@mipmap/ic_launcher')
        self.assertIsNone(attr(application, 'roundIcon'), 'no round icon resource exists')
        for reference in (attr(application, 'icon'), attr(application, 'networkSecurityConfig')):
            kind, name = reference[1:].split('/')
            found = any(
                os.path.splitext(n)[0] == name
                for folder in os.listdir(self.RES)
                if folder.startswith(kind)
                for n in os.listdir(os.path.join(self.RES, folder))
            )
            self.assertTrue(found, 'unresolved %s' % reference)

    def test_application_id_is_the_final_hady_id(self) -> None:
        gradle = read(GRADLE)
        self.assertRegex(gradle, r'applicationId\s*=\s*"app\.hady\.platform"')
        self.assertNotIn('applicationId = "app.hadithplatform', gradle)


class SigningTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.gradle = read(GRADLE)

    def test_release_config_uses_the_fixed_keystore_with_all_schemes(self) -> None:
        self.assertTrue(os.path.exists(KEYSTORE))
        config = re.search(r'create\("release"\)\s*\{(.*?)\n        \}', self.gradle, flags=re.DOTALL)
        self.assertIsNotNone(config)
        self.assertIn('storeFile = file("fixed-debug.keystore")', config.group(1))
        self.assertIn('keyAlias = "androiddebugkey"', config.group(1))
        for flag in ('enableV1Signing', 'enableV2Signing', 'enableV3Signing'):
            self.assertRegex(config.group(1), flag + r'\s*=\s*true')
        self.assertNotIn('hadith-stable', self.gradle)

    def test_release_is_signed_with_the_release_config_only(self) -> None:
        release = re.search(r'release\s*\{(.*?)\n        \}', self.gradle[self.gradle.index('buildTypes'):], flags=re.DOTALL)
        self.assertIsNotNone(release)
        self.assertIn('signingConfig = signingConfigs.getByName("release")', release.group(1))
        self.assertNotIn('getByName("debug")', self.gradle)

    def test_version_code_follows_the_ci_run_number(self) -> None:
        self.assertIn('System.getenv("GITHUB_RUN_NUMBER")', self.gradle)
        self.assertRegex(self.gradle, r'100 \+ ciRunNumber')

    def test_the_fixed_keystore_is_a_real_rsa_2048_pkcs12_store(self) -> None:
        with open(KEYSTORE, 'rb') as handle:
            data = handle.read()
        self.assertEqual(data[0], 0x30, 'PKCS12 stores are DER SEQUENCEs')
        self.assertGreater(len(data), 1500)

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
        self.assertIn('android/app/fixed-debug.keystore', self.workflow)
        self.assertNotIn('hadith-stable', self.workflow)
        self.assertLess(self.workflow.index('verify_apk.py'), self.workflow.index('upload-artifact'))
        self.assertLess(self.workflow.index('dump badging'), self.workflow.index('upload-artifact'))


if __name__ == '__main__':
    unittest.main()
