// محرك رتّب ألفاظ الحديث (حساب صرف):
// - ترصيع المتن: بعثرة عبارات الحديث التامة (كل مقطع حفظ عبارة) ببذرة ثابتة
//   للمستخدم في اليوم؛ تُجمع العبارات المتجاورة في تمارين من أربع عبارات فأقل.
// - التلاشي التدريجي: ترتيب إخفاء ثابت يبدأ بالكلمات المفتاحية، فما يُخفى
//   عند ٢٥٪ يبقى مخفياً عند ٥٠٪ و٨٠٪.
// الكلمات والعبارات تُقرأ من المتن الموثق بعقد التقسيم المشترك؛ لا يُنشأ نص جديد.

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/text/arabic_digits.dart';
import '../../../core/text/stable_hash.dart';
import '../data/models/models.dart';

/// عدد المحاولات الخاطئة المتتالية في المقطع الواحد الذي يظهر بعده التلميح
/// البصري على الكلمة الصحيحة التالية. التلميح لا يضع الكلمة ولا يفك القفل.
const int hintAfterMistakes = 3;

/// أكثر عدد من العبارات في تمرين ترتيب واحد.
const int maxPhrasesPerDrill = 4;

/// أحجام تمارين الترتيب لعدد من العبارات: متقاربة قدر الإمكان، لا يتجاوز أيٌّ
/// منها [maxPhrasesPerDrill]، ولا يقل عن اثنتين ما دام العدد اثنتين فأكثر.
List<int> phraseGroupSizes(int count, {int maxPerDrill = maxPhrasesPerDrill}) {
  if (count <= 0) {
    return const <int>[];
  }
  final int groups = (count + maxPerDrill - 1) ~/ maxPerDrill;
  final int base = count ~/ groups;
  final int extra = count % groups;
  return List<int>.unmodifiable(<int>[
    for (int group = 0; group < groups; group++) group < extra ? base + 1 : base,
  ]);
}

/// بلاطة في تمرين الترتيب: عبارة كاملة من عبارات المتن.
@immutable
class PracticeTile {
  const PracticeTile({required this.id, required this.tokenIndex, required this.token});

  /// موضع البلاطة في المصفوفة المبعثرة.
  final int id;

  /// موضع العبارة الصحيح داخل التمرين.
  final int tokenIndex;

  /// العبارة: [MatnToken.raw] نصها بعلامات ترقيمها، و[MatnToken.core] كلماتها
  /// المشكولة دون علامات الترقيم بمسافة واحدة بينها.
  final MatnToken token;
}

/// تمرين ترتيب عبارات متجاورة من المتن.
@immutable
class ChunkDrill {
  const ChunkDrill({
    required this.chunks,
    required this.label,
    required this.tokens,
    required this.tiles,
  });

  /// مقاطع الحفظ (العبارات) التي يضمها التمرين بترتيبها الصحيح.
  final List<PracticeChunk> chunks;

  /// عنوان التمرين في الواجهة.
  final String label;

  /// العبارات بالترتيب الصحيح.
  final List<MatnToken> tokens;

  /// البلاطات مبعثرة.
  final List<PracticeTile> tiles;

  /// معرّف ثابت للتمرين: معرّفات عباراته.
  String get id => chunks.map((PracticeChunk chunk) => chunk.id).join('+');

  /// هل البلاطة صحيحة للموضع التالي. العبارتان المتطابقتان رسماً وضبطاً متكافئتان.
  bool fits(int tileId, int position) {
    if (position < 0 || position >= tokens.length || tileId < 0 || tileId >= tiles.length) {
      return false;
    }
    return tiles[tileId].token.core == tokens[position].core;
  }

  /// البلاطة الصحيحة للموضع التالي بعد [placed]، أو null إن اكتمل المقطع.
  int? nextTileAfter(List<int> placed) {
    if (placed.length >= tokens.length) {
      return null;
    }
    for (final PracticeTile tile in tiles) {
      if (!placed.contains(tile.id) && fits(tile.id, placed.length)) {
        return tile.id;
      }
    }
    return null;
  }

  /// بلاطة التلميح: الصحيحة التالية متى بلغت الأخطاء المتتالية الحد، وإلا null.
  int? hintTile(List<int> placed, int consecutiveMistakes) {
    return consecutiveMistakes >= hintAfterMistakes ? nextTileAfter(placed) : null;
  }
}

/// كلمة في تمرين التلاشي.
@immutable
class VanishWord {
  const VanishWord({
    required this.segmentId,
    required this.tokenIndex,
    required this.token,
    required this.hideable,
  });

  /// المقطع.
  final String segmentId;

  /// رقم الكلمة في المقطع.
  final int tokenIndex;

  /// الكلمة.
  final MatnToken token;

  /// هل يجوز إخفاؤها (لا يُخفى رمز الصلاة على النبي ﷺ).
  final bool hideable;
}

/// المحرك.
@immutable
class PracticeEngine {
  const PracticeEngine._({
    required this.drills,
    required this.words,
    required this.hideOrder,
    required this.levels,
  });

