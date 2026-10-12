// اختبارات ترتيب العبارات: تقطيع الأحاديث 1–10 إلى عبارات تامة، وتجميعها في
// تمارين من أربع عبارات فأقل، وأن البلاطة عبارة كاملة من المتن حرفاً بحرف.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/features/hadith/data/models/models.dart';
import 'package:hadith_platform/features/hadith/domain/practice_engine.dart';

HadithDailyModel _hadith(int number) {
  final String path = 'assets/data/hadith/nawawi40/nawawi40_${number.toString().padLeft(3, '0')}.json';
  return HadithDailyModel.fromJson(asJsonMap(jsonDecode(File(path).readAsStringSync()), path));
}

void main() {
  group('phraseGroupSizes', () {
    test('balances the phrases and never exceeds the cap', () {
      expect(phraseGroupSizes(0), isEmpty);
      expect(phraseGroupSizes(1), <int>[1]);
      expect(phraseGroupSizes(4), <int>[4]);
      expect(phraseGroupSizes(5), <int>[3, 2]);
      expect(phraseGroupSizes(6), <int>[3, 3]);
      expect(phraseGroupSizes(7), <int>[4, 3]);
      expect(phraseGroupSizes(10), <int>[4, 3, 3]);
      expect(phraseGroupSizes(12), <int>[4, 4, 4]);
      expect(phraseGroupSizes(14), <int>[4, 4, 3, 3]);
      for (int count = 2; count <= 40; count++) {
        final List<int> sizes = phraseGroupSizes(count);
        expect(sizes.fold<int>(0, (int a, int b) => a + b), count);
        expect(sizes.every((int size) => size >= 2 && size <= maxPhrasesPerDrill), isTrue, reason: '$count');
      }
    });
  });

  for (int number = 1; number <= 10; number++) {
    group('hadith $number', () {
      final HadithDailyModel hadith = _hadith(number);
      final PracticeEngine engine = PracticeEngine.fromHadith(hadith, seed: 20261012);

      test('is cut into whole phrases in reading order without overlap', () {
        final List<PracticeChunk> chunks = hadith.practice.chunks;
        expect(chunks.length, greaterThanOrEqualTo(4));
        expect(hadith.practice.reconstruction.chunkIds, chunks.map((PracticeChunk c) => c.id).toList());
        (String, int)? previousEnd;
        for (final PracticeChunk chunk in chunks) {
          final int segmentIndex = hadith.matn.segments.indexWhere((MatnSegment s) => s.id == chunk.segmentId);
          expect(segmentIndex, greaterThanOrEqualTo(0), reason: chunk.id);
          final MatnSegment segment = hadith.matn.segments[segmentIndex];
          expect(chunk.endToken, lessThan(segment.tokens.length), reason: chunk.id);
          expect(chunk.tokenCount, greaterThanOrEqualTo(2), reason: '${chunk.id} is a phrase, not a single word');
          expect(chunk.label.trim(), isNotEmpty);
          if (previousEnd != null) {
            final int previousSegment = hadith.matn.segments.indexWhere((MatnSegment s) => s.id == previousEnd!.$1);
            final bool after = segmentIndex > previousSegment ||
                (segmentIndex == previousSegment && chunk.startToken > previousEnd.$2);
            expect(after, isTrue, reason: '${chunk.id} overlaps or precedes the previous phrase');
          }
          previousEnd = (chunk.segmentId, chunk.endToken);
        }
      });

      test('every tile is a whole phrase copied verbatim from the matn', () {
        expect(engine.drills, isNotEmpty);
        expect(
          engine.drills.fold<int>(0, (int sum, ChunkDrill d) => sum + d.tokens.length),
          hadith.practice.chunks.length,
        );
        for (final ChunkDrill drill in engine.drills) {
          expect(drill.tokens.length, inInclusiveRange(2, maxPhrasesPerDrill));
          expect(drill.tiles.length, drill.tokens.length);
          for (int i = 0; i < drill.chunks.length; i++) {
            final PracticeChunk chunk = drill.chunks[i];
            final List<MatnToken> words = hadith.matn.segmentById(chunk.segmentId)!.tokens.sublist(chunk.startToken, chunk.endToken + 1);
            expect(drill.tokens[i].core, words.map((MatnToken w) => w.core).join(' '));
            expect(drill.tokens[i].raw, words.map((MatnToken w) => w.raw).join(' '));
          }
        }
      });

      test('solving by phrases completes every drill, and a wrong phrase never fits', () {
        for (final ChunkDrill drill in engine.drills) {
          final List<int> placed = <int>[];
          for (int position = 0; position < drill.tokens.length; position++) {
            final int? tile = drill.nextTileAfter(placed);
            expect(tile, isNotNull);
            for (final PracticeTile other in drill.tiles) {
              if (!placed.contains(other.id) && other.token.core != drill.tokens[position].core) {
                expect(drill.fits(other.id, position), isFalse);
              }
            }
            placed.add(tile!);
          }
          expect(drill.nextTileAfter(placed), isNull);
        }
      });
    });
  }
}
