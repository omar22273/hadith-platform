// المرحلة الأولى: سياق الورود والحدث التاريخي، مع تنبيهات التحقيق العلمي.

import 'package:flutter/material.dart';

import '../../../../core/content/widgets/source_quote_tile.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../../hadith/data/models/models.dart';
import '../../../hadith/domain/hadith_bundle.dart';

/// مرحلة السياق.
class ContextStage extends StatelessWidget {
  const ContextStage({super.key, required this.bundle});

  /// الحديث وفهارسه.
  final HadithBundle bundle;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final HistoricalContext historical = bundle.hadith.context;
    final HistoricalPlace? place = historical.place;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        SmoothSurface(
          elevated: true,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionEyebrow('سياق الورود', icon: Icons.auto_stories_rounded),
              const SizedBox(height: 10),
              Text(
                historical.narrative,
                style: AppTypography.ui(color: palette.ink, fontSize: 17, height: 1.95),
              ),
              const SizedBox(height: 14),
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: palette.amberSoft,
                  shape: AppShapes.rounded(AppShapes.radiusSmall),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.psychology_alt_rounded, size: 20, color: palette.amberText),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          historical.humanMotive,
                          style: text.bodyMedium?.copyWith(
                            color: palette.amberText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (place != null) ...<Widget>[
                const SizedBox(height: 12),
                SoftChip(
                  icon: Icons.place_rounded,
                  label: '${place.name} · ${_relationLabel(place.relation)}'
                      '${place.coordinatesApproximate ? ' · موضع تقريبي' : ''}',
                ),
              ],
            ],
          ),
        ),
        if (historical.cautions.isNotEmpty) ...<Widget>[
          const SizedBox(height: 18),
          const SectionEyebrow('تنبيهات التحقيق العلمي', icon: Icons.fact_check_outlined),
          const SizedBox(height: 8),
          for (final ContextCaution caution in historical.cautions) ...<Widget>[
            SmoothSurface(
              color: palette.surfaceMuted,
              borderColor: palette.line,
              radius: AppShapes.radiusMedium,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.info_outline_rounded, size: 20, color: palette.inkSoft),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          caution.text,
                          style: text.bodyMedium?.copyWith(color: palette.ink, height: 1.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final SourceRef ref in caution.sources) ...<Widget>[
                    SourceQuoteTile(reference: ref, source: bundle.sources.byId(ref.sourceId)),
                    const SizedBox(height: 6),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
        const SizedBox(height: 14),
        _SourcesSection(bundle: bundle),
      ],
    );
  }

  static String _relationLabel(PlaceRelation relation) {
    switch (relation) {
      case PlaceRelation.eventLocation:
        return 'مكان وقوع الحدث';
      case PlaceRelation.subjectLocation:
        return 'مكان يدور عليه موضوع الحديث';
    }
  }
}

class _SourcesSection extends StatelessWidget {
  const _SourcesSection({required this.bundle});

  final HadithBundle bundle;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final List<SourceRef> sources = bundle.hadith.context.sources;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        iconColor: palette.amberText,
        collapsedIconColor: palette.inkSoft,
        title: const SectionEyebrow('مصادر القصة بنصوصها', icon: Icons.format_quote_rounded),
        children: <Widget>[
          for (final SourceRef ref in sources) ...<Widget>[
            SourceQuoteTile(reference: ref, source: bundle.sources.byId(ref.sourceId)),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
