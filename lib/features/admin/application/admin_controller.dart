// متحكم لوحة الإدخال: دفعتا المسودات (أحاديث ومشاهد سيرة)، ونص JSON المولد
// لكل منهما بعد التحقق منه.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../seerah/data/models/seerah_station.dart';
import '../data/models/hadith_draft.dart';
import '../domain/admin_drafts.dart';

/// حالة اللوحة.
@immutable
class AdminState {
  const AdminState({
    required this.hadithDrafts,
    required this.seerahDrafts,
    required this.hadithJson,
    required this.seerahJson,
  });

  /// بداية فارغة.
  static const AdminState initial = AdminState(
    hadithDrafts: <HadithDraft>[],
    seerahDrafts: <SeerahStationModel>[],
    hadithJson: null,
    seerahJson: null,
  );

  /// مسودات الأحاديث.
  final List<HadithDraft> hadithDrafts;

  /// محطات السيرة.
  final List<SeerahStationModel> seerahDrafts;

  /// آخر JSON مولد للأحاديث.
  final String? hadithJson;

  /// آخر JSON مولد للسيرة.
  final String? seerahJson;

  /// نسخة معدلة.
  AdminState copyWith({
    List<HadithDraft>? hadithDrafts,
    List<SeerahStationModel>? seerahDrafts,
    String? hadithJson,
    bool clearHadithJson = false,
    String? seerahJson,
    bool clearSeerahJson = false,
  }) {
    return AdminState(
      hadithDrafts: hadithDrafts ?? this.hadithDrafts,
      seerahDrafts: seerahDrafts ?? this.seerahDrafts,
      hadithJson: clearHadithJson ? null : (hadithJson ?? this.hadithJson),
      seerahJson: clearSeerahJson ? null : (seerahJson ?? this.seerahJson),
    );
  }
}

/// المتحكم.
class AdminController extends Notifier<AdminState> {
  @override
  AdminState build() => AdminState.initial;

  /// يضيف مسودة حديث، ويستبدل مسودة بالرقم نفسه إن وُجدت.
  void addHadith(HadithDraft draft) {
    final List<HadithDraft> next = <HadithDraft>[
      for (final HadithDraft existing in state.hadithDrafts)
        if (existing.number != draft.number) existing,
      draft,
    ]..sort((HadithDraft a, HadithDraft b) => a.number.compareTo(b.number));
    state = state.copyWith(hadithDrafts: List<HadithDraft>.unmodifiable(next), clearHadithJson: true);
  }

  /// يحذف مسودة حديث.
  void removeHadith(int number) {
    state = state.copyWith(
      hadithDrafts: List<HadithDraft>.unmodifiable(
        state.hadithDrafts.where((HadithDraft draft) => draft.number != number),
      ),
      clearHadithJson: true,
    );
  }

  /// يضيف محطة سيرة، ويستبدل محطة بالمعرّف نفسه إن وُجدت.
  void addSeerah(SeerahStationModel station) {
    final List<SeerahStationModel> next = <SeerahStationModel>[
      for (final SeerahStationModel existing in state.seerahDrafts)
        if (existing.id != station.id) existing,
      station,
    ];
    state = state.copyWith(seerahDrafts: List<SeerahStationModel>.unmodifiable(next), clearSeerahJson: true);
  }

  /// يحذف محطة سيرة.
  void removeSeerah(String id) {
    state = state.copyWith(
      seerahDrafts: List<SeerahStationModel>.unmodifiable(
        state.seerahDrafts.where((SeerahStationModel station) => station.id != id),
      ),
      clearSeerahJson: true,
    );
  }

  /// يولد JSON الأحاديث ويتحقق منه؛ يعيد null إن لم يجتز التحقق.
  String? exportHadiths() {
    final String json = encodeJsonArray(<Map<String, dynamic>>[
      for (final HadithDraft draft in state.hadithDrafts) draft.toJson(),
    ]);
    if (!verifyHadithDraftArray(json)) {
      return null;
    }
    state = state.copyWith(hadithJson: json);
    return json;
  }

  /// يولد JSON محطات السيرة ويتحقق منه.
  String? exportSeerah() {
    final String json = encodeJsonArray(<Map<String, dynamic>>[
      for (final SeerahStationModel station in state.seerahDrafts) station.toJson(),
    ]);
    if (!verifySeerahStationArray(json)) {
      return null;
    }
    state = state.copyWith(seerahJson: json);
    return json;
  }
}

/// اللوحة.
final NotifierProvider<AdminController, AdminState> adminControllerProvider =
    NotifierProvider<AdminController, AdminState>(AdminController.new);
