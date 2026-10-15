// شاشة المحطة الموحدة بطبقتين في تدفق عمودي واحد.
//
// أعلاها شريط البوصلة [العهد • السنة • عمر النبي ﷺ • الموقع] ثم الطور، وبطاقة «ما سبق»
// (previous_link) تربط المحطة بسابقتها.
//
// الطبقة الأولى «المعايشة والموقف» (تُعرض حين كُتبت للمحطة):
//   التمهيد المشوق ← المشهد الموجز (أربعة أسطر يُفتح كاملاً بزر) ← مأزق الشورى والتحدي
//   وسؤال الشورى وخياراته إن نصّ عليها الشاهد (فإن لم ينص فزر كشف واحد) ← القرار النبوي
//   بعد الاختيار أو الكشف ← «في المحطة التالية» (next_hook).
//
// الطبقة الثانية «الرواية التاريخية المطولة»: فصول قرائية بمقاطع حرفية موثقة تحت كل مقطع
// شارة مصدره وصفحته، وشريط حجم الخط. تُطوى حين تسبقها طبقة المعايشة، وتُفتح من البدء في
// المحطة التي لم تُكتب طبقتها الأولى بعد (المولّدة من نص الكتاب).
//
// كشف القرار يعدّ المحطة مفتوحة (تظهر علامتها على الخريطة)، وبعده يظهر زر الانتقال إلى
// المحطة التالية؛ والمحطة بلا طبقة معايشة يظهر زر الانتقال فيها من البدء ويعدّها مفتوحة
// بالانتقال. لا تقييم للاختيار: لا صواب ولا خطأ ولا لون عقاب.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/content/models/source_catalog.dart';
import '../../../core/content/source_catalog_provider.dart';
import '../../../core/content/widgets/source_quote_tile.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/ui/reading_size_bar.dart';
import '../../../core/ui/smooth_surface.dart';
import '../application/seerah_providers.dart';
import '../data/models/seerah_station.dart';
import '../domain/seerah_checkpoint.dart';
import 'seerah_checkpoint_screen.dart';
import 'widgets/seerah_compass_bar.dart';
import 'widgets/seerah_experience_cards.dart';
import 'widgets/seerah_labels.dart';
import 'widgets/seerah_reading_section.dart';

/// شاشة المحطة.
class SeerahStationScreen extends ConsumerStatefulWidget {
  const SeerahStationScreen({super.key, required this.stationId});

  /// المحطة.
  final String stationId;

  @override
  ConsumerState<SeerahStationScreen> createState() => _SeerahStationScreenState();
}

class _SeerahStationScreenState extends ConsumerState<SeerahStationScreen> {
  final GlobalKey _decisionAnchor = GlobalKey();
  final ScrollController _scroll = ScrollController();

  /// الخيار الذي اختاره المستخدم؛ null إن كشف القرار بلا خيارات.
  int? _chosen;
  bool _revealed = false;

  /// فتح الطبقة الثانية؛ null يعني الافتراضي (مفتوحة إن لم تكن للمحطة طبقة معايشة).
  bool? _readingOpen;
  bool _evidenceOpen = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// يكشف القرار النبوي، ويعدّ المحطة مفتوحة، ويُظهر القرار على الشاشة.
  void _reveal({int? choice}) {
    if (_revealed) {
      return;
    }
    setState(() {
      _chosen = choice;
      _revealed = true;
    });
    ref.read(seerahVisitedProvider.notifier).markVisited(widget.stationId);
    _scrollToDecision(0);
  }

