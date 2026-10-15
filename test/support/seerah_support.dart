// أدوات مشتركة لاختبارات شاشة المحطة: تحميل ملف السيرة الحقيقي ومصادره، وتحويل محطة
// إلى محطة بلا طبقة معايشة (كالتي تُولَّد من نص الكتاب)، وفتح شاشة المحطة وحدها فوق
// ملف سيرة مخصص بسمة تتبع إعدادات القراءة كما في التطبيق.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/core/content/asset_json_source.dart';
import 'package:hadith_platform/core/content/models/content_models.dart';
import 'package:hadith_platform/core/json/json_reader.dart';
import 'package:hadith_platform/core/preferences/reading_preferences.dart';
import 'package:hadith_platform/core/storage/key_value_store.dart';
import 'package:hadith_platform/core/theme/app_theme.dart';
import 'package:hadith_platform/features/seerah/application/seerah_providers.dart';
import 'package:hadith_platform/features/seerah/data/models/seerah_station.dart';
import 'package:hadith_platform/features/seerah/presentation/seerah_station_screen.dart';

import 'app_harness.dart';

/// يقرأ ملف JSON من القرص.
JsonMap loadJsonFile(String path) => asJsonMap(jsonDecode(File(path).readAsStringSync()), path);

/// ملف السيرة الحقيقي.
SeerahDataset loadSeerahDataset() => SeerahDataset.fromJson(loadJsonFile('assets/data/seerah_dataset.json'));

/// فهرس المصادر الحقيقي.
SourceCatalog loadSourceCatalog() => SourceCatalog.fromJson(loadJsonFile('assets/data/catalogs/sources.json'));

/// المحطة بلا طبقة المعايشة والموقف: لا مشهد ولا مأزق ولا قرار ولا تمهيد ولا سؤال ولا خيارات ولا شواهد،
/// وتبقى بوصلتها وروابطها وفصولها؛ هيئة المحطة المولّدة من نص الكتاب.
SeerahStationModel withoutExperience(SeerahStationModel station) {
  final JsonMap json = Map<String, dynamic>.of(station.toJson())
    ..remove('sceneDescription')
    ..remove('challenge')
    ..remove('propheticDecision')
    ..remove('hook')
    ..remove('shura_question')
    ..remove('dilemma_options')
    ..['evidence'] = <dynamic>[];
  return SeerahStationModel.fromJson(json);
}

/// المحطة وقد عُدّلت خريطتها بـ[edit].
SeerahStationModel editedStation(SeerahStationModel station, void Function(JsonMap json) edit) {
  final JsonMap json = Map<String, dynamic>.of(station.toJson());
  edit(json);
  return SeerahStationModel.fromJson(json);
}

/// الملف وقد بُدّلت فيه المحطة التي معرّفها كمعرّف [replacement] بها.
SeerahDataset replacingStation(SeerahDataset dataset, SeerahStationModel replacement) {
  return SeerahDataset(
    schemaVersion: dataset.schemaVersion,
    id: dataset.id,
    title: dataset.title,
    epochs: dataset.epochs,
    stations: <SeerahStationModel>[
      for (final SeerahStationModel station in dataset.stations)
        if (station.id == replacement.id) replacement else station,
    ],
  );
}

/// يفتح شاشة المحطة وحدها فوق [dataset]؛ السمة تتبع إعدادات القراءة فيتغير حجم خط الرواية بتغيرها.
Future<ProviderContainer> openStationScreen(
  WidgetTester tester, {
  required SeerahDataset dataset,
  required String stationId,
  Map<String, String>? stored,
  Size size = const Size(412, 1800),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore(stored)),
        assetJsonSourceProvider.overrideWithValue(AssetJsonSource(DiskBundle())),
        seerahDatasetProvider.overrideWith((Ref ref) async => dataset),
      ],
      child: Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? _) {
          return MaterialApp(
            theme: AppTheme.light(reading: ref.watch(readingPreferencesProvider).readingTheme),
            locale: const Locale('ar'),
            supportedLocales: const <Locale>[Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: SeerahStationScreen(stationId: stationId),
          );
        },
      ),
    ),
  );
  await settle(tester);
  return ProviderScope.containerOf(tester.element(find.byType(SeerahStationScreen)));
}

/// المحرك الرأسي للصفحة وحده (كل نص قابل للتحديد يحمل Scrollable داخلياً).
Finder stationPageScrollable() {
  return find.descendant(
    of: find.byKey(const ValueKey<String>('station-scroll')),
    matching: find.byType(Scrollable),
  ).first;
}

/// القائمة كسولة: ما بعد الشاشة لا يُبنى، فيُمرَّر إليه أولاً.
Future<void> scrollStationTo(WidgetTester tester, Finder target, {double delta = 300, int maxScrolls = 200}) {
  return tester.scrollUntilVisible(target, delta, maxScrolls: maxScrolls, scrollable: stationPageScrollable());
}
