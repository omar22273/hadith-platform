// شاشة المحطة: تدفق عمودي واحد بدل ثلاث صفحات متتابعة.
//
// 1. المشهد الموجز: وصف الموقف في أربعة أسطر، يُفتح كاملاً بزر عند الحاجة.
// 2. مأزق الشورى والتحدي: المأزق بنصه، وخياراته إن نصّ عليها الشاهد؛ فإن لم
//    ينص فزر واحد لكشف القرار. لا يُخترع خيار من خارج ملف البيانات.
// 3. القرار النبوي ونتيجته: يظهر بعد اختيار المستخدم (أو كشفه) مع شاهده.
// 4. «الرواية التاريخية وتفاصيل الأحداث»: قسم قابل للطي لمن أراد التوسع.
//
// كشف القرار يعدّ المحطة مفتوحة (تظهر علامتها على الخريطة)، وبعده يظهر زر
// الانتقال إلى المحطة التالية. لا تقييم للاختيار: لا صواب ولا خطأ ولا لون عقاب.

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
import '../../../core/ui/wide_action_button.dart';
import '../application/seerah_providers.dart';
import '../data/models/seerah_station.dart';
import '../domain/seerah_checkpoint.dart';
import 'seerah_checkpoint_screen.dart';
import 'widgets/seerah_labels.dart';
import 'widgets/seerah_narrative_section.dart';

/// عدد أسطر المشهد الموجز قبل فتحه كاملاً.
const int _briefLines = 4;

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

  /// الخيار الذي اختاره المستخدم؛ null إن كشف القرار بلا خيارات.
  int? _chosen;
  bool _revealed = false;

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
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      final BuildContext? target = _decisionAnchor.currentContext;
      if (!mounted || target == null) {
        return;
      }
      unawaited(
        Scrollable.ensureVisible(
          target,
          alignment: 0.04,
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        ),
      );
    });
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
        builder: (BuildContext routeContext) => SeerahStationScreen(stationId: station.id),
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
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: <Widget>[
                _BriefScene(station: station),
                const SizedBox(height: 14),
                _DilemmaCard(
                  station: station,
                  chosen: _chosen,
                  revealed: _revealed,
                  onChoose: (int option) => _reveal(choice: option),
                  onReveal: _reveal,
                ),
                if (_revealed) ...<Widget>[
                  const SizedBox(height: 14),
                  _DecisionCard(key: _decisionAnchor, station: station, sources: sources),
                ],
                const SizedBox(height: 14),
                SeerahNarrativeSection(station: station, sources: sources),
              ],
            ),
          ),
          if (_revealed)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey<String>('station-continue'),
                    onPressed: next == null
                        ? () => Navigator.of(context).maybePop()
                        : () => unawaited(_continueTo(next, ordered, index)),
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

/// عنوان بطاقة: أيقونة وعنوان تراثي.
class _CardHeading extends StatelessWidget {
  const _CardHeading({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Row(
      children: <Widget>[
        Icon(icon, color: palette.amberText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: AppTypography.heritageTitle(color: palette.ink, fontSize: 24),
          ),
        ),
      ],
    );
  }
}

/// المشهد الموجز: وصف الموقف في أربعة أسطر، وزر لفتحه كاملاً إن زاد عنها.
class _BriefScene extends StatefulWidget {
  const _BriefScene({required this.station});

  final SeerahStationModel station;

  @override
  State<_BriefScene> createState() => _BriefSceneState();
}

class _BriefSceneState extends State<_BriefScene> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final SeerahStationModel station = widget.station;
    final TextStyle style = AppTypography.athar(color: palette.ink, fontSize: 21);
    return SmoothSurface(
      key: const ValueKey<String>('station-brief'),
      elevated: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _CardHeading(icon: Icons.wb_sunny_outlined, title: 'المشهد الموجز'),
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
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final TextPainter probe = TextPainter(
                text: TextSpan(text: station.sceneDescription, style: style),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
                maxLines: _briefLines,
              )..layout(maxWidth: constraints.maxWidth);
              final bool longer = probe.didExceedMaxLines;
              probe.dispose();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    station.sceneDescription,
                    key: const ValueKey<String>('station-brief-text'),
                    maxLines: _expanded ? null : _briefLines,
                    overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: style,
                  ),
                  if (longer)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        key: const ValueKey<String>('station-brief-toggle'),
                        onPressed: () => setState(() => _expanded = !_expanded),
                        child: Text(_expanded ? 'طيّ المشهد' : 'قراءة المشهد كاملاً'),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// مأزق الشورى والتحدي: المأزق بنصه، ثم خياراته (إن نص عليها الشاهد) أو زر كشف.
