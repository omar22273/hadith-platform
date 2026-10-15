// أدوات مشتركة لاختبارات الأذكار: قراءة ملفات البيانات من القرص، وتسجيل الاهتزازات،
// وفتح تبويب الأذكار ثم فئة أو السبحة منه.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/app/app_shell_screen.dart';
import 'package:hadith_platform/core/content/asset_json_source.dart';
import 'package:hadith_platform/core/json/json_reader.dart';
import 'package:hadith_platform/core/storage/key_value_store.dart';
import 'package:hadith_platform/features/adhkar/application/adhkar_providers.dart';
import 'package:hadith_platform/features/adhkar/data/models/adhkar.dart';
import 'package:hadith_platform/features/adhkar/domain/adhkar_category.dart';
import 'package:hadith_platform/features/sunan/data/models/sunan.dart';
import 'package:hadith_platform/features/sunan/domain/sunan_info.dart';

import 'app_harness.dart';

/// يقرأ ملف JSON من القرص.
JsonMap loadJson(String path) => asJsonMap(jsonDecode(File(path).readAsStringSync()), path);

/// ملف فئة بعد التحويل إلى النموذج.
AdhkarCatalog loadCategory(AdhkarCategory category) => AdhkarCatalog.fromJson(loadJson(category.assetPath));

/// ملف السنن المهجورة بعد التحويل إلى النموذج.
SunanCatalog loadSunan() => SunanCatalog.fromJson(loadJson(SunanInfo.assetPath));

/// أذكار مسار من فئة ذات تبديل بترتيب عرضها؛ وأذكار الفئة كلها إن لم تكن لها مسارات.
/// بلا [trackId] يُؤخذ المسار الأول، وهو الذي يُفتح عليه المشغّل.
List<DhikrItem> loadScopeItems(AdhkarCategory category, [String? trackId]) {
  final List<DhikrItem> all = loadCategory(category).itemsInOrder;
  final String? track = trackId ?? category.firstTrack?.id;
  if (track == null) {
    return all;
  }
  return List<DhikrItem>.unmodifiable(all.where((DhikrItem item) => item.inTrack(track)));
}

/// مفتاح نطاق الوِرد لمسار (أو لفئة بلا تبديل).
String scopeKeyOf(AdhkarCategory category, [String? trackId]) {
  return category.scopeFor(trackId ?? category.firstTrack?.id).key;
}

/// يسجل كل اهتزاز بنوعه.
List<String> recordHaptics(WidgetTester tester) {
  final List<String> haptics = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
    if (call.method == 'HapticFeedback.vibrate') {
      haptics.add(call.arguments as String);
    }
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return haptics;
}

/// حاوية بلا واجهة: ملفات الأذكار من القرص ومخزن في الذاكرة.
ProviderContainer makeContainer({Map<String, String>? stored, InMemoryKeyValueStore? store}) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      keyValueStoreProvider.overrideWithValue(store ?? InMemoryKeyValueStore(stored)),
      assetJsonSourceProvider.overrideWithValue(AssetJsonSource(DiskBundle())),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Finder navLabel(String label) {
  return find.descendant(of: find.byType(AppBottomBar), matching: find.text(label));
}

/// مفتاح بطاقة فئة في المركز.
ValueKey<String> cardKey(AdhkarCategory category) => ValueKey<String>('adhkar-card-${category.id}');

const ValueKey<String> sebhaCardKey = ValueKey<String>('adhkar-card-sebha');

/// مفتاح بطاقة السنن المهجورة في المركز.
const ValueKey<String> sunanCardKey = ValueKey<String>('adhkar-card-${SunanInfo.id}');

/// يفتح التطبيق على تبويب الأذكار (المركز) ويعيد الحاوية.
Future<ProviderContainer> openHub(
  WidgetTester tester, {
  Size size = const Size(412, 2200),
  double systemTextScale = 1,
  Map<String, String>? stored,
}) async {
  final ProviderContainer container = await pumpApp(
    tester,
    size: size,
    systemTextScale: systemTextScale,
    stored: stored,
  );
  await tester.tap(navLabel('وِرد الأذكار'));
  await settle(tester);
  return container;
}

/// يمرر قائمة المركز حتى تظهر البطاقة؛ القائمة كسولة فلا تُبنى البطاقات البعيدة قبل ذلك.
Future<void> revealCard(WidgetTester tester, Finder card) async {
  await tester.scrollUntilVisible(
    card,
    300,
    scrollable: find.descendant(of: find.byKey(const ValueKey<String>('adhkar-hub')), matching: find.byType(Scrollable)),
  );
  await tester.pump();
}

/// يفتح فئة من المركز، وينتظر تحميل ملفها، ويعيد الحاوية.
Future<ProviderContainer> openCategory(
  WidgetTester tester,
  AdhkarCategory category, {
  Size size = const Size(412, 2200),
  double systemTextScale = 1,
}) async {
  final ProviderContainer container = await openHub(tester, size: size, systemTextScale: systemTextScale);
  await revealCard(tester, find.byKey(cardKey(category)));
  await tester.tap(find.byKey(cardKey(category)));
  await settle(tester);
  await container.read(adhkarCatalogProvider(category.id).future);
  await settle(tester);
  return container;
}

/// يختار مساراً من شريط التبديل في المشغّل المفتوح.
Future<void> selectTrack(WidgetTester tester, String trackId) async {
  await tester.tap(find.byKey(ValueKey<String>('adhkar-track-$trackId')));
  await settle(tester);
}

/// يفتح السبحة من المركز.
Future<ProviderContainer> openSebha(
  WidgetTester tester, {
  Size size = const Size(412, 915),
  double systemTextScale = 1,
  Map<String, String>? stored,
}) async {
  final ProviderContainer container =
      await openHub(tester, size: size, systemTextScale: systemTextScale, stored: stored);
  await revealCard(tester, find.byKey(sebhaCardKey));
  await tester.tap(find.byKey(sebhaCardKey));
  await settle(tester);
  return container;
}
