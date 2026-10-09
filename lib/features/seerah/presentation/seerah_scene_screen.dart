// المشاهد الثلاثة لمحطة السيرة: المشهد الزماني، فالمأزق والتحدي، فالقرار
// والنتيجة النبوية. تحت كل مشهد شواهده منقولة بنصها مع إحالاتها؛ فالصياغة
// تختصر ما في الشواهد ولا تزيد عليه.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/content/models/source_catalog.dart';
import '../../../core/content/source_catalog_provider.dart';
import '../../../core/content/widgets/source_quote_tile.dart';
import '../../../core/text/arabic_digits.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/ui/app_shapes.dart';
import '../../../core/ui/smooth_surface.dart';
import '../application/seerah_providers.dart';
import '../data/models/seerah_station.dart';
import '../domain/seerah_checkpoint.dart';
import 'seerah_checkpoint_screen.dart';
import 'widgets/seerah_labels.dart';

/// شاشة المشاهد.
class SeerahSceneScreen extends ConsumerStatefulWidget {
  const SeerahSceneScreen({super.key, required this.stationId});

  /// المحطة.
  final String stationId;

  @override
  ConsumerState<SeerahSceneScreen> createState() => _SeerahSceneScreenState();
}

class _SeerahSceneScreenState extends ConsumerState<SeerahSceneScreen> {
  final PageController _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(page);
    } else {
      unawaited(
        _pages.animateToPage(
          page,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeInOutCubic,
        ),
      );
    }
  }

  void _onPageChanged(int page) {
    setState(() => _page = page);
    if (page == SeerahScene.values.length - 1) {
      ref.read(seerahVisitedProvider.notifier).markVisited(widget.stationId);
    }
  }

  /// ينتقل إلى المحطة التالية، وتتوسط الطريق واحة استذكار كل خمس محطات.
  Future<void> _continueTo(
    SeerahStationModel next,
    List<SeerahStationModel> ordered,
    int currentIndex,
  ) async {
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
        builder: (BuildContext routeContext) => SeerahSceneScreen(stationId: station.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
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
    final bool last = _page == SeerahScene.values.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          station.title,
          style: AppTypography.heritageTitle(color: palette.ink, fontSize: 22),
        ),
      ),
      body: Column(
        children: <Widget>[
          _SceneProgress(current: _page, onTap: _goTo),
          Expanded(
            child: PageView(
              controller: _pages,
              onPageChanged: _onPageChanged,
              children: <Widget>[
                for (final SeerahScene scene in SeerahScene.values)
                  _ScenePage(station: station, scene: scene, sources: sources),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: <Widget>[
                  if (_page > 0)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _goTo(_page - 1),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('المشهد السابق'),
                      ),
                    ),
                  if (_page > 0) const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: last
                          ? (next == null ? () => Navigator.of(context).maybePop() : () => unawaited(_continueTo(next, ordered, index)))
                          : () => _goTo(_page + 1),
                      icon: Icon(last && next == null ? Icons.map_rounded : Icons.arrow_forward_rounded),
                      label: Text(
                        last
                            ? (next == null ? 'العودة إلى الخريطة' : (SeerahCheckpoint.isDueAfter(index, ordered.length) ? 'واحة الاستذكار ثم المتابعة' : 'المحطة التالية: ${next.title}'))
                            : 'المشهد التالي',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneProgress extends StatelessWidget {
  const _SceneProgress({required this.current, required this.onTap});

  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < SeerahScene.values.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                button: true,
                selected: i == current,
                label: '${sceneOrdinal(SeerahScene.values[i])}: ${sceneTitle(SeerahScene.values[i])}',
                child: ExcludeSemantics(
                  child: InkWell(
                    onTap: () => onTap(i),
                    customBorder: AppShapes.rounded(AppShapes.radiusSmall),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            height: 5,
                            decoration: BoxDecoration(
                              color: i <= current ? palette.amber : palette.line,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            sceneTitle(SeerahScene.values[i]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelSmall?.copyWith(
                              color: i == current ? palette.ink : palette.inkSoft,
                              fontWeight: i == current ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScenePage extends StatelessWidget {
  const _ScenePage({required this.station, required this.scene, required this.sources});

  final SeerahStationModel station;
  final SeerahScene scene;
  final SourceCatalog? sources;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final List<SeerahEvidence> evidence = station.evidenceFor(scene);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: <Widget>[
        SmoothSurface(
          gradient: scene == SeerahScene.decision
              ? LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: <Color>[palette.emeraldSoft, palette.surface],
                )
              : null,
          borderColor: scene == SeerahScene.challenge ? palette.amber.withValues(alpha: 0.45) : null,
          elevated: true,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(sceneIcon(scene), color: palette.amberText),
                  const SizedBox(width: 8),
                  Text(
                    sceneOrdinal(scene),
                    style: text.labelLarge?.copyWith(color: palette.amberText, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                sceneTitle(scene),
                style: AppTypography.heritageTitle(color: palette.ink, fontSize: 27),
              ),
              if (scene == SeerahScene.setting) ...<Widget>[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: <Widget>[
                    SoftChip(label: epochLabel(station.epoch), icon: Icons.timeline_rounded),
                    SoftChip(label: station.place.name, icon: Icons.place_rounded),
                    if (station.timeLabel != null) SoftChip(label: station.timeLabel!, icon: Icons.schedule_rounded),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Text(
                sceneText(station, scene),
                style: AppTypography.athar(color: palette.ink, fontSize: 21),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionEyebrow(
          evidence.length == 1
              ? 'الشاهد من المصادر'
              : 'الشواهد من المصادر (${arabicDigits(evidence.length)})',
          icon: Icons.format_quote_rounded,
        ),
        const SizedBox(height: 8),
        for (final SeerahEvidence item in evidence) ...<Widget>[
          SourceQuoteTile(reference: item.source, source: sources?.byId(item.source.sourceId)),
          const SizedBox(height: 8),
        ],
        if (scene == SeerahScene.decision) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            'صياغة المشاهد مقتصرة على الشواهد المنقولة أعلاه، وهي بانتظار المراجعة العلمية قبل الاعتماد.',
            style: text.labelSmall?.copyWith(color: palette.inkSoft, height: 1.7),
          ),
          for (final String note in station.review.notes.skip(1))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '• $note',
                style: text.labelSmall?.copyWith(color: palette.inkSoft, height: 1.7),
              ),
            ),
        ],
      ],
    );
  }
}
