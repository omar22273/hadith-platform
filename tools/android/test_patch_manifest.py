"""Tests for tools/android/patch_manifest.py.

Run: python3 -m unittest discover -s tools/android -p 'test_*.py' -v

The fixtures reproduce what `flutter create` generates (manifest, Kotlin and
Groovy app build files), so the patch is exercised on the same shapes CI sees.
"""

import os
import tempfile
import unittest
import xml.etree.ElementTree as ET

import patch_manifest as pm

ANDROID = '{http://schemas.android.com/apk/res/android}'

TEMPLATE_MANIFEST = """<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="hadith_platform"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <!-- Specifies an Android theme to apply to this Activity as soon as
                 the Android process has started. -->
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <!-- Don't delete the meta-data below.
             This is used by the Flutter tool to generate GeneratedPluginRegistrant.java -->
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
    <!-- Required to query activities that can process text, see:
         https://developer.android.com/training/package-visibility and
         https://developer.android.com/reference/android/content/Intent#ACTION_PROCESS_TEXT.

         In particular, this is used by the Flutter engine in io.flutter.plugin.text.ProcessTextPlugin. -->
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
</manifest>
"""

TEMPLATE_KTS = """plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.hadithplatform.hadith_platform"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.hadithplatform.hadith_platform"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
"""

TEMPLATE_GROOVY = """plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
}

android {
    namespace "app.hadithplatform.hadith_platform"
    compileSdk flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId "app.hadithplatform.hadith_platform"
        minSdkVersion flutter.minSdkVersion
        targetSdkVersion flutter.targetSdkVersion
        versionCode flutter.versionCode
        versionName flutter.versionName
    }

    buildTypes {
        release {
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig signingConfigs.debug
        }
    }
}

flutter {
    source "../.."
}
"""


def _release_block(text: str) -> str:
    build_types = pm._find_block(text, 'buildTypes')
    release = pm._find_block(text, 'release', build_types[0] + 1, build_types[1])
    return text[release[0] + 1: release[1]]