  /// القائمة كسولة: إن لم تُبنَ بطاقة القرار بعد، تُقدَّم القائمة قليلاً ثم يُعاد المحاولة.
  void _scrollToDecision(int attempt) {
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) {
        return;
      }
      final BuildContext? target = _decisionAnchor.currentContext;
      final Duration duration =
          MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 420);
      if (target != null) {
        unawaited(Scrollable.ensureVisible(target, alignment: 0.04, duration: duration, curve: Curves.easeOutCubic));
        return;
      }
      if (attempt >= 6 || !_scroll.hasClients) {
        return;
      }
      final ScrollPosition position = _scroll.position;
      _scroll.jumpTo(math.min(position.maxScrollExtent, position.pixels + position.viewportDimension * 0.6));
      _scrollToDecision(attempt + 1);
    });
  }

  /// ينتقل إلى المحطة التالية، وتتوسط الطريق واحة استذكار كل خمس محطات.
  Future<void> _continueTo(
    SeerahStationModel next,
    List<SeerahStationModel> ordered,
    int currentIndex,
  ) async {
    ref.read(seerahVisitedProvider.notifier).markVisited(widget.stationId);
    final SeerahCheckpoint? checkpoint = SeerahCheckpoint.after(ordered, currentIndex);
    if (checkpoint != null) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (BuildContext routeContext) => SeerahCheckpointScreen(checkpoint: checkpoint),
        ),
      );
      if (!mounted) {
        return;
      }
    }
    _openStation(next);
  }

  void _openStation(SeerahStationModel station) {
    ref.read(selectedSeerahStationProvider.notifier).select(station.id);
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (BuildContext routeContext) => SeerahStationScreen(stationId: station.id),
      ),
    );
  }

  void _finish() {
    ref.read(seerahVisitedProvider.notifier).markVisited(widget.stationId);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final SeerahDataset? dataset = ref.watch(seerahDatasetProvider).value;
    final SourceCatalog? sources = ref.watch(sourceCatalogProvider).value;
    final SeerahStationModel? station = dataset?.stationById(widget.stationId);
    if (dataset == null || station == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final List<SeerahStationModel> ordered = dataset.chronological;
    final int index = ordered.indexWhere((SeerahStationModel s) => s.id == station.id);
    final SeerahStationModel? next = index >= 0 && index + 1 < ordered.length ? ordered[index + 1] : null;
    final SeerahEpochInfo? epoch = dataset.epochOf(station);

    final String? scene = station.sceneDescription;
    final String? challenge = station.challenge;
    final String? decision = station.propheticDecision;
    final bool experience = scene != null && challenge != null && decision != null;
    final bool readingOpen = _readingOpen ?? !experience;
    final bool canContinue = _revealed || !experience;
    final String? previousLink = station.previousLink;
    final String? nextHook = station.nextHook;

    final List<Widget> items = <Widget>[];
    void add(Widget widget, {double gap = 14}) {
      items
        ..add(widget)
        ..add(SizedBox(height: gap));
    }

    add(SeerahCompassBar(station: station, sources: sources), gap: 8);
    if (epoch != null) {
      add(
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 6, 0),
          child: Text(
            epochCaption(epoch),
            key: const ValueKey<String>('station-epoch'),
            style: text.labelMedium?.copyWith(color: palette.amberText, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
    if (previousLink != null) {
      add(
        KeyedSubtree(
          key: const ValueKey<String>('station-previous-link'),
          child: SeerahBridgeCard(icon: Icons.history_rounded, label: 'ما سبق', text: previousLink),
        ),
      );
    }

    if (scene != null && challenge != null && decision != null) {
      add(const SectionEyebrow('المعايشة والموقف', icon: Icons.explore_outlined), gap: 10);
      final String? hook = station.hook;
      if (hook != null) {
        add(SeerahHookCard(text: hook));
      }
      add(SeerahBriefScene(text: scene));
      add(
        SeerahDilemmaCard(
          challenge: challenge,
          shuraQuestion: station.shuraQuestion,
          options: station.dilemmaOptions ?? const <String>[],
          chosen: _chosen,
          revealed: _revealed,
          onChoose: (int option) => _reveal(choice: option),
          onReveal: _reveal,
        ),
      );
      if (_revealed) {
        add(
          SeerahDecisionCard(
            key: _decisionAnchor,
            decision: decision,
            evidence: station.evidenceFor(SeerahScene.decision),
            sources: sources,
          ),
        );
        if (nextHook != null) {
          add(
            KeyedSubtree(
              key: const ValueKey<String>('station-next-hook'),
              child: SeerahBridgeCard(icon: Icons.near_me_rounded, label: 'في المحطة التالية', text: nextHook),
            ),
          );
        }
      }
    }

    add(
      SeerahReadingHeader(
        station: station,
        open: readingOpen,
        onToggle: () => setState(() => _readingOpen = !readingOpen),
      ),
      gap: readingOpen ? 12 : 14,
    );
    if (readingOpen) {
      add(const ReadingSizeBar(), gap: 18);
      for (int c = 0; c < station.chapters.length; c++) {
        final SeerahChapter chapter = station.chapters[c];
        add(
          SeerahChapterHeading(
            key: ValueKey<String>('chapter-${chapter.id}'),
            chapter: chapter,
            number: c + 1,
            total: station.chapters.length,
          ),
          gap: 10,
        );
        for (int p = 0; p < chapter.passages.length; p++) {
          add(
            SeerahPassageView(
              id: '${chapter.id}-$p',
              passage: chapter.passages[p],
              sources: sources,
            ),
            gap: p == chapter.passages.length - 1 ? 26 : 14,
          );
        }
      }
    }

    if (!experience && nextHook != null) {
      add(
        KeyedSubtree(
          key: const ValueKey<String>('station-next-hook'),
          child: SeerahBridgeCard(icon: Icons.near_me_rounded, label: 'في المحطة التالية', text: nextHook),
        ),
      );
    }

    if (experience) {
      add(
        SeerahEvidenceHeader(
          open: _evidenceOpen,
          onToggle: () => setState(() => _evidenceOpen = !_evidenceOpen),
        ),
        gap: _evidenceOpen ? 12 : 14,
      );
      if (_evidenceOpen) {
        for (final SeerahScene each in SeerahScene.values) {
          add(
            SeerahSceneEvidenceBlock(
              scene: each,
              evidence: station.evidenceFor(each),
              builder: (SeerahEvidence item) =>
                  SourceQuoteTile(reference: item.source, source: sources?.byId(item.source.sourceId)),
            ),
            gap: 18,
          );
        }
      }
    }

    items.add(
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 6, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'المقاطع منقولة بنصها من الكتب المثبتة، وعناوين الفصول والتمهيد وسؤال الشورى '
              'والربط بين المحطات صياغة تحريرية مقتصرة على شواهد المحطة.',
              style: text.labelSmall?.copyWith(color: palette.inkSoft, height: 1.7),
            ),
            for (final String note in station.review.notes.skip(experience ? 1 : 0))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '• $note',
                  style: text.labelSmall?.copyWith(color: palette.inkSoft, height: 1.7),
                ),
              ),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          station.title,
          style: AppTypography.heritageTitle(color: palette.ink, fontSize: 22),
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              key: const ValueKey<String>('station-scroll'),
              controller: _scroll,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: items,
            ),
          ),
          if (canContinue)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey<String>('station-continue'),
                    onPressed: next == null ? _finish : () => unawaited(_continueTo(next, ordered, index)),
                    icon: Icon(next == null ? Icons.map_rounded : Icons.arrow_forward_rounded),
                    label: Text(
                      next == null
                          ? 'العودة إلى الخريطة'
                          : (SeerahCheckpoint.isDueAfter(index, ordered.length)
                              ? 'واحة الاستذكار ثم المتابعة'
                              : 'المحطة التالية: ${next.title}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
