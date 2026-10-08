// البطاقة السفلية للمحطة: ملخص الحدث التاريخي بشواهده المنقولة، وأوراد
// المحطة، وزرّا البدء العريضان: «بدء وِرد التثبيت اللمسي» و«بدء مجلس السماع الشفاهي».

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/preferences/reception_mode.dart';
import '../../../../core/text/arabic_digits.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../../../core/ui/wide_action_button.dart';
import '../../../hadith/application/content_providers.dart';
import '../../../hadith/data/models/models.dart';
import '../../../hadith/presentation/widgets/source_quote_tile.dart';
import '../../application/journey_controller.dart';
import '../../domain/journey_snapshot.dart';
import 'station_labels.dart';

/// ما يختاره المستخدم من بطاقة المحطة.
sealed class StationAction {
  const StationAction(this.hadithId);

  /// الحديث.
  final String hadithId;
}

/// بدء وِرد التثبيت اللمسي (المراحل الأربع).
final class StartTouchSession extends StationAction {
  const StartTouchSession(super.hadithId);
}

/// بدء مجلس السماع الشفاهي.
final class StartOralSession extends StationAction {
  const StartOralSession(super.hadithId);
}

/// مراجعة وِرد مكتمل دون أن تُحسب وِرداً جديداً.
final class ReviewSession extends StationAction {
  const ReviewSession(super.hadithId);
}

/// محتوى البطاقة.
class StationSheet extends ConsumerWidget {
  const StationSheet({super.key, required this.stationIndex});

