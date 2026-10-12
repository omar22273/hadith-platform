// مزودات وِرد الأذكار: المستودع، والملف بعد فحص سلامته، وأذكاره مرتبة،
// وإمهال الانتقال التلقائي بعد إتمام ذكر (تستبدله الاختبارات).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/content/asset_json_source.dart';
import '../data/asset_adhkar_repository.dart';
import '../data/models/adhkar.dart';
import '../domain/adhkar_repository.dart';

/// المستودع.
final Provider<AdhkarRepository> adhkarRepositoryProvider = Provider<AdhkarRepository>(
  (Ref ref) => AssetAdhkarRepository(ref.watch(assetJsonSourceProvider)),
);

/// ملف الأذكار بعد فحص سلامته.
final FutureProvider<AdhkarCatalog> adhkarCatalogProvider = FutureProvider<AdhkarCatalog>(
  (Ref ref) => ref.watch(adhkarRepositoryProvider).loadCatalog(),
  retry: contentNoRetry,
);

/// الأذكار بترتيب عرضها؛ فارغة حتى يُحمَّل الملف.
final Provider<List<DhikrItem>> adhkarItemsProvider = Provider<List<DhikrItem>>(
  (Ref ref) => ref.watch(adhkarCatalogProvider).value?.itemsInOrder ?? const <DhikrItem>[],
);

/// المهلة بين بلوغ العدد المسنون والانتقال التلقائي إلى الذكر التالي، تتيح
/// رؤية الهالة الخضراء قبل الانتقال.
final Provider<Duration> adhkarAutoAdvanceDelayProvider = Provider<Duration>(
  (Ref ref) => const Duration(milliseconds: 1400),
);
