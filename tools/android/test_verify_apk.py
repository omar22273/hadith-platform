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
    A: package="app.hadithplatform.hadith_platform" (Raw: "app.hadithplatform.hadith_platform")
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


class XmlTreeTest(unittest.TestCase):
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

    def test_alignment_helper(self) -> None:
        class Info:
            filename = 'resources.arsc'
            extra = b''
            header_offset = 0

        self.assertEqual(va.data_offset(Info()), 30 + len('resources.arsc'))
        self.assertEqual(va.data_offset(Info()) % 4, 0)

    def test_collect_and_main_without_apks(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            self.assertEqual(va.collect([folder]), [])
            self.assertEqual(va.main(['verify_apk.py', folder]), 1)


if __name__ == '__main__':
    unittest.main()
