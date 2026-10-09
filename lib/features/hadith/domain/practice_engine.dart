// محرك التثبيت الحركي (حساب صرف):
// - ترصيع المتن: بعثرة كلمات كل مقطع حفظ ببذرة ثابتة للمستخدم في اليوم.
// - التلاشي التدريجي: ترتيب إخفاء ثابت يبدأ بالكلمات المفتاحية، فما يُخفى
//   عند ٢٥٪ يبقى مخفياً عند ٥٠٪ و٨٠٪.
// الكلمات تُقرأ من المتن الموثق بعقد التقسيم المشترك؛ لا تُنشأ كلمة جديدة.

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/text/stable_hash.dart';
import '../data/models/models.dart';

/// بلاطة في تمرين الترصيع.
@immutable
class PracticeTile {
  const PracticeTile({required this.id, required this.tokenIndex, required this.token});

  /// موضع البلاطة في المصفوفة المبعثرة.
  final int id;

  /// رقم الكلمة داخل مقطع الحفظ.
  final int tokenIndex;

  /// الكلمة.
  final MatnToken token;
}

/// تمرين ترصيع مقطع واحد.
@immutable
class ChunkDrill {
  const ChunkDrill({required this.chunk, required this.tokens, required this.tiles});

  /// مقطع الحفظ.
  final PracticeChunk chunk;

  /// كلمات المقطع بالترتيب الصحيح.
  final List<MatnToken> tokens;

  /// البلاطات مبعثرة.
  final List<PracticeTile> tiles;

  /// هل البلاطة صحيحة للموضع التالي. الكلمتان المتطابقتان رسماً وضبطاً متكافئتان.
  bool fits(int tileId, int position) {
    if (position < 0 || position >= tokens.length || tileId < 0 || tileId >= tiles.length) {
      return false;
    }
    return tiles[tileId].token.core == tokens[position].core;
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
    final List<ChunkDrill> drills = <ChunkDrill>[];
    for (final PracticeChunk chunk in drillChunks.isEmpty ? practice.chunks : drillChunks) {
      final List<MatnToken> tokens = tokensOf(chunk);
      if (tokens.isEmpty) {
        continue;
      }
      final List<int> order = List<int>.generate(tokens.length, (int i) => i);
      final int chunkSeed = practice.reconstruction.shuffleStrategy == ShuffleStrategy.fixed
          ? stableHash(chunk.id)
          : seed ^ stableHash(chunk.id);
      order.shuffle(Random(chunkSeed));
      if (order.length > 1 && _isIdentity(order)) {
        order.add(order.removeAt(0));
      }
      drills.add(
        ChunkDrill(
          chunk: chunk,
          tokens: List<MatnToken>.unmodifiable(tokens),
          tiles: List<PracticeTile>.unmodifiable(<PracticeTile>[
            for (int id = 0; id < order.length; id++)
              PracticeTile(id: id, tokenIndex: order[id], token: tokens[order[id]]),
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

  /// تمارين الترصيع بالترتيب.
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

  static bool _isIdentity(List<int> order) {
    for (int i = 0; i < order.length; i++) {
      if (order[i] != i) {
        return false;
      }
    }
    return true;
  }
}
