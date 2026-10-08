// حالة جلسة الوِرد اليومي بمراحلها الأربع.

import 'package:flutter/foundation.dart';

/// مراحل الوِرد.
enum SessionStage {
  /// سياق الورود والحدث التاريخي.
  context('السياق', 'سياق الورود'),

  /// المتن الشريف والبيان اللغوي اللمسي.
  matn('المتن', 'المتن والغريب'),

  /// التثبيت الحركي والحفظ التراكمي.
  practice('التثبيت', 'التثبيت الحركي'),

  /// الإسقاط السلوكي.
  reflection('الإسقاط', 'الإسقاط السلوكي');

  const SessionStage(this.shortLabel, this.title);

  /// العنوان القصير في شريط المراحل.
  final String shortLabel;

  /// العنوان الكامل.
  final String title;
}

/// نوع تمرين التثبيت.
enum PracticeMode {
  /// ترصيع المتن.
  reconstruction,

  /// التلاشي التدريجي.
  vanishing,
}

/// الحالة.
@immutable
class SessionState {
  const SessionState({
    required this.stage,
    required this.visited,
    required this.scholarLayerOpen,
    required this.selectedGharibId,
    required this.practiceMode,
    required this.drillIndex,
    required this.placedTiles,
    required this.mistakeTileId,
    required this.mistakeTick,
    required this.completedDrills,
    required this.vanishingLevel,
    required this.revealed,
    required this.chosenOptionId,
    required this.finished,
  });

  /// بداية الجلسة.
  static const SessionState initial = SessionState(
    stage: SessionStage.context,
    visited: <SessionStage>{SessionStage.context},
    scholarLayerOpen: false,
    selectedGharibId: null,
    practiceMode: PracticeMode.reconstruction,
    drillIndex: 0,
    placedTiles: <int>[],
    mistakeTileId: null,
    mistakeTick: 0,
    completedDrills: <int>{},
    vanishingLevel: 0,
    revealed: <int>{},
    chosenOptionId: null,
    finished: false,
  );

  /// المرحلة الحالية.
  final SessionStage stage;

  /// المراحل التي زارها المستخدم.
  final Set<SessionStage> visited;

  /// هل طبقة طالب العلم مفتوحة.
  final bool scholarLayerOpen;

  /// لفظة الغريب المختارة.
  final String? selectedGharibId;

  /// تمرين التثبيت الحالي.
  final PracticeMode practiceMode;

  /// مقطع الترصيع الحالي.
  final int drillIndex;

  /// البلاطات الموضوعة في الحوض بالترتيب.
  final List<int> placedTiles;

  /// آخر بلاطة لم توافق موضعها (لاهتزاز لطيف بلا توبيخ).
  final int? mistakeTileId;

  /// عداد يتغير مع كل محاولة غير موافقة لإعادة الاهتزاز.
  final int mistakeTick;

  /// المقاطع التي اكتمل ترصيعها.
  final Set<int> completedDrills;

  /// مستوى التلاشي الحالي.
  final int vanishingLevel;

  /// الكلمات المخفية التي استحضرها المستخدم فكشفها.
  final Set<int> revealed;

  /// الخيار المختار في المأزق.
  final String? chosenOptionId;

  /// هل اكتملت الجلسة.
  final bool finished;

  /// نسخة معدلة. أعلام clear تمسح القيم الاختيارية.
  SessionState copyWith({
    SessionStage? stage,
    Set<SessionStage>? visited,
    bool? scholarLayerOpen,
    String? selectedGharibId,
    bool clearGharib = false,
    PracticeMode? practiceMode,
    int? drillIndex,
    List<int>? placedTiles,
    int? mistakeTileId,
    bool clearMistake = false,
    int? mistakeTick,
    Set<int>? completedDrills,
    int? vanishingLevel,
    Set<int>? revealed,
    String? chosenOptionId,
    bool? finished,
  }) {
    return SessionState(
      stage: stage ?? this.stage,
      visited: visited ?? this.visited,
      scholarLayerOpen: scholarLayerOpen ?? this.scholarLayerOpen,
      selectedGharibId: clearGharib ? null : (selectedGharibId ?? this.selectedGharibId),
      practiceMode: practiceMode ?? this.practiceMode,
      drillIndex: drillIndex ?? this.drillIndex,
      placedTiles: placedTiles ?? this.placedTiles,
      mistakeTileId: clearMistake ? null : (mistakeTileId ?? this.mistakeTileId),
      mistakeTick: mistakeTick ?? this.mistakeTick,
      completedDrills: completedDrills ?? this.completedDrills,
      vanishingLevel: vanishingLevel ?? this.vanishingLevel,
      revealed: revealed ?? this.revealed,
      chosenOptionId: chosenOptionId ?? this.chosenOptionId,
      finished: finished ?? this.finished,
    );
  }
}
