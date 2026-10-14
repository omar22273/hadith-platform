// متحكم السبحة النبوية الذكية: تسبيح حر بعدّاد هادئ.
//
// يختار المستخدم الذكر (سبحان الله، الحمد لله، الله أكبر، الصلاة على النبي ﷺ،
// الاستغفار) والعدد المستهدف للجولة (٣٣ أو ١٠٠ أو حر بلا حد). كل لمسة تزيد عدّاد
// الجولة والمجموع المحفوظ للذكر؛ وبلوغ العدد المستهدف يُتمّ الجولة، وأول لمسة بعدها
// تبدأ جولة جديدة. المجاميع والاختيار تُحفظ محلياً في الجهاز وتعود عند فتح التطبيق.
//
// أسماء الأذكار هنا عناوين خيارات كما حددها مالك المنتج، وليست نصوص أحاديث؛ ونصوص
// الأذكار المشكولة وشواهدها في ملفات البيانات وحدها.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/key_value_store.dart';

/// الذكر الذي تعدّ عليه السبحة.
enum SebhaDhikr {
  subhanAllah('subhan_allah', 'سبحان الله'),
  alhamdulillah('alhamdulillah', 'الحمد لله'),
  allahuAkbar('allahu_akbar', 'الله أكبر'),
  salawat('salawat', 'الصلاة على النبي ﷺ'),
  istighfar('istighfar', 'الاستغفار');

  const SebhaDhikr(this.id, this.label);

  /// المعرّف في التخزين.
  final String id;

  /// العنوان المعروض.
  final String label;

  /// الذكر بمعرّفه، أو null إن لم يوجد.
  static SebhaDhikr? byId(Object? id) {
    for (final SebhaDhikr dhikr in SebhaDhikr.values) {
      if (dhikr.id == id) {
        return dhikr;
      }
    }
    return null;
  }
}

/// العدد المستهدف للجولة.
enum SebhaTarget {
  thirtyThree(33, '33'),
  hundred(100, '100'),
  free(0, 'حر');

  const SebhaTarget(this.limit, this.label);

  /// الحد؛ صفر يعني عدّاً حراً بلا حد.
  final int limit;

  /// نص الزر.
  final String label;

  /// الهدف بحدّه، أو null إن لم يوجد.
  static SebhaTarget? byLimit(Object? limit) {
    for (final SebhaTarget target in SebhaTarget.values) {
      if (target.limit == limit) {
        return target;
      }
    }
    return null;
  }
}

/// نتيجة لمسة على السبحة.
enum SebhaTapResult {
  /// احتُسبت تسبيحة وبقي من الجولة ما بقي.
  counted,

  /// احتُسبت التسبيحة الأخيرة وأُتمّت الجولة.
  roundCompleted,
}

/// حالة السبحة.
@immutable
class SebhaState {
  const SebhaState({
    required this.dhikr,
    required this.target,
    required this.count,
    required this.totals,
  });

  /// البداية: سبحان الله، ٣٣، من الصفر.
  static const SebhaState initial = SebhaState(
    dhikr: SebhaDhikr.subhanAllah,
    target: SebhaTarget.thirtyThree,
    count: 0,
    totals: <String, int>{},
  );

  /// الذكر المختار.
  final SebhaDhikr dhikr;

  /// العدد المستهدف للجولة.
  final SebhaTarget target;

  /// عدّاد الجولة الحالية.
  final int count;

  /// المجموع المحفوظ لكل ذكر بمعرّفه.
  final Map<String, int> totals;

  /// هل أُتمّت الجولة الحالية (يتوقف العدّاد عند الحد حتى تُلمس السبحة من جديد).
  bool get roundComplete => target.limit > 0 && count >= target.limit;

  /// ما بقي من الجولة، أو null في العدّ الحر.
  int? get remaining => target.limit > 0 ? (target.limit - count).clamp(0, target.limit).toInt() : null;

  /// مجموع الذكر المختار.
  int get dhikrTotal => totals[dhikr.id] ?? 0;

