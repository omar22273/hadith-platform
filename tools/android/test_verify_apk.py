"""Tests for tools/android/verify_apk.py (parsers and checks; no Android SDK needed)."""

import os
import tempfile
import unittest
import zipfile

import verify_apk as va

GOOD_TREE = """N: android=http://schemas.android.com/apk/res/android (line=2)
  E: manifest (line=2)
    A: android:versionCode(0x0101021b)=2006
    A: android:versionName(0x0101021c)="2.2.1" (Raw: "2.2.1")
    A: package="app.hady.platform" (Raw: "app.hady.platform")
    E: uses-sdk (line=7)
      A: android:minSdkVersion(0x0101020c)=24
      A: android:targetSdkVersion(0x01010270)=36
    E: uses-permission (line=11)
      A: android:name(0x01010003)="android.permission.INTERNET" (Raw: "android.permission.INTERNET")
    E: uses-permission (line=12)
      A: android:name(0x01010003)="android.permission.VIBRATE" (Raw: "android.permission.VIBRATE")
    E: queries (line=14)
      E: intent (line=15)
        E: action (line=16)
          A: android:name(0x01010003)="android.intent.action.TTS_SERVICE" (Raw: "android.intent.action.TTS_SERVICE")
    E: application (line=20)
      A: android:label(0x01010001)="Hadith" (Raw: "Hadith")
      E: activity (line=26)
        A: android:name(0x01010003)="app.hadithplatform.hadith_platform.MainActivity" (Raw: "app.hadithplatform.hadith_platform.MainActivity")
        A: android:exported(0x01010010)=(type 0x12)0xffffffff
        E: intent-filter (line=40)
          E: action (line=41)
            A: android:name(0x01010003)="android.intent.action.MAIN" (Raw: "android.intent.action.MAIN")
          E: category (line=42)
            A: android:name(0x01010003)="android.intent.category.LAUNCHER" (Raw: "android.intent.category.LAUNCHER")
      E: receiver (line=50)
        A: android:name(0x01010003)="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" (Raw: "x")
        A: android:exported(0x01010010)=false
"""


URI = 'http://schemas.android.com/apk/res/android:'
# aapt2 prints namespaced attribute names with the namespace URI, not the prefix.
GOOD_TREE_URI = GOOD_TREE.replace('A: android:', 'A: ' + URI)


class XmlTreeTest(unittest.TestCase):
    def test_namespace_uri_attributes_are_read_as_android_prefixed(self) -> None:
        root = va.parse_xmltree(GOOD_TREE_URI)
        self.assertEqual(va.manifest_problems(root), [])
        self.assertEqual(va.permissions_of(root), ['android.permission.INTERNET', 'android.permission.VIBRATE'])
        self.assertEqual(root.find_all('activity')[0].attrs['android:exported'], 'true')
        broken = GOOD_TREE_URI.replace('=(type 0x12)0xffffffff', '=(type 0x12)0x0')
        self.assertTrue(any('not exported' in p for p in va.manifest_problems(va.parse_xmltree(broken))))

    def test_values_are_normalised(self) -> None:
        self.assertEqual(va.parse_attribute_value('(type 0x12)0xffffffff'), 'true')
        self.assertEqual(va.parse_attribute_value('true'), 'true')
        self.assertEqual(va.parse_attribute_value('(type 0x12)0x0'), 'false')
        self.assertEqual(va.parse_attribute_value('"abc" (Raw: "abc")'), 'abc')
        self.assertEqual(va.parse_attribute_value('"plain"'), 'plain')
        self.assertEqual(va.parse_attribute_value('36'), '36')

    def test_good_manifest_has_no_problems(self) -> None:
        root = va.parse_xmltree(GOOD_TREE)
        self.assertEqual(root.name, 'manifest')
        self.assertEqual(va.manifest_problems(root), [])
        self.assertEqual(va.permissions_of(root), ['android.permission.INTERNET', 'android.permission.VIBRATE'])
        activity = root.find_all('activity')[0]
        self.assertEqual(activity.attrs['android:exported'], 'true')
        self.assertEqual(root.find_all('receiver')[0].attrs['android:exported'], 'false')

    def test_permission_inside_application_is_reported(self) -> None:
        broken = GOOD_TREE.replace(
            '    E: application (line=20)\n',
            '    E: application (line=20)\n      E: uses-permission (line=21)\n'
            '        A: android:name(0x01010003)="x.Y" (Raw: "x.Y")\n',
        )
        problems = va.manifest_problems(va.parse_xmltree(broken))
        self.assertTrue(any('direct child' in p for p in problems), problems)

    def test_unexported_launcher_and_component_outside_application(self) -> None:
        unexported = GOOD_TREE.replace('=(type 0x12)0xffffffff', '=(type 0x12)0x0')
        self.assertTrue(any('not exported' in p for p in va.manifest_problems(va.parse_xmltree(unexported))))
        outside = GOOD_TREE.replace(
            '    E: queries (line=14)\n',
            '    E: receiver (line=13)\n      A: android:name(0x01010003)="r.R" (Raw: "r.R")\n    E: queries (line=14)\n',
        )
        self.assertTrue(any('inside <application>' in p for p in va.manifest_problems(va.parse_xmltree(outside))))

    def test_missing_launcher_and_empty_tree(self) -> None:
        no_launcher = GOOD_TREE.replace('android.intent.action.MAIN', 'android.intent.action.VIEW')
        self.assertTrue(any('launcher' in p for p in va.manifest_problems(va.parse_xmltree(no_launcher))))
        self.assertTrue(va.manifest_problems(va.parse_xmltree('')))

    def test_intent_filter_without_exported_is_reported(self) -> None:
        broken = GOOD_TREE.replace(
            '        A: android:exported(0x01010010)=false\n',
            '        E: intent-filter (line=51)\n          E: action (line=52)\n'
            '            A: android:name(0x01010003)="a.B" (Raw: "a.B")\n',
        )
        self.assertTrue(any('no android:exported' in p for p in va.manifest_problems(va.parse_xmltree(broken))))


