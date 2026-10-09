// مزودات رحلة السيرة: المستودع، والمحطات، والخريطة، والمحطة المختارة،
// والمحطات التي فتحها المستخدم (تُحفظ محلياً).

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/content/asset_json_source.dart';
import '../../../core/storage/key_value_store.dart';
import '../data/asset_seerah_repository.dart';
import '../data/models/seerah_station.dart';
import '../domain/seerah_map.dart';
import '../domain/seerah_repository.dart';

/// المستودع.
final Provider<SeerahRepository> seerahRepositoryProvider = Provider<SeerahRepository>(
  (Ref ref) => AssetSeerahRepository(ref.watch(assetJsonSourceProvider)),
);

/// محطات الرحلة بعد فحص سلامتها.
final FutureProvider<SeerahDataset> seerahDatasetProvider = FutureProvider<SeerahDataset>(
  (Ref ref) => ref.watch(seerahRepositoryProvider).loadDataset(),
  retry: contentNoRetry,
);

/// اليابسة المرسومة.
final FutureProvider<SeerahLand> seerahLandProvider = FutureProvider<SeerahLand>(
  (Ref ref) => ref.watch(seerahRepositoryProvider).loadLand(),
  retry: contentNoRetry,
);

/// المواضع وخط السير.
final FutureProvider<SeerahRoute> seerahRouteProvider = FutureProvider<SeerahRoute>(
  (Ref ref) async {
    final SeerahDataset dataset = await ref.watch(seerahDatasetProvider.future);
    return SeerahRoute.build(dataset.chronological);
  },
  retry: contentNoRetry,
);

/// متحكم المحطة المختارة على الخريطة.
class SelectedSeerahStationController extends Notifier<String?> {
  @override
  String? build() => null;

  /// يختار محطة.
  void select(String stationId) {
    state = stationId;
  }
}

/// المحطة المختارة (null: أول محطة).
final NotifierProvider<SelectedSeerahStationController, String?> selectedSeerahStationProvider =
    NotifierProvider<SelectedSeerahStationController, String?>(SelectedSeerahStationController.new);

/// متحكم المحطات المفتوحة.
class SeerahVisitedController extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final String? raw = ref.watch(keyValueStoreProvider).readString(StorageKeys.seerahVisited);
    if (raw == null || raw.isEmpty) {
      return const <String>{};
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List) {
        return Set<String>.unmodifiable(decoded.whereType<String>());
      }
    } on FormatException {
      return const <String>{};
    }
    return const <String>{};
  }

  /// يسجل أن المستخدم بلغ مشهد القرار في محطة.
  void markVisited(String stationId) {
    if (state.contains(stationId)) {
      return;
    }
    final Set<String> next = Set<String>.unmodifiable(<String>{...state, stationId});
    state = next;
    unawaited(
      ref
          .read(keyValueStoreProvider)
          .writeString(StorageKeys.seerahVisited, jsonEncode(next.toList()..sort())),
    );
  }
}

/// المحطات التي اكتملت مشاهدها الثلاثة.
final NotifierProvider<SeerahVisitedController, Set<String>> seerahVisitedProvider =
    NotifierProvider<SeerahVisitedController, Set<String>>(SeerahVisitedController.new);
