// اختبارات دخان لغلاف التطبيق: تُبنى التبويبات الأربعة من بيانات الأصول
// الحقيقية دون أخطاء تخطيط، ويحفظ IndexedStack حالتها، وتفتح النقرات الخمس
// على رقم الإصدار لوحة الإدخال المحلية، ويُفتح وِرد اليوم من المسار.

import 'dart:io';

import 'package:flutter/material.dart' show Text;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/app/app_shell_screen.dart';
import 'package:hadith_platform/app/hadith_app.dart';
import 'package:hadith_platform/core/content/asset_json_source.dart';
import 'package:hadith_platform/core/storage/key_value_store.dart';
import 'package:hadith_platform/core/time/clock.dart';
import 'package:hadith_platform/features/admin/presentation/admin_export_screen.dart';
import 'package:hadith_platform/features/daily_session/presentation/daily_hadith_session_screen.dart';
import 'package:hadith_platform/features/hadith/application/hadith_providers.dart';
import 'package:hadith_platform/features/journey/application/journey_controller.dart';
import 'package:hadith_platform/features/journey/application/journey_progress_controller.dart';
import 'package:hadith_platform/features/journey/application/pacing_notifier.dart';
import 'package:hadith_platform/features/journey/presentation/widgets/caravan_trail_view.dart';
import 'package:hadith_platform/features/journey/presentation/widgets/wird_node.dart';
import 'package:hadith_platform/features/settings/presentation/settings_screen.dart';

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

Future<void> _pumpApp(WidgetTester tester) async {
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
  if (find.byType(CaravanTrailView).evaluate().isEmpty) {
    final String texts = find
        .byType(Text)
        .evaluate()
        .map((Element e) => (e.widget as Text).data ?? '')
        .join(' | ');
    final ProviderContainer container = ProviderScope.containerOf(tester.element(find.byType(AppShellScreen)));
    final String journey = container.read(journeyControllerProvider).toString();
    final String curriculum = container.read(curriculumProvider).toString();
    final String progress = container.read(journeyProgressProvider).toString();
    final String pacing = container.read(pacingProvider).toString();
    final String tree = find.byType(IndexedStack).evaluate().length.toString();
    final String deep = tester.binding.rootElement!.toStringDeep();
    final int at = deep.indexOf('IndexedStack');
    final String dump = at < 0 ? 'no IndexedStack' : deep.substring(at, at + 6000 > deep.length ? deep.length : at + 6000);
    // ignore: avoid_print
    print('TREE>>>\n$dump\n<<<TREE');
    fail('Arbaeen path did not render. texts: $texts; stacks: $tree; journey: $journey; curriculum: $curriculum; progress: $progress; pacing: $pacing');
  }
}

void main() {
  testWidgets('the shell builds all four tabs and opens the hidden admin gate', (WidgetTester tester) async {
    await _pumpApp(tester);

    expect(find.byType(CaravanTrailView), findsOneWidget);
    expect(find.byType(WirdNodeView), findsNWidgets(42));
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
    await tester.scrollUntilVisible(
      version,
      300,
      scrollable: find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first,
    );
    expect(version, findsOneWidget);

    await tester.tap(_navLabel('الأربعين النووية'));
    await _settle(tester);
    expect(find.byType(CaravanTrailView), findsOneWidget);

    await tester.tap(_navLabel('الإعدادات'));
    await _settle(tester);
    for (int i = 0; i < 5; i++) {
      await tester.tap(version);
      await tester.pump(const Duration(milliseconds: 120));
    }
    await _settle(tester);
    expect(find.byType(AdminExportScreen), findsOneWidget);
    expect(find.text('لوحة الإدخال المحلية'), findsOneWidget);
  });

  testWidgets("today's wird opens from the path into the four-stage session", (WidgetTester tester) async {
    await _pumpApp(tester);

    final Finder todayNode = find.descendant(
      of: find.byType(WirdNodeView),
      matching: find.text('الأعمال بالنيات'),
    );
    await tester.tap(todayNode.first);
    await _settle(tester);
    expect(find.text('بدء وِرد التثبيت اللمسي'), findsOneWidget);

    await tester.tap(find.text('بدء وِرد التثبيت اللمسي'));
    await _settle(tester);
    expect(find.byType(DailyHadithSessionScreen), findsOneWidget);
    expect(find.text('سياق الورود'), findsWidgets);
  });
}
