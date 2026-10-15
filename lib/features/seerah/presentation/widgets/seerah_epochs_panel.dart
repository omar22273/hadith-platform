// لوحة الأطوار: منهج السيرة مقسماً إلى أطوار تاريخية كبرى متسلسلة، كل طور بطاقة
// تُفتح فتُظهر محطاته بترتيبها الزمني. يُفتح طور المحطة المختارة تلقائياً، والطور
// الذي لم تُضَف محطاته بعد يُعرض بترتيبه ويبقى مفتوحاً للبيان لا مخفياً.

import 'package:flutter/material.dart';

import '../../../../core/text/arabic_digits.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../data/models/seerah_station.dart';
import 'seerah_labels.dart';

/// لوحة الأطوار.
class SeerahEpochsPanel extends StatefulWidget {
  const SeerahEpochsPanel({
    super.key,
    required this.dataset,
    required this.selectedStationId,
    required this.visited,
    required this.onSelect,
  });

  /// ملف السيرة بأطواره ومحطاته.
  final SeerahDataset dataset;

  /// المحطة المختارة؛ يُفتح طورها.
  final String selectedStationId;

  /// المحطات التي أتمّها المستخدم.
  final Set<String> visited;

  /// اختيار محطة من اللوحة.
  final ValueChanged<SeerahStationModel> onSelect;

  @override
  State<SeerahEpochsPanel> createState() => _SeerahEpochsPanelState();
}

class _SeerahEpochsPanelState extends State<SeerahEpochsPanel> {
  String? _open;

  String? _epochOfSelected() {
    return widget.dataset.stationById(widget.selectedStationId)?.epochId;
  }

  @override
  void initState() {
    super.initState();
    _open = _epochOfSelected();
  }

  @override
  void didUpdateWidget(SeerahEpochsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedStationId != widget.selectedStationId) {
      _open = _epochOfSelected() ?? _open;
    }
  }

  void _toggle(String epochId) {
    setState(() => _open = _open == epochId ? null : epochId);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final List<SeerahEpochInfo> epochs = widget.dataset.epochsInOrder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 10),
          child: Semantics(
            header: true,
            child: Text(
              'منهج السيرة في ${arabicDigits(epochs.length)} أطوار',
              key: const ValueKey<String>('epochs-panel-title'),
              style: AppTypography.heritageTitle(color: palette.ink, fontSize: 26),
            ),
          ),
        ),
        for (final SeerahEpochInfo epoch in epochs) ...<Widget>[
          _EpochBlock(
            epoch: epoch,
            stations: widget.dataset.stationsOfEpoch(epoch.id),
            open: _open == epoch.id,
            selectedStationId: widget.selectedStationId,
            visited: widget.visited,
            onToggle: () => _toggle(epoch.id),
            onSelect: widget.onSelect,
          ),
          const SizedBox(height: 10),
        ],
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 0),
          child: Text(
            'الأطوار عناوين المنهج؛ وتُضاف محطات كل طور بنصوصها الموثقة كلما أُدرج من الكتب المثبتة.',
            style: text.labelSmall?.copyWith(color: palette.inkSoft, height: 1.7),
          ),
        ),
      ],
    );
  }
}

class _EpochBlock extends StatelessWidget {
  const _EpochBlock({
    required this.epoch,
    required this.stations,
    required this.open,
    required this.selectedStationId,
    required this.visited,
    required this.onToggle,
    required this.onSelect,
  });

