// متحكم وِرد فئة من الأذكار: العدّ على الذكر الحالي بلمسة، والقفل النهائي عند
// بلوغ العدد المسنون فلا زيادة عليه، ثم الانتقال التلقائي إلى أول ذكر لم يكتمل.
// لكل نطاق متحكمه (family بمفتاح النطاق: معرّف الفئة، أو «الفئة#المسار» للفئات ذات
// التبديل)، فلكل من الصباح والمساء وِرده وعدّاده؛ وحالته في الذاكرة تبقى ما دام
// التطبيق مفتوحاً وتبدأ وِرداً جديداً عند فتحه.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../data/models/adhkar.dart';
import 'adhkar_providers.dart';

/// نتيجة لمسة على بطاقة الذكر.
enum DhikrTapResult {
  /// احتُسبت ضغطة ولم يبلغ العدد بعد.
  counted,

  /// احتُسبت الضغطة الأخيرة وبلغ العدد المسنون فقُفل الذكر.
  completed,

  /// الذكر مقفل ببلوغ العدد؛ لم يُحتسب شيء.
  locked,

  /// لا ذكر حالياً (الملف لم يُحمَّل بعد).
  unavailable,
}

/// حالة الوِرد.
@immutable
class AdhkarWirdState {
  const AdhkarWirdState({
    required this.index,
    required this.counts,
    required this.completionTick,
  });

  /// البداية.
  static const AdhkarWirdState empty = AdhkarWirdState(
    index: 0,
    counts: <int>[],
    completionTick: 0,
  );

  /// رقم الذكر الحالي.
  final int index;

  /// ما عُدَّ من كل ذكر، بترتيب الأذكار.
  final List<int> counts;

  /// عداد يزيد مع كل ذكر يبلغ عدده، لتحريك الاحتفال مرة لكل إتمام.
  final int completionTick;

  /// ما عُدَّ من ذكر، أو صفر إن لم يوجد.
  int countOf(int itemIndex) {
    return itemIndex >= 0 && itemIndex < counts.length ? counts[itemIndex] : 0;
  }

  /// هل بلغ الذكر عدده المسنون.
  bool isDone(List<DhikrItem> items, int itemIndex) {
    return itemIndex >= 0 && itemIndex < items.length && countOf(itemIndex) >= items[itemIndex].count;
  }

  /// عدد الأذكار التي بلغت عددها.
  int doneCount(List<DhikrItem> items) {
    int done = 0;
    for (int i = 0; i < items.length; i++) {
      if (isDone(items, i)) {
        done++;
      }
    }
    return done;
  }

  /// هل أتمّ المستخدم الوِرد كله.
  bool isComplete(List<DhikrItem> items) => items.isNotEmpty && doneCount(items) == items.length;

  /// نسخة معدلة.
  AdhkarWirdState copyWith({int? index, List<int>? counts, int? completionTick}) {
    return AdhkarWirdState(
      index: index ?? this.index,
      counts: counts ?? this.counts,
      completionTick: completionTick ?? this.completionTick,
    );
  }
}

/// المتحكم.
class AdhkarWirdController extends Notifier<AdhkarWirdState> {
  AdhkarWirdController(this.scope);

  /// مفتاح النطاق الذي يعدّ عليه هذا المتحكم.
  final String scope;

  Timer? _advanceTimer;

  @override
  AdhkarWirdState build() {
    ref.onDispose(() => _advanceTimer?.cancel());
    final List<DhikrItem> items = ref.watch(adhkarItemsProvider(scope));
    return AdhkarWirdState(
      index: 0,
      counts: List<int>.unmodifiable(List<int>.filled(items.length, 0)),
      completionTick: 0,
    );
  }

  List<DhikrItem> get _items => ref.read(adhkarItemsProvider(scope));

  /// لمسة على بطاقة الذكر الحالي: ضغطة واحدة. بلوغ العدد المسنون يقفل الذكر
  /// نهائياً، وكل لمسة بعده مرفوضة هنا، لا في الواجهة وحدها.
  DhikrTapResult tap() {
    final List<DhikrItem> items = _items;
    final int i = state.index;
    if (items.isEmpty || i < 0 || i >= items.length || state.counts.length != items.length) {
      return DhikrTapResult.unavailable;
    }
    final int target = items[i].count;
    final int current = state.counts[i];
    if (current >= target) {
      return DhikrTapResult.locked;
    }
    final List<int> updated = List<int>.of(state.counts);
    updated[i] = current + 1;
    final bool done = current + 1 >= target;
    state = state.copyWith(
      counts: List<int>.unmodifiable(updated),
      completionTick: done ? state.completionTick + 1 : state.completionTick,
    );
    if (done) {
      _scheduleAdvance(i);
      return DhikrTapResult.completed;
    }
    return DhikrTapResult.counted;
  }

  /// يختار ذكراً ليعدّ عليه. اختيار المستخدم يُلغي أي انتقال تلقائي معلّق.
  void select(int itemIndex) {
    if (itemIndex < 0 || itemIndex >= _items.length || itemIndex == state.index) {
      return;
    }
    _advanceTimer?.cancel();
    state = state.copyWith(index: itemIndex);
  }

  /// يبدأ وِرداً جديداً من أوله.
  void restart() {
    _advanceTimer?.cancel();
    state = AdhkarWirdState(
      index: 0,
      counts: List<int>.unmodifiable(List<int>.filled(_items.length, 0)),
      completionTick: state.completionTick,
    );
  }

  void _scheduleAdvance(int from) {
    _advanceTimer?.cancel();
    _advanceTimer = Timer(ref.read(adhkarAutoAdvanceDelayProvider), () => _advanceFrom(from));
  }

  /// ينتقل من الذكر المكتمل إلى أول ذكر لم يكتمل بعده (ثم قبله)، ويبقى في
  /// مكانه إن اكتمل الوِرد كله فتظهر شارة الإتمام.
  void _advanceFrom(int from) {
    if (!ref.mounted || state.index != from) {
      return;
    }
    final List<DhikrItem> items = _items;
    for (int step = 1; step < items.length; step++) {
      final int candidate = (from + step) % items.length;
      if (!state.isDone(items, candidate)) {
        state = state.copyWith(index: candidate);
        return;
      }
    }
  }
}

/// حالة وِرد نطاق من الأذكار بمفتاحه.
final NotifierProviderFamily<AdhkarWirdController, AdhkarWirdState, String> adhkarWirdProvider =
    NotifierProvider.family<AdhkarWirdController, AdhkarWirdState, String>(AdhkarWirdController.new);