class ZipTest(unittest.TestCase):
    def _apk(self, folder: str, entries: dict, name: str = 'x.apk') -> str:
        path = os.path.join(folder, name)
        with zipfile.ZipFile(path, 'w') as archive:
            for entry, (data, method) in entries.items():
                archive.writestr(zipfile.ZipInfo(entry), data, compress_type=method)
        return path

    def test_missing_entries_and_compressed_resources_are_reported(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            complete = self._apk(
                folder,
                {
                    'AndroidManifest.xml': (b'm', zipfile.ZIP_DEFLATED),
                    'classes.dex': (b'd', zipfile.ZIP_DEFLATED),
                    'resources.arsc': (b'r' * 100, zipfile.ZIP_DEFLATED),
                    'lib/arm64-v8a/libapp.so': (b's', zipfile.ZIP_STORED),
                },
            )
            problems = va.zip_problems(complete)
            self.assertTrue(any('compressed' in p for p in problems), problems)
            self.assertEqual(va.abis_of(complete), ['arm64-v8a'])
            partial = self._apk(folder, {'AndroidManifest.xml': (b'm', zipfile.ZIP_STORED)}, 'p.apk')
            missing = va.zip_problems(partial)
            self.assertTrue(any('classes.dex' in p for p in missing))
            self.assertTrue(any('resources.arsc' in p for p in missing))

    def test_not_a_zip(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            path = os.path.join(folder, 'bad.apk')
            with open(path, 'wb') as handle:
                handle.write(b'this is not a zip')
            self.assertTrue(any('Not a valid zip' in p for p in va.zip_problems(path)))

    def test_data_offset_points_at_the_entry_data_in_the_local_header(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            path = self._apk(
                folder,
                {
                    'AndroidManifest.xml': (b'm', zipfile.ZIP_STORED),
                    'resources.arsc': (b'ARSC-DATA', zipfile.ZIP_STORED),
                },
            )
            with open(path, 'rb') as raw, zipfile.ZipFile(raw) as archive:
                offset = va.data_offset(raw, archive.getinfo('resources.arsc'))
                raw.seek(offset)
                self.assertEqual(raw.read(9), b'ARSC-DATA')

    def test_collect_and_main_without_apks(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            self.assertEqual(va.collect([folder]), [])
            self.assertEqual(va.main(['verify_apk.py', folder]), 1)


class SignatureReportTest(unittest.TestCase):
    PINNED = va.pinned_fingerprint()

    def _report(self, output: str, code: int = 0) -> tuple:
        original = va.run
        va.run = lambda command: (code, output)
        try:
            return va.signature_report('apksigner', 'app.apk')
        finally:
            va.run = original

    @staticmethod
    def _output(v1: str = 'true', v2: str = 'true', v3: str = 'true', digest: str = '') -> str:
        return (
            'Verifies\n'
            'Verified using v1 scheme (JAR signing): %s\n'
            'Verified using v2 scheme (APK Signature Scheme v2): %s\n'
            'Verified using v3 scheme (APK Signature Scheme v3): %s\n'
            'Number of signers: 1\n'
            'Signer #1 certificate SHA-256 digest: %s\n' % (v1, v2, v3, digest)
        )

    def test_the_pinned_fingerprint_is_a_sha256_hex_string(self) -> None:
        self.assertIsNotNone(self.PINNED)
        self.assertRegex(self.PINNED, r'^[0-9a-f]{64}$')

    def test_a_v1_v2_v3_apk_with_the_stable_certificate_passes(self) -> None:
        problems, info = self._report(self._output(digest=self.PINNED))
        self.assertEqual(problems, [])
        self.assertTrue(any(line.startswith('signing certificate sha256: ') for line in info))

    def test_another_certificate_is_rejected(self) -> None:
        problems, _ = self._report(self._output(digest='0' * 64))
        self.assertTrue(any('stable key' in problem for problem in problems))

    def test_missing_v1_is_rejected(self) -> None:
        problems, _ = self._report(self._output(v1='false', digest=self.PINNED))
        self.assertTrue(any('v1' in problem for problem in problems))

    def test_missing_v2_or_v3_is_rejected(self) -> None:
        self.assertTrue(self._report(self._output(v2='false', digest=self.PINNED))[0])
        self.assertTrue(self._report(self._output(v3='false', digest=self.PINNED))[0])

    def test_apksigner_failure_is_reported(self) -> None:
        problems, _ = self._report('DOES NOT VERIFY', code=1)
        self.assertTrue(problems)


if __name__ == '__main__':
    unittest.main()
