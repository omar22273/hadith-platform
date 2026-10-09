// اختبارات التفضيلات والإعدادات: السمة المحفوظة، وحدود الخطوط والحجم،
// وقالب رابط التلاوة على شبكة التوزيع.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/core/config/app_config.dart';
import 'package:hadith_platform/core/preferences/reading_preferences.dart';
import 'package:hadith_platform/core/preferences/theme_preference.dart';
import 'package:hadith_platform/core/storage/key_value_store.dart';
import 'package:hadith_platform/core/theme/app_palette.dart';
import 'package:hadith_platform/core/theme/app_theme.dart';

void main() {
  test('the theme choice is persisted and restored', () async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    final ProviderContainer first = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
    );
    addTearDown(first.dispose);
    expect(first.read(themePreferenceProvider), ThemePreference.system);
    first.read(themePreferenceProvider.notifier).select(ThemePreference.parchment);
    await Future<void>.delayed(Duration.zero);
    expect(store.readString(StorageKeys.themeMode), 'parchment');

    final ProviderContainer second = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
    );
    addTearDown(second.dispose);
    expect(second.read(themePreferenceProvider), ThemePreference.parchment);
    expect(second.read(themePreferenceProvider).themeMode, ThemeMode.light);
  });

  test('the warm parchment palette uses the specified colors', () {
    const AppPalette light = AppPalette.light;
    expect(light.paper, const Color(0xFFF8F6F0));
    expect(light.surface, const Color(0xFFFFFFFF));
    expect(light.line, const Color(0xFFE2E8F0));
    expect(light.ink, const Color(0xFF0F172A));
    expect(light.inkSoft, const Color(0xFF475569));
    expect(AppTheme.light().scaffoldBackgroundColor, const Color(0xFFF8F6F0));
    expect(AppTheme.dark().scaffoldBackgroundColor, AppPalette.dark.paper);
  });

  test('reading preferences clamp out-of-range and corrupt values', () {
    final ReadingPreferences prefs = ReadingPreferences.fromJson(const <String, dynamic>{
      'matnFontSize': 99,
      'textScale': 0.1,
      'matnFont': 'unknown',
    });
    expect(prefs.matnFontSize, ReadingPreferences.maxMatnFontSize);
    expect(prefs.textScale, ReadingPreferences.minTextScale);
    expect(prefs.matnFont, MatnFont.amiri);
    expect(prefs.readingTheme.matnScale, ReadingPreferences.maxMatnFontSize / ReadingPreferences.baseMatnFontSize);
  });

  test('reading preferences survive a restart', () async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore(<String, String>{
      StorageKeys.readingPreferences: 'not json',
    });
    final ProviderContainer container = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    expect(container.read(readingPreferencesProvider), ReadingPreferences.defaults);
    container.read(readingPreferencesProvider.notifier).setMatnFontSize(32);
    container.read(readingPreferencesProvider.notifier).setMatnFont(MatnFont.readex);
    await Future<void>.delayed(Duration.zero);
    final ProviderContainer restarted = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
    );
    addTearDown(restarted.dispose);
    expect(restarted.read(readingPreferencesProvider).matnFontSize, 32);
    expect(restarted.read(readingPreferencesProvider).matnFont, MatnFont.readex);
  });

  test('the CDN template builds the audio url of a hadith', () {
    const AppConfig config = AppConfig(
      version: '2.0.0',
      audioUrlTemplate: AppConfig.defaultAudioUrlTemplate,
      audioLoadTimeout: Duration(seconds: 5),
    );
    expect(
      config.audioUrlFor('nawawi40_001').toString(),
      'https://cdn.hadithplatform.app/audio/hadith_nawawi40_001.mp3',
    );
    expect(AppConfig.standard.version, '2.0.0');
  });
}