  /// مجموع الأذكار كلها.
  int get grandTotal => totals.values.fold<int>(0, (int sum, int value) => sum + value);

  /// نسخة معدلة.
  SebhaState copyWith({SebhaDhikr? dhikr, SebhaTarget? target, int? count, Map<String, int>? totals}) {
    return SebhaState(
      dhikr: dhikr ?? this.dhikr,
      target: target ?? this.target,
      count: count ?? this.count,
      totals: totals ?? this.totals,
    );
  }

  /// يحوّل الحالة إلى نص JSON للحفظ.
  String encode() {
    return jsonEncode(<String, Object>{
      'v': 1,
      'dhikr': dhikr.id,
      'target': target.limit,
      'count': count,
      'totals': totals,
    });
  }

  /// يقرأ الحالة المحفوظة؛ أي خلل في النص يعيد البداية دون رمي.
  static SebhaState decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return initial;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return initial;
      }
      final SebhaDhikr dhikr = SebhaDhikr.byId(decoded['dhikr']) ?? initial.dhikr;
      final SebhaTarget target = SebhaTarget.byLimit(decoded['target']) ?? initial.target;
      final Object? rawCount = decoded['count'];
      int count = rawCount is int && rawCount > 0 ? rawCount : 0;
      if (target.limit > 0 && count > target.limit) {
        count = target.limit;
      }
      final Map<String, int> totals = <String, int>{};
      final Object? rawTotals = decoded['totals'];
      if (rawTotals is Map<String, dynamic>) {
        for (final MapEntry<String, dynamic> entry in rawTotals.entries) {
          final Object? value = entry.value;
          if (SebhaDhikr.byId(entry.key) != null && value is int && value > 0) {
            totals[entry.key] = value;
          }
        }
      }
      return SebhaState(
        dhikr: dhikr,
        target: target,
        count: count,
        totals: Map<String, int>.unmodifiable(totals),
      );
    } on FormatException {
      return initial;
    }
  }
}

/// المتحكم.
class SebhaController extends Notifier<SebhaState> {
  @override
  SebhaState build() {
    return SebhaState.decode(ref.watch(keyValueStoreProvider).readString(StorageKeys.adhkarSebha));
  }

  /// لمسة على السبحة: تسبيحة واحدة. بعد إتمام الجولة تبدأ اللمسة التالية جولة جديدة.
  SebhaTapResult tap() {
    final int limit = state.target.limit;
    final int base = state.roundComplete ? 0 : state.count;
    final int next = base + 1;
    final Map<String, int> totals = <String, int>{...state.totals};
    totals[state.dhikr.id] = (totals[state.dhikr.id] ?? 0) + 1;
    _commit(state.copyWith(count: next, totals: Map<String, int>.unmodifiable(totals)));
    return limit > 0 && next >= limit ? SebhaTapResult.roundCompleted : SebhaTapResult.counted;
  }

  /// يختار الذكر ويبدأ جولة جديدة؛ المجاميع المحفوظة لا تتغير.
  void selectDhikr(SebhaDhikr dhikr) {
    if (dhikr == state.dhikr) {
      return;
    }
    _commit(state.copyWith(dhikr: dhikr, count: 0));
  }

  /// يختار العدد المستهدف ويبدأ جولة جديدة.
  void selectTarget(SebhaTarget target) {
    if (target == state.target) {
      return;
    }
    _commit(state.copyWith(target: target, count: 0));
  }

  /// يصفّر عدّاد الجولة الحالية دون المساس بالمجاميع المحفوظة.
  void resetRound() {
    if (state.count == 0) {
      return;
    }
    _commit(state.copyWith(count: 0));
  }

  void _commit(SebhaState next) {
    state = next;
    unawaited(ref.read(keyValueStoreProvider).writeString(StorageKeys.adhkarSebha, next.encode()));
  }
}

/// حالة السبحة.
final NotifierProvider<SebhaController, SebhaState> sebhaProvider =
    NotifierProvider<SebhaController, SebhaState>(SebhaController.new);