  /// يبني المحرك من الحديث وبذرة اليوم.
  factory PracticeEngine.fromHadith(HadithDailyModel hadith, {required int seed}) {
    final Matn matn = hadith.matn;
    final PracticeConfig practice = hadith.practice;

    List<MatnToken> tokensOf(PracticeChunk chunk) {
      final MatnSegment? segment = matn.segmentById(chunk.segmentId);
      if (segment == null) {
        return const <MatnToken>[];
      }
      final List<MatnToken> all = segment.tokens;
      if (chunk.startToken < 0 || chunk.endToken >= all.length || chunk.endToken < chunk.startToken) {
        return const <MatnToken>[];
      }
      return all.sublist(chunk.startToken, chunk.endToken + 1);
    }

    final List<PracticeChunk> drillChunks = <PracticeChunk>[
      for (final String id in practice.reconstruction.chunkIds)
        if (practice.chunkById(id) != null) practice.chunkById(id)!,
    ];
    final List<PracticeChunk> phraseChunks = <PracticeChunk>[
      for (final PracticeChunk chunk in drillChunks.isEmpty ? practice.chunks : drillChunks)
        if (tokensOf(chunk).isNotEmpty) chunk,
    ];
    final List<ChunkDrill> drills = <ChunkDrill>[];
    int cursor = 0;
    for (final int size in phraseGroupSizes(phraseChunks.length)) {
      final List<PracticeChunk> group = phraseChunks.sublist(cursor, cursor + size);
      final List<MatnToken> phrases = <MatnToken>[
        for (int i = 0; i < group.length; i++) _phraseOf(i, tokensOf(group[i])),
      ];
      final String label = size == 1
          ? group.first.label
          : 'العبارات ${arabicDigits(cursor + 1)}–${arabicDigits(cursor + size)}';
      cursor += size;
      final String drillId = group.map((PracticeChunk chunk) => chunk.id).join('+');
      final List<int> order = List<int>.generate(phrases.length, (int i) => i);
      final int drillSeed = practice.reconstruction.shuffleStrategy == ShuffleStrategy.fixed
          ? stableHash(drillId)
          : seed ^ stableHash(drillId);
      order.shuffle(Random(drillSeed));
      if (order.length > 1 && _isIdentity(order)) {
        order.add(order.removeAt(0));
      }
      drills.add(
        ChunkDrill(
          chunks: List<PracticeChunk>.unmodifiable(group),
          label: label,
          tokens: List<MatnToken>.unmodifiable(phrases),
          tiles: List<PracticeTile>.unmodifiable(<PracticeTile>[
            for (int id = 0; id < order.length; id++)
              PracticeTile(id: id, tokenIndex: order[id], token: phrases[order[id]]),
          ]),
        ),
      );
    }

    final List<VanishWord> words = <VanishWord>[];
    for (final PracticeChunk chunk in practice.chunks) {
      final List<MatnToken> tokens = tokensOf(chunk);
      for (int i = 0; i < tokens.length; i++) {
        final MatnToken token = tokens[i];
        words.add(
          VanishWord(
            segmentId: chunk.segmentId,
            tokenIndex: chunk.startToken + i,
            token: token,
            hideable: !token.isHonorific && token.core.isNotEmpty,
          ),
        );
      }
    }

    final List<int> hideOrder = <int>[];
    for (final TokenAnchor anchor in practice.vanishing.priorityAnchors) {
      for (int offset = 0; offset < anchor.length; offset++) {
        for (int w = 0; w < words.length; w++) {
          final VanishWord word = words[w];
          if (word.segmentId == anchor.segmentId &&
              word.tokenIndex == anchor.tokenIndex + offset &&
              word.hideable &&
              !hideOrder.contains(w)) {
            hideOrder.add(w);
          }
        }
      }
    }
    final List<int> rest = <int>[
      for (int w = 0; w < words.length; w++)
        if (words[w].hideable && !hideOrder.contains(w)) w,
    ]..shuffle(Random(seed ^ 0x5EED));
    hideOrder.addAll(rest);

    final List<int> levels = practice.vanishing.levels
        .map((VanishingLevel level) => level.hidePercent)
        .toList()
      ..sort();

    return PracticeEngine._(
      drills: List<ChunkDrill>.unmodifiable(drills),
      words: List<VanishWord>.unmodifiable(words),
      hideOrder: List<int>.unmodifiable(hideOrder),
      levels: List<int>.unmodifiable(levels),
    );
  }

  /// تمارين ترتيب العبارات بالترتيب.
  final List<ChunkDrill> drills;

  /// كلمات التلاشي بالترتيب.
  final List<VanishWord> words;

  /// ترتيب الإخفاء (مواضع في [words]).
  final List<int> hideOrder;

  /// نسب الإخفاء المتصاعدة.
  final List<int> levels;

  /// الكلمات المخفية في المستوى المعطى.
  Set<int> hiddenAt(int levelIndex) {
    if (levels.isEmpty || levelIndex < 0) {
      return const <int>{};
    }
    final int index = levelIndex >= levels.length ? levels.length - 1 : levelIndex;
    final int percent = levels[index];
    final int count = (hideOrder.length * percent / 100).round();
    return hideOrder.take(count).toSet();
  }

  /// العبارة وحدةً واحدة: نصها بعلامات الترقيم، وكلماتها المشكولة بلا علامات.
  static MatnToken _phraseOf(int index, List<MatnToken> words) {
    return MatnToken(
      index: index,
      raw: words.map((MatnToken word) => word.raw).join(' '),
      leading: '',
      core: words.map((MatnToken word) => word.core).join(' '),
      trailing: '',
    );
  }

  static bool _isIdentity(List<int> order) {
    for (int i = 0; i < order.length; i++) {
      if (order[i] != i) {
        return false;
      }
    }
    return true;
  }
}
