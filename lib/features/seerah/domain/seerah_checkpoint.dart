// واحة الاستذكار: بعد كل خمس محطات زمنية يُطلب من المستخدم إعادة ترتيب
// أحداث المحطات الخمس الأخيرة ترتيباً زمنياً قبل أن يتابع. حساب صرف بلا واجهة.
//
// الترتيب الصحيح هو ترتيب المحطات في ملف البيانات (حقل order)، لا شيء يُولَّد
// هنا من خارجه؛ والخلط ثابت النتيجة للمجموعة نفسها.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/text/stable_hash.dart';
import '../data/models/seerah_station.dart';

/// عدد المحطات بين واحة وأخرى.
const int checkpointInterval = 5;

/// واحة استذكار.
@immutable
class SeerahCheckpoint {
  const SeerahCheckpoint._({required this.stations, required this.shuffled});

  /// المحطات الخمس بترتيبها الزمني الصحيح.
  final List<SeerahStationModel> stations;

  /// المحطات بالترتيب المخلوط الذي يبدأ به المستخدم.
  final List<SeerahStationModel> shuffled;

  /// هل تستحق المحطة التي في الموضع [index] (من صفر) واحة بعدها؟ لا واحة بعد
  /// آخر محطة لأنه لا متابعة بعدها.
  static bool isDueAfter(int index, int total) {
    final int ordinal = index + 1;
    return ordinal % checkpointInterval == 0 && ordinal < total;
  }

  /// واحة بعد المحطة التي في الموضع [index]، أو null إن لم تستحق.
  static SeerahCheckpoint? after(List<SeerahStationModel> chronological, int index) {
    if (index < 0 || index >= chronological.length || !isDueAfter(index, chronological.length)) {
      return null;
    }
    final List<SeerahStationModel> group =
        List<SeerahStationModel>.unmodifiable(chronological.sublist(index + 1 - checkpointInterval, index + 1));
    return SeerahCheckpoint._(stations: group, shuffled: _shuffle(group));
  }

  /// واحة بترتيب بداية محدد (للاختبار).
  @visibleForTesting
  factory SeerahCheckpoint.withOrder(List<SeerahStationModel> stations, List<SeerahStationModel> shuffled) {
    return SeerahCheckpoint._(stations: stations, shuffled: shuffled);
  }

  /// صحة كل موضع في [attempt]: true إن كانت المحطة في مكانها الزمني.
  List<bool> evaluate(List<SeerahStationModel> attempt) {
    return <bool>[
      for (int i = 0; i < stations.length; i++) i < attempt.length && attempt[i].id == stations[i].id,
    ];
  }

  /// هل الترتيب صحيح كله؟
  bool isSolved(List<SeerahStationModel> attempt) {
    return attempt.length == stations.length && evaluate(attempt).every((bool ok) => ok);
  }

  static List<SeerahStationModel> _shuffle(List<SeerahStationModel> group) {
    final math.Random random = math.Random(stableHash(group.map((SeerahStationModel s) => s.id).join('|')));
    List<SeerahStationModel> out = List<SeerahStationModel>.of(group);
    for (int attempt = 0; attempt < 8; attempt++) {
      out = List<SeerahStationModel>.of(group)..shuffle(random);
      if (!_sameOrder(out, group)) {
        return List<SeerahStationModel>.unmodifiable(out);
      }
    }
    // احتياط: تدوير واحد يضمن اختلاف الترتيب عن الصحيح.
    return List<SeerahStationModel>.unmodifiable(<SeerahStationModel>[...group.skip(1), group.first]);
  }

  static bool _sameOrder(List<SeerahStationModel> a, List<SeerahStationModel> b) {
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) {
        return false;
      }
    }
    return true;
  }
}
