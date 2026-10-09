// أدوات مشتركة لاختبارات الواجهة: حزمة أصول من القرص، ومخزن في الذاكرة،
// وتشغيل التطبيق كاملاً بمقاس هاتف محدد.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/app/hadith_app.dart';
import 'package:hadith_platform/core/content/asset_json_source.dart';
import 'package:hadith_platform/core/share/share_service.dart';
import 'package:hadith_platform/core/storage/key_value_store.dart';
import 'package:hadith_platform/core/time/clock.dart';
import 'package:hadith_platform/features/journey/domain/journey_progress.dart';

/// حزمة أصول تقرأ من القرص مباشرة.
class DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    return ByteData.sublistView(File(key).readAsBytesSync());
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    return File(key).readAsStringSync();
  }
}

/// يقدّم الزمن في الاختبار على دفعات قصيرة حتى تستقر الحركات والتحميلات.
Future<void> settle(WidgetTester tester) async {
  for (int i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// تقدم يعدّ الحديثين المُعدّين مكتملين.
String completedProgressJson() {
  final DateTime at = DateTime(2026, 10, 8, 9);
  return jsonEncode(
    JourneyProgress(
      completed: <CompletedWird>[
        CompletedWird(hadithId: 'nawawi40_001', completedAt: at),
        CompletedWird(hadithId: 'nawawi40_002', completedAt: at),
      ],
    ).toJson(),
  );
}

/// يشغّل التطبيق. [size] بالبكسل المنطقي.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  Map<String, String>? stored,
  Size size = const Size(412, 915),
  double systemTextScale = 1,
  ShareService? shareService,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = systemTextScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore(stored)),
        assetJsonSourceProvider.overrideWithValue(AssetJsonSource(DiskBundle())),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 9, 10)),
        if (shareService != null) shareServiceProvider.overrideWithValue(shareService),
      ],
      child: const HadithApp(),
    ),
  );
  await settle(tester);
  return ProviderScope.containerOf(tester.element(find.byType(HadithApp)));
}
