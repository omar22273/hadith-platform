// مزودات مركز الأذكار: المستودع، وملف كل فئة بعد فحص سلامته، وأذكار الفئة مرتبة،
// وإمهال الانتقال التلقائي بعد إتمام ذكر (تستبدله الاختبارات).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../../../core/content/asset_json_source.dart';
import '../data/asset_adhkar_repository.dart';
import '../data/models/adhkar.dart';
import '../domain/adhkar_category.dart';
import '../domain/adhkar_repository.dart';

/// المستودع.
final Provider<AdhkarRepository> adhkarRepositoryProvider = Provider<AdhkarRepository>(
  (Ref ref) => AssetAdhkarRepository(ref.watch(assetJsonSourceProvider)),
);

/// ملف فئة بمعرّفها بعد فحص سلامته.
final FutureProviderFamily<AdhkarCatalog, String> adhkarCatalogProvider =
    FutureProvider.family<AdhkarCatalog, String>(
  (Ref ref, String categoryId) {
    final AdhkarCategory? category = AdhkarCategories.byId(categoryId);
    if (category == null) {
      throw ArgumentError.value(categoryId, 'categoryId', 'Unknown adhkar category');
    }
    return ref.watch(adhkarRepositoryProvider).loadCategory(category);
  },
  retry: contentNoRetry,
);

/// أذكار نطاق بترتيب عرضها؛ فارغة حتى يُحمَّل ملف الفئة. المفتاح «معرّف الفئة» لأذكار الفئة
/// كلها، أو «معرّف الفئة#المسار» لأذكار مسار واحد من فئة ذات تبديل (انظر [AdhkarScope]).
final ProviderFamily<List<DhikrItem>, String> adhkarItemsProvider = Provider.family<List<DhikrItem>, String>(
  (Ref ref, String scopeKey) {
    final AdhkarScope scope = AdhkarScope.parse(scopeKey);
    final List<DhikrItem> all = ref.watch(adhkarCatalogProvider(scope.categoryId)).value?.itemsInOrder ?? const <DhikrItem>[];
    final String? trackId = scope.trackId;
    if (trackId == null) {
      return all;
    }
    return List<DhikrItem>.unmodifiable(all.where((DhikrItem item) => item.inTrack(trackId)));
  },
);

/// المهلة بين بلوغ العدد المسنون والانتقال التلقائي إلى الذكر التالي، تتيح
/// رؤية الهالة الخضراء قبل الانتقال.
final Provider<Duration> adhkarAutoAdvanceDelayProvider = Provider<Duration>(
  (Ref ref) => const Duration(milliseconds: 1400),
);
