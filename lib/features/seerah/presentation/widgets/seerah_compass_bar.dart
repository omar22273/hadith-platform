// شريط البوصلة الزمانية والمكانية في أعلى كل محطة:
// [العهد • السنة • عمر النبي ﷺ • الموقع الجغرافي].
//
// العهد والموقع من بيانات المحطة. السنة والعمر لا يُعرضان إلا إذا نصّ عليهما
// شاهد منقول بنصه، وزر ⓘ يفتح ورقة تعرض ذلك الشاهد؛ فلا رقم يُستنتج هنا.

import 'package:flutter/material.dart';

import '../../../../core/content/models/source_catalog.dart';
import '../../../../core/content/models/source_ref.dart';
import '../../../../core/content/widgets/source_quote_tile.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_sheet.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../data/models/seerah_station.dart';
import 'seerah_labels.dart';

/// شريط البوصلة.
class SeerahCompassBar extends StatelessWidget {
  const SeerahCompassBar({super.key, required this.station, required this.sources});

  /// المحطة.
  final SeerahStationModel station;

  /// فهرس المصادر لعرض شاهد الورقة.
  final SourceCatalog? sources;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return SmoothSurface(
      key: const ValueKey<String>('station-compass'),
      color: palette.surfaceMuted,
      borderColor: palette.line,
      radius: AppShapes.radiusMedium,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 18,
                runSpacing: 8,
                children: <Widget>[
                  _CompassCell(
                    cellKey: const ValueKey<String>('compass-covenant'),
                    icon: covenantIcon(station.covenant),
                    caption: 'العهد',
                    value: covenantLabel(station.covenant),
                  ),
                  if (station.yearLabel != null)
                    _CompassCell(
                      cellKey: const ValueKey<String>('compass-year'),
                      icon: Icons.event_rounded,
                      caption: 'السنة',
                      value: station.yearLabel!,
                    ),
                  if (station.ageLabel != null)
                    _CompassCell(
                      cellKey: const ValueKey<String>('compass-age'),
                      icon: Icons.person_outline_rounded,
                      caption: 'عمر النبي ﷺ',
                      value: station.ageLabel!,
                    ),
                  _CompassCell(
                    cellKey: const ValueKey<String>('compass-place'),
                    icon: Icons.place_rounded,
                    caption: 'الموقع',
                    value: station.place.name,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            key: const ValueKey<String>('station-compass-info'),
            tooltip: 'مستند شريط البوصلة',
            onPressed: () => showSmoothSheet<void>(
              context: context,
              builder: (BuildContext sheetContext) => _CompassBasisSheet(station: station, sources: sources),
            ),
            icon: Icon(Icons.info_outline_rounded, color: palette.amberText),
          ),
        ],
      ),
    );
  }
}

class _CompassCell extends StatelessWidget {
  const _CompassCell({
    required this.cellKey,
    required this.icon,
    required this.caption,
    required this.value,
  });

  final Key cellKey;
  final IconData icon;
  final String caption;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '$caption: $value',
      child: ExcludeSemantics(
        child: Row(
          key: cellKey,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 18, color: palette.amberText),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(caption, style: text.labelSmall?.copyWith(color: palette.inkSoft)),
                  Text(
                    value,
                    style: AppTypography.ui(
                      color: palette.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ورقة مستند البوصلة: الشواهد الحرفية للسنة والعمر، أو بيان أن الشواهد لم تنص عليهما.
class _CompassBasisSheet extends StatelessWidget {
  const _CompassBasisSheet({required this.station, required this.sources});

  final SeerahStationModel station;
  final SourceCatalog? sources;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final List<SourceRef> basis = station.compassBasis ?? const <SourceRef>[];
    return Column(
      key: const ValueKey<String>('compass-basis-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'مستند شريط البوصلة',
          style: AppTypography.heritageTitle(color: palette.ink, fontSize: 28),
        ),
        const SizedBox(height: 6),
        Text(
          'العهد والموقع من بيانات المحطة. أما السنة وعمر النبي ﷺ فلا يُعرضان إلا إذا نصّ عليهما '
          'شاهد منقول بنصه، وهذا الشاهد:',
          style: text.bodyMedium?.copyWith(color: palette.inkSoft, height: 1.8),
        ),
        const SizedBox(height: 12),
        if (basis.isEmpty)
          SmoothSurface(
            key: const ValueKey<String>('compass-basis-empty'),
            color: palette.amberSoft,
            borderColor: palette.amber.withValues(alpha: 0.45),
            radius: AppShapes.radiusMedium,
            padding: const EdgeInsets.all(14),
            child: Text(
              'لم تنصّ الشواهد المثبّتة لهذه المحطة على سنة ولا على عمر، فلم يُعرضا.',
              style: AppTypography.ui(color: palette.amberText, fontSize: 14, height: 1.8),
            ),
          )
        else
          for (final SourceRef reference in basis) ...<Widget>[
            SourceQuoteTile(reference: reference, source: sources?.byId(reference.sourceId)),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}
