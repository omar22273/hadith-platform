// فاحص سلامة الوِرد: يتحقق من اتساق الحديث مع نفسه ومع الفهارس قبل عرضه.
//
// يكشف المراسي المكسورة بعد أي تعديل في المتن، والمعرّفات المفقودة في
// فهارس الرواة والمصادر والمحطات، ويُستعمل في الاختبارات وفي وضع التطوير.
//
// Hadith Platform — data model v1.1.0.

import 'package:flutter/foundation.dart';

import 'audio_sync.dart';
import 'hadith_daily_model.dart';
import 'journey_catalog.dart';
import 'matn.dart';
import 'matn_tokenizer.dart';
import 'narrator_profile.dart';
import 'practice.dart';
import 'provenance.dart';
import 'reflection.dart';
import 'scholar_layer.dart';
import 'source_catalog.dart';
import 'source_ref.dart';
import 'takhrij.dart';

/// مشكلة واحدة في سلامة البيانات.
@immutable
class IntegrityIssue {
  const IntegrityIssue({required this.path, required this.message});

  /// موضع المشكلة داخل ملف JSON.
  final String path;

  /// وصف المشكلة.
  final String message;

  @override
  String toString() => '$path: $message';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is IntegrityIssue &&
        path == other.path &&
        message == other.message;
  }

  @override
  int get hashCode => Object.hash(path, message);
}

/// يفحص الوِرد اليومي، ويقارن المعرّفات بالفهارس إن مُرّرت.
class HadithIntegrityChecker {
  const HadithIntegrityChecker({
    this.narrators,
    this.journey,
    this.sources,
  });

  /// فهرس الرواة.
  final NarratorCatalog? narrators;

  /// فهرس مسار القوافل.
  final JourneyCatalog? journey;

  /// فهرس المصادر.
  final SourceCatalog? sources;

