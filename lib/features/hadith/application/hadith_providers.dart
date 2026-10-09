// مزودات الحديث: تقرأ المنهج والفهارس والأحاديث من HadithRepository مرة
// واحدة وتحتفظ بها.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../../../core/content/asset_json_source.dart';
import '../../../core/content/source_catalog_provider.dart';
import '../data/asset_hadith_repository.dart';
import '../data/models/models.dart';
import '../domain/hadith_bundle.dart';
import '../domain/hadith_repository.dart';

export '../../../core/content/source_catalog_provider.dart' show sourceCatalogProvider;

/// مستودع الأحاديث.
final Provider<HadithRepository> hadithRepositoryProvider = Provider<HadithRepository>(
  (Ref ref) => AssetHadithRepository(ref.watch(assetJsonSourceProvider)),
);

/// المنهج.
final FutureProvider<CurriculumManifest> curriculumProvider =
    FutureProvider<CurriculumManifest>(
  (Ref ref) => ref.watch(hadithRepositoryProvider).loadCurriculum(),
  retry: contentNoRetry,
);

/// فهرس الرواة.
final FutureProvider<NarratorCatalog> narratorCatalogProvider =
    FutureProvider<NarratorCatalog>(
  (Ref ref) => ref.watch(hadithRepositoryProvider).loadNarrators(),
  retry: contentNoRetry,
);

/// بنك العبارات التراثية.
final FutureProvider<WisdomCatalog> wisdomCatalogProvider =
    FutureProvider<WisdomCatalog>(
  (Ref ref) => ref.watch(hadithRepositoryProvider).loadWisdom(),
  retry: contentNoRetry,
);

/// حديث واحد بعد فحص سلامته.
final FutureProviderFamily<HadithDailyModel, String> hadithProvider =
    FutureProvider.family<HadithDailyModel, String>(
  (Ref ref, String hadithId) {
    return ref.watch(hadithRepositoryProvider).loadHadith(hadithId);
  },
  retry: contentNoRetry,
);

/// الحديث مع فهارس الرواة والمصادر.
final FutureProviderFamily<HadithBundle, String> hadithBundleProvider =
    FutureProvider.family<HadithBundle, String>(
  (Ref ref, String hadithId) async {
    final HadithDailyModel hadith = await ref.watch(hadithProvider(hadithId).future);
    final NarratorCatalog narrators = await ref.watch(narratorCatalogProvider.future);
    final SourceCatalog sources = await ref.watch(sourceCatalogProvider.future);
    return HadithBundle(hadith: hadith, narrators: narrators, sources: sources);
  },
  retry: contentNoRetry,
);