class _DilemmaCard extends StatelessWidget {
  const _DilemmaCard({
    required this.station,
    required this.chosen,
    required this.revealed,
    required this.onChoose,
    required this.onReveal,
  });

  final SeerahStationModel station;
  final int? chosen;
  final bool revealed;
  final ValueChanged<int> onChoose;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final List<String> options = station.dilemmaOptions ?? const <String>[];
    return SmoothSurface(
      key: const ValueKey<String>('station-dilemma'),
      borderColor: palette.amber.withValues(alpha: 0.45),
      elevated: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _CardHeading(icon: Icons.help_outline_rounded, title: 'مأزق الشورى والتحدي'),
          const SizedBox(height: 10),
          Text(
            station.challenge,
            key: const ValueKey<String>('station-challenge'),
            style: AppTypography.athar(color: palette.ink, fontSize: 21),
          ),
          if (options.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              revealed ? 'اخترتَ:' : 'اختر ما تراه ثم يُكشف القرار النبوي:',
              style: text.labelLarge?.copyWith(color: palette.inkSoft, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < options.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 8),
              _OptionTile(
                index: i,
                label: options[i],
                selected: chosen == i,
                dimmed: revealed && chosen != i,
                onTap: revealed ? null : () => onChoose(i),
              ),
            ],
          ] else if (!revealed) ...<Widget>[
            const SizedBox(height: 16),
            WideActionButton(
              key: const ValueKey<String>('station-reveal'),
              label: 'اكشف القرار النبوي',
              subtitle: 'تأمّل الموقف أولاً ثم اكشف',
              icon: Icons.lightbulb_outline_rounded,
              onPressed: onReveal,
            ),
          ],
        ],
      ),
    );
  }
}

/// خيار واحد من خيارات المأزق: نصه كما ورد في الشاهد.
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.index,
    required this.label,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final int index;
  final String label;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return SmoothSurface(
      key: ValueKey<String>('station-option-$index'),
      onTap: onTap,
      semanticLabel: 'الخيار ${arabicDigits(index + 1)}: $label',
      color: selected ? palette.amberSoft : palette.surface,
      borderColor: selected ? palette.amber : palette.line,
      radius: AppShapes.radiusMedium,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: <Widget>[
          Icon(
            selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
            size: 22,
            color: selected ? palette.amberText : palette.inkSoft,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: AppTypography.athar(
                color: dimmed ? palette.inkSoft : palette.ink,
                fontSize: 19,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// القرار النبوي ونتيجته مع شاهده، يظهر بعد الاختيار أو الكشف.
class _DecisionCard extends StatelessWidget {
  const _DecisionCard({super.key, required this.station, required this.sources});

  final SeerahStationModel station;
  final SourceCatalog? sources;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final List<SeerahEvidence> evidence = station.evidenceFor(SeerahScene.decision);
    final Duration fade = MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 380);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: fade,
      curve: Curves.easeOut,
      builder: (BuildContext context, double opacity, Widget? child) => Opacity(opacity: opacity, child: child),
      child: SmoothSurface(
        key: const ValueKey<String>('station-decision'),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: <Color>[palette.emeraldSoft, palette.surface],
        ),
        elevated: true,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const _CardHeading(icon: Icons.lightbulb_outline_rounded, title: 'القرار النبوي ونتيجته'),
            const SizedBox(height: 10),
            Text(
              station.propheticDecision,
              key: const ValueKey<String>('station-decision-text'),
              style: AppTypography.athar(color: palette.ink, fontSize: 21),
            ),
            const SizedBox(height: 16),
            SectionEyebrow(
              evidence.length == 1 ? 'الشاهد من المصادر' : 'الشواهد من المصادر (${arabicDigits(evidence.length)})',
              icon: Icons.format_quote_rounded,
            ),
            const SizedBox(height: 8),
            for (final SeerahEvidence item in evidence) ...<Widget>[
              SourceQuoteTile(reference: item.source, source: sources?.byId(item.source.sourceId)),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