class ManifestPatchTest(unittest.TestCase):
    def setUp(self) -> None:
        self.patched = pm.patch(TEMPLATE_MANIFEST)
        self.root = ET.fromstring(self.patched.encode('utf-8'))

    def test_patched_manifest_is_valid_xml_with_a_sound_structure(self) -> None:
        self.assertEqual(pm.validate_manifest(self.patched), [])

    def test_permissions_sit_directly_under_manifest_never_under_application(self) -> None:
        direct = {p.get(ANDROID + 'name') for p in self.root.findall('uses-permission')}
        self.assertEqual(direct, {'android.permission.INTERNET', *pm.PERMISSIONS})
        application = self.root.find('application')
        self.assertIsNone(application.find('uses-permission'))
        self.assertEqual(len(list(self.root.iter('uses-permission'))), len(direct))

    def test_main_activity_is_exported_and_portrait(self) -> None:
        activity = self.root.find('application/activity')
        self.assertEqual(activity.get(ANDROID + 'name'), '.MainActivity')
        self.assertEqual(activity.get(ANDROID + 'exported'), 'true')
        self.assertEqual(activity.get(ANDROID + 'screenOrientation'), 'portrait')

    def test_application_attributes_receivers_and_queries(self) -> None:
        application = self.root.find('application')
        self.assertEqual(application.get(ANDROID + 'label'), pm.LABEL)
        self.assertEqual(application.get(ANDROID + 'networkSecurityConfig'), '@xml/network_security_config')
        receivers = {r.get(ANDROID + 'name'): r for r in application.findall('receiver')}
        self.assertEqual(
            set(receivers),
            {
                'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver',
                'com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver',
            },
        )
        for receiver in receivers.values():
            self.assertIsNotNone(receiver.get(ANDROID + 'exported'))
        actions = {a.get(ANDROID + 'name') for a in self.root.find('queries').iter('action')}
        self.assertEqual(actions, {'android.intent.action.PROCESS_TEXT', 'android.intent.action.TTS_SERVICE'})
        self.assertIsNone(application.find('queries'))

    def test_patch_is_idempotent(self) -> None:
        self.assertEqual(pm.patch(self.patched), self.patched)

    def test_a_missing_or_false_export_on_the_launcher_is_corrected(self) -> None:
        without = TEMPLATE_MANIFEST.replace('            android:exported="true"\n', '')
        self.assertNotIn('android:exported', without)
        for source in (without, TEMPLATE_MANIFEST.replace('android:exported="true"', 'android:exported="false"')):
            patched = pm.patch(source)
            self.assertEqual(pm.validate_manifest(patched), [])
            activity = ET.fromstring(patched.encode('utf-8')).find('application/activity')
            self.assertEqual(activity.get(ANDROID + 'exported'), 'true')

    def test_manifest_without_queries_gets_one_directly_under_manifest(self) -> None:
        start = TEMPLATE_MANIFEST.index('    <!-- Required to query')
        end = TEMPLATE_MANIFEST.index('</manifest>')
        patched = pm.patch(TEMPLATE_MANIFEST[:start] + TEMPLATE_MANIFEST[end:])
        self.assertEqual(pm.validate_manifest(patched), [])
        self.assertIsNotNone(ET.fromstring(patched.encode('utf-8')).find('queries'))

    def test_validator_rejects_broken_manifests(self) -> None:
        self.assertTrue(pm.validate_manifest('<manifest><application></manifest>'))
        inside = self.patched.replace(
            '<application', '<application', 1
        ).replace('<meta-data', '<uses-permission android:name="x.Y" />\n        <meta-data', 1)
        self.assertTrue(any('direct child' in p for p in pm.validate_manifest(inside)))
        unexported = TEMPLATE_MANIFEST.replace('            android:exported="true"\n', '')
        problems = pm.validate_manifest(unexported)
        self.assertTrue(any('exported' in p for p in problems), problems)
        duplicate = self.patched.replace(
            '<uses-permission android:name="android.permission.VIBRATE" />',
            '<uses-permission android:name="android.permission.VIBRATE" />\n'
            '    <uses-permission android:name="android.permission.VIBRATE" />',
            1,
        )
        self.assertTrue(any('Duplicate' in p for p in pm.validate_manifest(duplicate)))

    def test_main_writes_a_valid_manifest_and_the_network_config(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            main_dir = os.path.join(folder, 'app', 'src', 'main')
            os.makedirs(main_dir)
            with open(os.path.join(main_dir, 'AndroidManifest.xml'), 'w', encoding='utf-8') as handle:
                handle.write(TEMPLATE_MANIFEST)
            with open(os.path.join(folder, 'app', 'build.gradle.kts'), 'w', encoding='utf-8') as handle:
                handle.write(TEMPLATE_KTS)
            self.assertEqual(pm.main(['patch_manifest.py', folder]), 0)
            with open(os.path.join(main_dir, 'AndroidManifest.xml'), encoding='utf-8') as handle:
                self.assertEqual(pm.validate_manifest(handle.read()), [])
            config = os.path.join(main_dir, 'res', 'xml', 'network_security_config.xml')
            ET.parse(config)


class GradleSigningTest(unittest.TestCase):
    def test_the_template_signing_is_kept_and_desugaring_is_added(self) -> None:
        patched = pm.patch_gradle(TEMPLATE_KTS, True)
        self.assertIn(pm.SIGNING_KTS, _release_block(patched))
        self.assertEqual(patched.count('signingConfig'), TEMPLATE_KTS.count('signingConfig'))
        self.assertIn('isCoreLibraryDesugaringEnabled = true', patched)
        self.assertIn('multiDexEnabled = true', patched)
        self.assertIn('coreLibraryDesugaring("%s")' % pm.DESUGAR_LIB, patched)
        self.assertEqual(pm.patch_gradle(patched, True), patched)

    def test_groovy_template(self) -> None:
        patched = pm.patch_gradle(TEMPLATE_GROOVY, False)
        self.assertIn(pm.SIGNING_GROOVY, _release_block(patched))
        self.assertIn('coreLibraryDesugaringEnabled true', patched)
        self.assertEqual(pm.patch_gradle(patched, False), patched)

    def test_release_without_a_signing_line_gets_the_debug_one(self) -> None:
        bare = TEMPLATE_KTS.replace('signingConfig = signingConfigs.getByName("debug")\n', '')
        self.assertNotIn(pm.SIGNING_KTS, bare)
        patched = pm.patch_gradle(bare, True)
        self.assertIn(pm.SIGNING_KTS, _release_block(patched))
        self.assertEqual(pm.patch_gradle(patched, True), patched)

    def test_a_commented_out_signing_line_does_not_count(self) -> None:
        commented = TEMPLATE_KTS.replace(
            '            signingConfig = signingConfigs.getByName("debug")',
            '            // signingConfig = signingConfigs.getByName("debug")',
        )
        patched = pm.patch_gradle(commented, True)
        active = [
            line.strip()
            for line in _release_block(patched).splitlines()
            if line.strip().startswith('signingConfig')
        ]
        self.assertEqual(active, [pm.SIGNING_KTS])

    def test_another_signing_config_is_replaced_by_debug(self) -> None:
        other = TEMPLATE_KTS.replace('getByName("debug")', 'getByName("release")')
        patched = pm.patch_gradle(other, True)
        self.assertIn(pm.SIGNING_KTS, _release_block(patched))
        self.assertNotIn('getByName("release")', patched)

    def test_missing_release_block_or_build_types(self) -> None:
        no_release = TEMPLATE_KTS.replace(
            'release {\n            // TODO: Add your own signing config for the release build.\n'
            '            // Signing with the debug keys for now, so `flutter run --release` works.\n'
            '            signingConfig = signingConfigs.getByName("debug")\n        }',
            'debug {\n        }',
        )
        self.assertNotIn('signingConfigs', no_release)
        self.assertIn(pm.SIGNING_KTS, _release_block(pm.patch_gradle(no_release, True)))
        start = TEMPLATE_GROOVY.index('    buildTypes {')
        end = TEMPLATE_GROOVY.index('}\n\nflutter {')
        no_types = TEMPLATE_GROOVY[:start] + TEMPLATE_GROOVY[end:]
        self.assertNotIn('buildTypes', no_types)
        patched = pm.patch_gradle(no_types, False)
        self.assertIn(pm.SIGNING_GROOVY, _release_block(patched))
        self.assertEqual(pm.patch_gradle(patched, False), patched)

    def test_braces_in_comments_and_strings_do_not_confuse_the_block_search(self) -> None:
        tricky = TEMPLATE_KTS.replace(
            '    buildTypes {',
            '    // a stray { in a comment\n    val note = "{ not a block"\n    buildTypes {',
        ).replace('signingConfig = signingConfigs.getByName("debug")\n', '')
        patched = pm.patch_gradle(tricky, True)
        self.assertIn(pm.SIGNING_KTS, _release_block(patched))
        self.assertEqual(patched.count(pm.SIGNING_KTS), 1)
        self.assertEqual(pm.patch_gradle(patched, True), patched)


if __name__ == '__main__':
    unittest.main()
