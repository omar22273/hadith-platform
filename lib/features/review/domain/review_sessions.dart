// حالات جلسات المراجعة الثلاث، صرفة وقابلة للاختبار:
// - البطاقات: طابور يعود فيه ما يحتاج إعادة إلى آخره، بلا عقاب.
// - الترتيب: تُقبل الكلمة في الموضع التالي إن طابقت رسماً وضبطاً، والخطأ
//   يهتز بلطف ويعود.
// - المواقف: اختيار يجوز تغييره لقراءة تغذية الخيارات الأخرى.

import 'package:flutter/foundation.dart';

import '../../hadith/domain/practice_engine.dart';

/// جلسة البطاقات.
@immutable
class FlashcardSession {
  const FlashcardSession({
    required this.queue,
    required this.flipped,
    required this.known,
    required this.repeats,
  });

  /// جلسة جديدة لعدد من البطاقات.
  factory FlashcardSession.start(int count) {
    return FlashcardSession(
      queue: List<int>.unmodifiable(List<int>.generate(count, (int index) => index)),
      flipped: false,
      known: 0,
      repeats: 0,
    );
  }

  /// البطاقات الباقية بترتيبها؛ الأولى هي المعروضة.
  final List<int> queue;

  /// هل قُلبت البطاقة الحالية.
  final bool flipped;

  /// البطاقات التي عرفها المستخدم.
  final int known;

  /// مرات الإعادة.
  final int repeats;

  /// البطاقة الحالية، أو null عند الانتهاء.
  int? get current => queue.isEmpty ? null : queue.first;

  /// هل انتهت الجلسة.
  bool get done => queue.isEmpty;

  /// يقلب البطاقة.
  FlashcardSession flip() {
    return FlashcardSession(queue: queue, flipped: !flipped, known: known, repeats: repeats);
  }

  /// «عرفتُها»: تخرج من الطابور.
  FlashcardSession markKnown() {
    if (queue.isEmpty) {
      return this;
    }
    return FlashcardSession(
      queue: List<int>.unmodifiable(queue.sublist(1)),
      flipped: false,
      known: known + 1,
      repeats: repeats,
    );
  }

  /// «أعدها لاحقاً»: تنتقل إلى آخر الطابور.
  FlashcardSession repeatLater() {
    if (queue.isEmpty) {
      return this;
    }
    return FlashcardSession(
      queue: List<int>.unmodifiable(<int>[...queue.sublist(1), queue.first]),
      flipped: false,
      known: known,
      repeats: repeats + 1,
    );
  }
}

/// نتيجة وضع كلمة.
enum PlacementOutcome {
  /// وُضعت في موضعها.
  placed,

  /// ليست كلمة الموضع التالي؛ تعود بلطف.
  mismatch,

  /// اكتمل المقطع بهذه الكلمة.
  completed,

  /// لا يُقبل الوضع (البلاطة مستعملة أو المقطع مكتمل).
  ignored,
}

/// حالة لوحة الترتيب لمقطع واحد.
@immutable
class OrderBoard {
  const OrderBoard({
    required this.drill,
    required this.placedTiles,
    required this.mistakes,
    required this.lastMismatchTile,
    required this.mismatchTick,
  });

  /// لوحة جديدة.
  factory OrderBoard.start(ChunkDrill drill) {
    return OrderBoard(
      drill: drill,
      placedTiles: const <int>[],
      mistakes: 0,
      lastMismatchTile: null,
      mismatchTick: 0,
    );
  }

  /// المقطع.
  final ChunkDrill drill;

  /// البلاطات الموضوعة بترتيب المواضع.
  final List<int> placedTiles;

  /// المحاولات غير المطابقة (للعرض الهادئ فقط).
  final int mistakes;

  /// آخر بلاطة لم تطابق، لتهتز.
  final int? lastMismatchTile;

  /// عدّاد يتغير مع كل عدم مطابقة لإعادة تشغيل الاهتزاز.
  final int mismatchTick;

  /// الموضع التالي.
  int get nextPosition => placedTiles.length;

  /// هل اكتمل المقطع.
  bool get completed => placedTiles.length == drill.tokens.length;

  /// هل البلاطة مستعملة.
  bool isUsed(int tileId) => placedTiles.contains(tileId);

  /// يحاول وضع بلاطة في الموضع التالي.
  (OrderBoard, PlacementOutcome) place(int tileId) {
    if (completed || isUsed(tileId) || tileId < 0 || tileId >= drill.tiles.length) {
      return (this, PlacementOutcome.ignored);
    }
    if (!drill.fits(tileId, nextPosition)) {
      return (
        OrderBoard(
          drill: drill,
          placedTiles: placedTiles,
          mistakes: mistakes + 1,
          lastMismatchTile: tileId,
          mismatchTick: mismatchTick + 1,
        ),
        PlacementOutcome.mismatch,
      );
    }
    final OrderBoard next = OrderBoard(
      drill: drill,
      placedTiles: List<int>.unmodifiable(<int>[...placedTiles, tileId]),
      mistakes: mistakes,
      lastMismatchTile: null,
      mismatchTick: mismatchTick,
    );
    return (next, next.completed ? PlacementOutcome.completed : PlacementOutcome.placed);
  }

  /// يتراجع عن آخر كلمة.
  OrderBoard undo() {
    if (placedTiles.isEmpty) {
      return this;
    }
    return OrderBoard(
      drill: drill,
      placedTiles: List<int>.unmodifiable(placedTiles.sublist(0, placedTiles.length - 1)),
      mistakes: mistakes,
      lastMismatchTile: null,
      mismatchTick: mismatchTick,
    );
  }
}

/// جلسة المواقف.
@immutable
class ScenarioQuizSession {
  const ScenarioQuizSession({required this.index, required this.choices});

  /// جلسة جديدة.
  static const ScenarioQuizSession initial = ScenarioQuizSession(index: 0, choices: <int, String>{});

  /// الموقف المعروض.
  final int index;

  /// اختيار المستخدم في كل موقف.
  final Map<int, String> choices;

  /// اختيار الموقف الحالي.
  String? get currentChoice => choices[index];

  /// يختار خياراً.
  ScenarioQuizSession choose(String optionId) {
    return ScenarioQuizSession(
      index: index,
      choices: Map<int, String>.unmodifiable(<int, String>{...choices, index: optionId}),
    );
  }

  /// ينتقل إلى موقف.
  ScenarioQuizSession goTo(int target) {
    return ScenarioQuizSession(index: target, choices: choices);
  }
}
