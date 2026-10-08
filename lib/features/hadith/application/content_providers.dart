// مزودات المحتوى: تقرأ الفهارس والأحاديث من المستودع مرة واحدة وتحتفظ بها.
//
// تُعطّل إعادة المحاولة التلقائية: خطأ في ملف أصول لن يُصلحه التكرار.

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../data/asset_content_repository.dart';
import '../data/models/models.dart';
import '../domain/content_repository.dart';
import '../domain/hadith_bundle.dart';

Duration? _noRetry(int retryCount, Object error) => null;

/// المستودع.
final Provider<ContentRepository> contentRepositoryProvider =
    Provider<ContentRepository>(
  (Ref ref) => AssetContentRepository(AssetJsonSource(rootBundle)),
);

/// المنهج.
final FutureProvider<CurriculumManifest> curriculumProvider =
    FutureProvider<CurriculumManifest>(
  (Ref ref) => ref.watch(contentRepositoryProvider).loadCurriculum(),
  retry: _noRetry,
);

/// فهرس مسار القوافل.
final FutureProvider<JourneyCatalog> journeyCatalogProvider =
    FutureProvider<JourneyCatalog>(
  (Ref ref) => ref.watch(contentRepositoryProvider).loadJourney(),
  retry: _noRetry,
);

/// فهرس الرواة.
final FutureProvider<NarratorCatalog> narratorCatalogProvider =
    FutureProvider<NarratorCatalog>(
  (Ref ref) => ref.watch(contentRepositoryProvider).loadNarrators(),
  retry: _noRetry,
);

/// فهرس المصادر.
final FutureProvider<SourceCatalog> sourceCatalogProvider =
    FutureProvider<SourceCatalog>(
  (Ref ref) => ref.watch(contentRepositoryProvider).loadSources(),
  retry: _noRetry,
);

/// بنك العبارات التراثية.
final FutureProvider<WisdomCatalog> wisdomCatalogProvider =
    FutureProvider<WisdomCatalog>(
  (Ref ref) => ref.watch(contentRepositoryProvider).loadWisdom(),
  retry: _noRetry,
);

/// حديث واحد بعد فحص سلامته.
final FutureProviderFamily<HadithDailyModel, String> hadithProvider =
    FutureProvider.family<HadithDailyModel, String>(
  (Ref ref, String hadithId) {
    return ref.watch(contentRepositoryProvider).loadHadith(hadithId);
  },
  retry: _noRetry,
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
  retry: _noRetry,
);
