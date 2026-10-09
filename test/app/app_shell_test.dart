// اختبار دخان لغلاف التطبيق: تُبنى التبويبات الأربعة من بيانات الأصول الحقيقية
// دون أخطاء تخطيط، ويحفظ IndexedStack حالتها، وتفتح النقرات الخمس على رقم
// الإصدار لوحة الإدخال المحلية.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/app/app_shell_screen.dart';
import 'package:hadith_platform/app/hadith_app.dart';
import 'package:hadith_platform/core/content/asset_json_source.dart';
import 'package:hadith_platform/core/storage/key_value_store.dart';
import 'package:hadith_platform/core/time/clock.dart';
import 'package:hadith_platform/features/hadith/application/hadith_providers.dart';
import 'package:hadith_platform/features/journey/application/journey_controller.dart';
import 'package:hadith_platform/features/journey/application/journey_progress_controller.dart';
import 'package:hadith_platform/features/journey/application/pacing_notifier.dart';

/// حزمة أصول تقرأ من القرص مباشرة، فلا تحتاج قراءة الملفات الكبيرة إلى عزلة.
class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    return ByteData.sublistView(File(key).readAsBytesSync());
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    return File(key).readAsStringSync();
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _navLabel(String label) {
  return find.descendant(of: find.byType(AppBottomBar), matching: find.text(label));
}

void main() {
  testWidgets('the shell builds all four tabs and opens the hidden admin gate', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1236, 2745);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
          assetJsonSourceProvider.overrideWithValue(AssetJsonSource(_DiskBundle())),
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 9, 10)),
        ],
        child: const HadithApp(),
      ),
    );
    await _settle(tester);

    final ProviderContainer container = ProviderScope.containerOf(tester.element(find.byType(HadithApp)));
    printOnFailure('curriculum: ${container.read(curriculumProvider)}');
    printOnFailure('progress: ${container.read(journeyProgressProvider)}');
    printOnFailure('pacing: ${container.read(pacingProvider)}');
    printOnFailure('journey: ${container.read(journeyControllerProvider)}');
    expect(find.text('مسار الأربعين'), findsWidgets);
    expect(find.text('الأعمال بالنيات'), findsWidgets);
    expect(find.text('قيد الإعداد'), findsWidgets);

    await tester.tap(_navLabel('رحلة السيرة'));
    await _settle(tester);
    expect(find.text('المولد في عام الفيل'), findsWidgets);

    await tester.tap(_navLabel('ميدان المراجعة'));
    await _settle(tester);
    expect(find.text('يُفتح الميدان بعد أول وِرد'), findsOneWidget);

    await tester.tap(_navLabel('الإعدادات'));
    await _settle(tester);
    final Finder version = find.text('Version 2.0.0');
    await tester.scrollUntilVisible(version, 300);
    expect(version, findsOneWidget);

    await tester.tap(_navLabel('الأربعين النووية'));
    await _settle(tester);
    expect(find.text('مسار الأربعين'), findsWidgets);

    await tester.tap(_navLabel('الإعدادات'));
    await _settle(tester);
    for (int i = 0; i < 5; i++) {
      await tester.tap(version);
      await tester.pump(const Duration(milliseconds: 120));
    }
    await _settle(tester);
    expect(find.text('لوحة الإدخال المحلية'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
