// شريط التبديل بين مسارَي الفئة (صباح|مساء، نوم|استيقاظ، منزل|مسجد): زران متساويان
// بحواف ناعمة، المختار منهما بلون العنبر الهادئ. التسميات بالرموز التعبيرية كما حددها
// مالك المشروع حرفياً (AdhkarCategory.tracks)، وتلتف إلى سطرين أو أكثر بدل أن تفيض
// على الهاتف الضيق أو مع تكبير الخط.

import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../domain/adhkar_category.dart';

/// شريط تبديل المسارات.
class AdhkarTrackToggle extends StatelessWidget {
  const AdhkarTrackToggle({
    super.key,
    required this.tracks,
    required this.selectedId,
    required this.onSelected,
  });

  /// المسارات بترتيب عرضها.
  final List<AdhkarTrack> tracks;

  /// معرّف المسار المختار.
  final String selectedId;

  /// اختيار مسار.
  final ValueChanged<AdhkarTrack> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: palette.surfaceMuted,
        shape: AppShapes.rounded(AppShapes.radiusMedium, side: BorderSide(color: palette.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int i = 0; i < tracks.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: _Segment(
                    track: tracks[i],
                    selected: tracks[i].id == selectedId,
                    onTap: () => onSelected(tracks[i]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.track, required this.selected, required this.onTap});

  final AdhkarTrack track;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: SmoothSurface(
        key: ValueKey<String>('adhkar-track-${track.id}'),
        onTap: selected ? null : onTap,
        color: selected ? palette.amberSoft : Colors.transparent,
        borderColor: selected ? palette.amber : null,
        radius: AppShapes.radiusSmall,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        semanticLabel: track.label,
        child: Center(
          child: Text(
            track.label,
            textAlign: TextAlign.center,
            style: text.labelLarge?.copyWith(
              color: selected ? palette.amberText : palette.inkSoft,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}