  /// المحطة.
  final int stationIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final JourneySnapshot? snapshot = ref.watch(journeyControllerProvider).value;
    final SourceCatalog? sources = ref.watch(sourceCatalogProvider).value;
    final ReceptionMode preferred = ref.watch(receptionModeProvider);
    if (snapshot == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final StationView view = snapshot.stations[stationIndex];
    final JourneyStation station = view.station;
    final bool locked = view.status == StationStatus.locked;
    final StationEvent? event = station.event;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'المحطة ${arabicDigits(station.order)} من ${arabicDigits(snapshot.stations.length)} · ${view.region.name}',
          style: text.labelMedium?.copyWith(
            color: palette.amberText,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          station.name,
          style: AppTypography.heritageTitle(color: palette.ink, fontSize: 32),
        ),
        Text(
          station.description,
          style: text.bodyMedium?.copyWith(color: palette.inkSoft),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: <Widget>[
            _StatusChip(view: view, today: snapshot.todayKind),
            SoftChip(label: stationDaysLabel(view), icon: Icons.wb_twilight_rounded),
          ],
        ),
        const SizedBox(height: 18),
        if (locked) ...<Widget>[
          _LockNotice(view: view, snapshot: snapshot),
          const SizedBox(height: 18),
        ],
        if (event != null) ...<Widget>[
          const SectionEyebrow('الحدث التاريخي', icon: Icons.auto_stories_rounded),
          const SizedBox(height: 6),
          Text(
            event.title,
            style: AppTypography.heritageTitle(color: palette.amberText, fontSize: 23),
          ),
          const SizedBox(height: 10),
          if (locked)
            Text(
              'تُعرض شواهد الحدث بنصوص مصادرها عند بلوغ القافلة هذه المحطة.',
              style: text.bodySmall?.copyWith(color: palette.inkSoft),
            )
          else
            _EventQuotes(event: event, sources: sources),
          const SizedBox(height: 20),
        ],
        const SectionEyebrow('أوراد المحطة', icon: Icons.menu_book_rounded),
        const SizedBox(height: 8),
        if (view.wirds.isEmpty)
          Text(
            'لم تُربط أوراد بهذه المحطة في نسخة المنهج الحالية.',
            style: text.bodyMedium?.copyWith(color: palette.inkSoft),
          )
        else
          for (final StationWird wird in view.wirds) ...<Widget>[
            _WirdRow(
              wird: wird,
              onReview: wird.status == WirdStatus.completed
                  ? () => Navigator.of(context).pop(ReviewSession(wird.item.hadithId))
                  : null,
            ),
            const SizedBox(height: 8),
          ],
        ..._actions(context, view, snapshot, preferred),
        const SizedBox(height: 14),
        Text(
          'الموضع تقريبي: ${arabicDigits(station.latitude.toStringAsFixed(2))}° ش، '
          '${arabicDigits(station.longitude.abs().toStringAsFixed(2))}° ${station.longitude < 0 ? 'غ' : 'ق'}',
          style: text.labelSmall?.copyWith(color: palette.inkSoft),
        ),
      ],
    );
  }

  List<Widget> _actions(
    BuildContext context,
    StationView view,
    JourneySnapshot snapshot,
    ReceptionMode preferred,
  ) {
    final CurriculumItem? next = snapshot.nextItem;
    if (next == null || next.stationId != view.station.id) {
      return const <Widget>[];
    }
    final bool available = snapshot.todayKind == TodayKind.available;
    final String hadithId = next.hadithId;
    final String? waitingNote = available ? null : 'يُفتح عند الفجر';

    final WideActionButton touch = WideActionButton(
      label: 'بدء وِرد التثبيت اللمسي',
      subtitle: waitingNote ?? 'السياق، والمتن والغريب، والترصيع والتلاشي، والإسقاط السلوكي',
      icon: Icons.touch_app_rounded,
      tone: preferred == ReceptionMode.touch ? WideActionTone.primary : WideActionTone.secondary,
      onPressed: available ? () => Navigator.of(context).pop(StartTouchSession(hadithId)) : null,
    );
    final WideActionButton oral = WideActionButton(
      label: 'بدء مجلس السماع الشفاهي',
      subtitle: waitingNote ?? 'سرد القصة، والتلقين بالترديد، والمأزق بمساحات لمس كبيرة',
      icon: Icons.headphones_rounded,
      tone: preferred == ReceptionMode.oral ? WideActionTone.primary : WideActionTone.secondary,
      giant: preferred == ReceptionMode.oral,
      onPressed: available ? () => Navigator.of(context).pop(StartOralSession(hadithId)) : null,
    );
    final List<Widget> ordered = preferred == ReceptionMode.oral
        ? <Widget>[oral, const SizedBox(height: 10), touch]
        : <Widget>[touch, const SizedBox(height: 10), oral];
    return <Widget>[
      const SizedBox(height: 12),
      if (!available) ...<Widget>[
        _CapNotice(snapshot: snapshot),
        const SizedBox(height: 12),
      ],
      ...ordered,
    ];
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.view, required this.today});

  final StationView view;
  final TodayKind today;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final String label = stationStatusLine(view, today);
    switch (view.status) {
      case StationStatus.completed:
        return SoftChip(
          label: label,
          icon: Icons.verified_outlined,
          background: palette.emeraldSoft,
          foreground: palette.emeraldText,
          borderColor: palette.emerald.withValues(alpha: 0.4),
        );
      case StationStatus.active:
        return SoftChip(
          label: label,
          icon: Icons.explore_rounded,
          background: palette.amberSoft,
          foreground: palette.amberText,
          borderColor: palette.amber.withValues(alpha: 0.5),
        );
      case StationStatus.locked:
        return SoftChip(
          label: label,
          icon: Icons.lock_clock,
          foreground: palette.locked,
        );
    }
  }
}

class _LockNotice extends StatelessWidget {
  const _LockNotice({required this.view, required this.snapshot});