  final SeerahEpochInfo epoch;
  final List<SeerahStationModel> stations;
  final bool open;
  final String selectedStationId;
  final Set<String> visited;
  final VoidCallback onToggle;
  final ValueChanged<SeerahStationModel> onSelect;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final int done = stations.where((SeerahStationModel s) => visited.contains(s.id)).length;
    final bool holdsSelected = stations.any((SeerahStationModel s) => s.id == selectedStationId);
    final String progress = stations.isEmpty
        ? stationCountLabel(0)
        : (done == 0
            ? stationCountLabel(stations.length)
            : '${stationCountLabel(stations.length)} · أتممتَ ${arabicDigits(done)}');
    final Duration slide = MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 220);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SmoothSurface(
          key: ValueKey<String>('epoch-tile-${epoch.id}'),
          onTap: onToggle,
          semanticLabel:
              'الطور ${arabicDigits(epoch.number)}: ${epoch.title}، $progress، ${open ? 'مفتوح' : 'مطوي'}',
          color: holdsSelected ? palette.amberSoft : palette.surface,
          borderColor: holdsSelected ? palette.amber : palette.line,
          radius: AppShapes.radiusMedium,
          padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 8, 12),
          child: Row(
            children: <Widget>[
              _NumberBadge(number: epoch.number, active: holdsSelected),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      epoch.title,
                      style: AppTypography.heritageTitle(color: palette.ink, fontSize: 21),
                    ),
                    Text(
                      progress,
                      style: text.labelMedium?.copyWith(
                        color: stations.isEmpty ? palette.inkSoft : palette.amberText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: palette.inkSoft),
            ],
          ),
        ),
        AnimatedSize(
          duration: slide,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: open
              ? Padding(
                  padding: const EdgeInsetsDirectional.only(start: 18, top: 8),
                  child: stations.isEmpty
                      ? _EmptyEpochNote(key: ValueKey<String>('epoch-empty-${epoch.id}'))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            for (final SeerahStationModel station in stations) ...<Widget>[
                              _StationRow(
                                station: station,
                                selected: station.id == selectedStationId,
                                visited: visited.contains(station.id),
                                onTap: () => onSelect(station),
                              ),
                              const SizedBox(height: 6),
                            ],
                          ],
                        ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.number, required this.active});

  final int number;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: active ? palette.amber : palette.surfaceMuted,
        shape: AppShapes.rounded(
          AppShapes.radiusSmall,
          side: BorderSide(color: active ? palette.amber : palette.line),
        ),
      ),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: Text(
            arabicDigits(number),
            style: AppTypography.ui(
              color: active ? palette.surface : palette.amberText,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _StationRow extends StatelessWidget {
  const _StationRow({
    required this.station,
    required this.selected,
    required this.visited,
    required this.onTap,
  });

  final SeerahStationModel station;
  final bool selected;
  final bool visited;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return SmoothSurface(
      key: ValueKey<String>('epoch-station-${station.id}'),
      onTap: onTap,
      semanticLabel: 'المحطة ${arabicDigits(station.order)}: ${station.title}${visited ? '، مكتملة' : ''}',
      color: selected ? palette.amberSoft : palette.surface,
      borderColor: selected ? palette.amber : palette.line,
      borderWidth: selected ? 1.6 : 1,
      radius: AppShapes.radiusSmall,
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 10, 10),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 28,
            child: Text(
              arabicDigits(station.order),
              style: text.titleMedium?.copyWith(color: palette.amberText, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  station.title,
                  style: text.titleSmall?.copyWith(color: palette.ink, fontWeight: FontWeight.w700, height: 1.5),
                ),
                Text(
                  station.place.name,
                  style: text.labelSmall?.copyWith(color: palette.inkSoft),
                ),
              ],
            ),
          ),
          if (visited) Icon(Icons.verified_rounded, size: 20, color: palette.emeraldText),
        ],
      ),
    );
  }
}

class _EmptyEpochNote extends StatelessWidget {
  const _EmptyEpochNote({super.key});

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return SmoothSurface(
      color: palette.surfaceMuted,
      borderColor: palette.line,
      radius: AppShapes.radiusSmall,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.hourglass_empty_rounded, size: 20, color: palette.inkSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'محطات هذا الطور تصل مع حزمة المحتوى القادمة من نص الكتاب الكامل، ولن يُكتب فيه شيء من الذاكرة.',
              style: AppTypography.ui(color: palette.inkSoft, fontSize: 13.5, height: 1.8),
            ),
          ),
        ],
      ),
    );
  }
}