  /// يعيد قائمة المشكلات؛ القائمة الفارغة تعني أن الوِرد سليم.
  List<IntegrityIssue> check(HadithDailyModel hadith) {
    final List<IntegrityIssue> issues = <IntegrityIssue>[];

    void report(String path, String message) {
      issues.add(IntegrityIssue(path: path, message: message));
    }

    void checkSource(String sourceId, String path) {
      final SourceCatalog? catalog = sources;
      if (catalog != null && catalog.byId(sourceId) == null) {
        report(path, 'Unknown sourceId "$sourceId".');
      }
    }

    void checkSourceRef(SourceRef reference, String path) {
      checkSource(reference.sourceId, '$path.sourceId');
    }

    void checkNarrator(String narratorId, String path) {
      final NarratorCatalog? catalog = narrators;
      if (catalog != null && catalog.byId(narratorId) == null) {
        report(path, 'Unknown narratorId "$narratorId".');
      }
    }

    void checkStation(String stationId, String path) {
      final JourneyCatalog? catalog = journey;
      if (catalog != null && catalog.stationById(stationId) == null) {
        report(path, 'Unknown stationId "$stationId".');
      }
    }

    // ------------------------------------------------------------ segments
    final Map<String, List<MatnToken>> tokensBySegment =
        <String, List<MatnToken>>{};
    for (int index = 0; index < hadith.matn.segments.length; index++) {
      final MatnSegment segment = hadith.matn.segments[index];
      final String path = 'matn.segments[$index]';
      if (tokensBySegment.containsKey(segment.id)) {
        report(path, 'Duplicate segment id "${segment.id}".');
      }
      final List<MatnToken> tokens = segment.tokens;
      if (tokens.isEmpty) {
        report(path, 'Segment "${segment.id}" has no words.');
      }
      tokensBySegment[segment.id] = tokens;
    }

    List<MatnToken>? tokensOf(String segmentId, String path) {
      final List<MatnToken>? tokens = tokensBySegment[segmentId];
      if (tokens == null) {
        report(path, 'Unknown segmentId "$segmentId".');
      }
      return tokens;
    }

    void checkAnchor(TokenAnchor anchor, String path) {
      final List<MatnToken>? tokens =
          tokensOf(anchor.segmentId, '$path.segmentId');
      if (tokens == null) {
        return;
      }
      if (anchor.tokenIndex + anchor.length > tokens.length) {
        report(path, 'Anchor runs past the end of "${anchor.segmentId}".');
        return;
      }
      final String surface = MatnTokenizer.surfaceOf(
        tokens,
        anchor.tokenIndex,
        anchor.length,
      );
      if (surface != anchor.surface) {
        report(
          path,
          'Anchor surface "${anchor.surface}" does not match "$surface".',
        );
      }
    }

    // ------------------------------------------------------------ journey
    checkStation(hadith.journey.stationId, 'journey.stationId');
    final String? placeStation = hadith.context.place?.stationId;
    if (placeStation != null) {
      checkStation(placeStation, 'context.place.stationId');
    }

    // ------------------------------------------------------------ context
    for (int index = 0; index < hadith.context.sources.length; index++) {
      checkSourceRef(hadith.context.sources[index], 'context.sources[$index]');
    }
    for (int index = 0; index < hadith.context.cautions.length; index++) {
      final List<SourceRef> refs = hadith.context.cautions[index].sources;
      for (int refIndex = 0; refIndex < refs.length; refIndex++) {
        checkSourceRef(
          refs[refIndex],
          'context.cautions[$index].sources[$refIndex]',
        );
      }
    }

    // ------------------------------------------------------------ gharib
    final Set<String> gharibIds = <String>{};
    for (int index = 0; index < hadith.matn.gharib.length; index++) {
      final GharibEntry entry = hadith.matn.gharib[index];
      final String path = 'matn.gharib[$index]';
      if (!gharibIds.add(entry.id)) {
        report(path, 'Duplicate gharib id "${entry.id}".');
      }
      checkAnchor(entry.anchor, '$path.anchor');
      for (int refIndex = 0; refIndex < entry.sources.length; refIndex++) {
        checkSourceRef(entry.sources[refIndex], '$path.sources[$refIndex]');
      }
    }

    // ------------------------------------------------------------ audio
    final AudioSync audio = hadith.matn.audio;
    if (audio.status == AudioStatus.aligned && audio.timings.isEmpty) {
      report('matn.audio', 'Aligned audio must provide word timings.');
    }
    if (audio.status != AudioStatus.notRecorded && audio.assetPath == null) {
      report('matn.audio.assetPath', 'Recorded audio needs an asset path.');
    }
    for (int index = 0; index < audio.timings.length; index++) {
      final WordTiming timing = audio.timings[index];
      final String path = 'matn.audio.timings[$index]';
      final List<MatnToken>? tokens =
          tokensOf(timing.segmentId, '$path.segmentId');
      if (tokens != null && timing.tokenIndex >= tokens.length) {
        report(path, 'Token index ${timing.tokenIndex} is out of range.');
      }
      if (timing.startMs >= timing.endMs) {
        report(path, 'startMs must be before endMs.');
      }
    }

    // ------------------------------------------------------------ takhrij
    final Takhrij takhrij = hadith.matn.takhrij;
    for (int index = 0; index < takhrij.references.length; index++) {
      checkSource(
        takhrij.references[index].sourceId,
        'matn.takhrij.references[$index].sourceId',
      );
    }
    final CompilerStatement? statement = takhrij.compilerStatement;
    if (statement != null) {
      checkSource(
        statement.sourceId,
        'matn.takhrij.compilerStatement.sourceId',
      );
    }
    for (int index = 0; index < takhrij.gradings.length; index++) {
      checkSourceRef(
        takhrij.gradings[index].source,
        'matn.takhrij.gradings[$index].source',
      );
    }

    // ------------------------------------------------------------ practice
    final PracticeConfig practice = hadith.practice;
    final Set<String> chunkIds = <String>{};
    for (int index = 0; index < practice.chunks.length; index++) {
      final PracticeChunk chunk = practice.chunks[index];
      final String path = 'practice.chunks[$index]';
      if (!chunkIds.add(chunk.id)) {
        report(path, 'Duplicate chunk id "${chunk.id}".');
      }
      final List<MatnToken>? tokens =
          tokensOf(chunk.segmentId, '$path.segmentId');
      if (tokens != null &&
          (chunk.startToken > chunk.endToken ||
              chunk.endToken >= tokens.length)) {
        report(path, 'Invalid token range ${chunk.startToken}-${chunk.endToken}.');
      }
    }
    for (int index = 0;
        index < practice.reconstruction.chunkIds.length;
        index++) {
      final String chunkId = practice.reconstruction.chunkIds[index];
      if (!chunkIds.contains(chunkId)) {
        report(
          'practice.reconstruction.chunkIds[$index]',
          'Unknown chunk id "$chunkId".',
        );
      }
    }
    final List<VanishingLevel> levels = practice.vanishing.levels;
    for (int index = 1; index < levels.length; index++) {
      if (levels[index].level <= levels[index - 1].level ||
          levels[index].hidePercent <= levels[index - 1].hidePercent) {
        report(
          'practice.vanishing.levels[$index]',
          'Levels and hide percentages must strictly increase.',
        );
      }
    }
    for (int index = 0;
        index < practice.vanishing.priorityAnchors.length;
        index++) {
      checkAnchor(
        practice.vanishing.priorityAnchors[index],
        'practice.vanishing.priorityAnchors[$index]',
      );
    }

    // ------------------------------------------------------------ reflection
    final Scenario scenario = hadith.reflection.scenario;
    final Set<String> optionIds = <String>{};
    int alignedCount = 0;
    for (int index = 0; index < scenario.options.length; index++) {
      final ScenarioOption option = scenario.options[index];
      if (!optionIds.add(option.id)) {
        report(
          'reflection.scenario.options[$index]',
          'Duplicate option id "${option.id}".',
        );
      }
      if (option.alignment == OptionAlignment.aligned) {
        alignedCount++;
      }
    }
    if (alignedCount != 1) {
      report(
        'reflection.scenario.options',
        'Exactly one option must be aligned, found $alignedCount.',
      );
    }
    for (int index = 0; index < scenario.basis.length; index++) {
      checkSourceRef(
        scenario.basis[index],
        'reflection.scenario.basis[$index]',
      );
    }
    for (int index = 0; index < hadith.reflection.impacts.length; index++) {
      final List<SourceRef> refs = hadith.reflection.impacts[index].sources;
      for (int refIndex = 0; refIndex < refs.length; refIndex++) {
        checkSourceRef(
          refs[refIndex],
          'reflection.impacts[$index].sources[$refIndex]',
        );
      }
    }

    // ------------------------------------------------------------ scholar
    final ScholarLayer scholar = hadith.scholar;
    final Set<String> chainIds = <String>{};
    for (int index = 0; index < scholar.chains.length; index++) {
      final SanadChain chain = scholar.chains[index];
      final String path = 'scholar.chains[$index]';
      if (!chainIds.add(chain.id)) {
        report(path, 'Duplicate chain id "${chain.id}".');
      }
      checkSource(chain.source.sourceId, '$path.source.sourceId');
      if (chain.links.isEmpty || chain.links.first.narratorId != 'prophet') {
        report('$path.links[0]', 'A chain must start with the Prophet ﷺ.');
      }
      for (int linkIndex = 0; linkIndex < chain.links.length; linkIndex++) {
        checkNarrator(
          chain.links[linkIndex].narratorId,
          '$path.links[$linkIndex].narratorId',
        );
      }
    }
    for (int index = 0; index < scholar.variants.length; index++) {
      final NarrationVariant variant = scholar.variants[index];
      final String path = 'scholar.variants[$index]';
      checkSource(variant.sourceId, '$path.sourceId');
      checkNarrator(variant.companionNarratorId, '$path.companionNarratorId');
      if (!variant.fullText.contains(variant.matnText)) {
        report(path, 'matnText must be a part of fullText.');
      }
      for (int chainIndex = 0;
          chainIndex < variant.chainIds.length;
          chainIndex++) {
        final String chainId = variant.chainIds[chainIndex];
        if (!chainIds.contains(chainId)) {
          report('$path.chainIds[$chainIndex]', 'Unknown chain id "$chainId".');
        }
      }
    }

    // ------------------------------------------------------------ provenance
    final Provenance provenance = hadith.provenance;
    checkSourceRef(provenance.matnSource, 'provenance.matnSource');
    for (int index = 0; index < provenance.vocalizationEdits.length; index++) {
      final VocalizationEdit edit = provenance.vocalizationEdits[index];
      final String path = 'provenance.vocalizationEdits[$index]';
      final List<MatnToken>? tokens = tokensOf(edit.segmentId, '$path.segmentId');
      if (tokens != null) {
        if (edit.tokenIndex >= tokens.length) {
          report(path, 'Token index ${edit.tokenIndex} is out of range.');
        } else if (tokens[edit.tokenIndex].core != edit.after) {
          report(path, 'The edited word no longer matches the matn.');
        }
      }
      final SourceRef? editSource = edit.source;
      if (edit.method == EditMethod.alignedSource && editSource == null) {
        report(path, 'An aligned-source edit must cite its source.');
      }
      if (editSource != null) {
        checkSourceRef(editSource, '$path.source');
      }
    }

    return List<IntegrityIssue>.unmodifiable(issues);
  }
}