  final StationView view;
  final JourneySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final String body;
    switch (view.lockReason) {
      case StationLockReason.awaitingDawn:
        {
          final DateTime? at = snapshot.nextUnlockAt;
          body = at == null
              ? 'أتممتَ وِرد اليوم. تسير القافلة إلى هذه المحطة عند الفجر.'
              : 'أتممتَ وِرد اليوم. تسير القافلة إلى هذه المحطة عند الفجر '
                  '(${arabicDigits(at.hour)}:${arabicDigits(at.minute.toString().padLeft(2, '0'))}'
                  '${snapshot.unlockUsesFallback ? ' بالوقت الاحتياطي' : ''}).';
        }
      case StationLockReason.notInCurriculumYet:
        body = 'تُفتح حين تُربط بها أورادها في المنهج. شواهد حدثها محفوظة وتظهر عند بلوغها.';
      case StationLockReason.awaitingPrevious:
      case null:
        {
          final int previous = view.index - 1;
          final String previousName =
              previous >= 0 ? snapshot.stations[previous].station.name : '';
          body = previousName.isEmpty
              ? 'تُفتح حين يحين وِردها.'
              : 'تُفتح حين يحين وِردها، بعد إتمام أوراد محطة «$previousName».';
        }
    }
    return SmoothSurface(
      color: palette.lockedSoft,
      borderColor: palette.line,
      radius: AppShapes.radiusMedium,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.lock_clock, color: palette.locked, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text(body, style: text.bodyMedium?.copyWith(color: palette.ink)),
          ),
        ],
      ),
    );
  }
}

class _CapNotice extends StatelessWidget {
  const _CapNotice({required this.snapshot});

  final JourneySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final DateTime? at = snapshot.nextUnlockAt;
    return SmoothSurface(
      color: palette.amberSoft,
      borderColor: palette.amber.withValues(alpha: 0.4),
      radius: AppShapes.radiusMedium,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            snapshot.curriculum.dailyCap.completionMessage,
            style: AppTypography.athar(color: palette.amberText, fontSize: 19, fontWeight: FontWeight.w700),
          ),
          if (at != null)
            Text(
              'يُفتح الوِرد التالي عند الفجر · ${arabicDigits(at.hour)}:${arabicDigits(at.minute.toString().padLeft(2, '0'))}'
              '${snapshot.unlockUsesFallback ? ' (الوقت الاحتياطي في المنهج)' : ''}',
              style: text.bodySmall?.copyWith(color: palette.ink),
            ),
        ],
      ),
    );
  }
}

class _WirdRow extends StatelessWidget {
  const _WirdRow({required this.wird, required this.onReview});

  final StationWird wird;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final bool done = wird.status == WirdStatus.completed;
    final bool today = wird.status == WirdStatus.today;
    return SmoothSurface(
      color: palette.surfaceMuted,
      borderColor: today ? palette.amber : palette.line,
      radius: AppShapes.radiusMedium,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  wird.item.title,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'اليوم ${arabicDigits(wird.dayNumber)} · ${wirdStatusLabel(wird.status)}',
                  style: text.labelSmall?.copyWith(
                    color: done
                        ? palette.emeraldText
                        : today
                            ? palette.amberText
                            : palette.inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (onReview != null)
            TextButton.icon(
              onPressed: onReview,
              icon: const Icon(Icons.replay_rounded, size: 18),
              label: const Text('مراجعة'),
            ),
        ],
      ),
    );
  }
}

class _EventQuotes extends StatefulWidget {
  const _EventQuotes({required this.event, required this.sources});

  final StationEvent event;
  final SourceCatalog? sources;

  @override
  State<_EventQuotes> createState() => _EventQuotesState();
}

class _EventQuotesState extends State<_EventQuotes> {
  static const int _initiallyShown = 2;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final List<SourceRef> all = widget.event.sources;
    final List<SourceRef> shown =
        _expanded || all.length <= _initiallyShown ? all : all.sublist(0, _initiallyShown);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final SourceRef ref in shown) ...<Widget>[
          SourceQuoteTile(reference: ref, source: widget.sources?.byId(ref.sourceId)),
          const SizedBox(height: 8),
        ],
        if (!_expanded && all.length > _initiallyShown)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = true),
              icon: const Icon(Icons.expand_more_rounded),
              label: Text('بقية الشواهد (${arabicDigits(all.length - _initiallyShown)})'),
            ),
          ),
      ],
    );
  }
}
