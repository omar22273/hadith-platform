// «التفاصيل والرواية الكاملة»: ورقة سفلية قابلة للسحب والتمرير للمطالعة
// الموسعة. تعرض السرد المفصل للمحطة مشهداً مشهداً، وتحت كل مشهد النصوص
// المصدرية كاملة كما وردت في الشواهد المنقولة، مع إحالاتها.
//
// لا يُضاف هنا سرد من خارج ملف البيانات: السرد هو نصوص المشاهد الموثقة
// نفسها، والنص المصدري هو الشواهد نفسها بلا اقتطاع.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/content/models/source_catalog.dart';
import '../../../../core/content/source_catalog_provider.dart';
import '../../../../core/content/widgets/source_quote_tile.dart';
import '../../../../core/text/arabic_digits.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../data/models/seerah_station.dart';
import 'seerah_labels.dart';

/// يفتح ورقة التفاصيل.
Future<void> showSeerahDetailSheet(BuildContext context, SeerahStationModel station) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => SeerahDetailSheet(station: station),
  );
}

/// الورقة.
class SeerahDetailSheet extends ConsumerWidget {
  const SeerahDetailSheet({super.key, required this.station});

  /// المحطة.
  final SeerahStationModel station;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final SourceCatalog? sources = ref.watch(sourceCatalogProvider).value;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (BuildContext context, ScrollController controller) {
        return SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
            Text(
              'المحطة ${arabicDigits(station.order)} · ${epochLabel(station.epoch)}',
              style: text.labelMedium?.copyWith(color: palette.amberText, fontWeight: FontWeight.w600),
            ),
            Text(
              station.title,
              style: AppTypography.heritageTitle(color: palette.ink, fontSize: 30),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                SoftChip(label: station.place.name, icon: Icons.place_rounded),
                if (station.timeLabel != null) SoftChip(label: station.timeLabel!, icon: Icons.schedule_rounded),
              ],
            ),
            const SizedBox(height: 18),
            for (final SeerahScene scene in SeerahScene.values) ...<Widget>[
              _SceneSection(station: station, scene: scene, sources: sources),
              const SizedBox(height: 18),
            ],
            Text(
              'السرد أعلاه هو نصوص المشاهد الموثقة نفسها، والنصوص المصدرية منقولة كما وردت في الشواهد، '
              'وصياغة المشاهد بانتظار المراجعة العلمية.',
              style: text.labelSmall?.copyWith(color: palette.inkSoft, height: 1.7),
            ),
            ],
          ),
        );
      },
    );
  }
}

class _SceneSection extends StatelessWidget {
  const _SceneSection({required this.station, required this.scene, required this.sources});

  final SeerahStationModel station;
  final SeerahScene scene;
  final SourceCatalog? sources;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final List<SeerahEvidence> evidence = station.evidenceFor(scene);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(sceneIcon(scene), size: 20, color: palette.amberText),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                sceneTitle(scene),
                style: AppTypography.heritageTitle(color: palette.ink, fontSize: 22),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SmoothSurface(
          color: palette.surface,
          borderColor: palette.line,
          radius: AppShapes.radiusMedium,
          padding: const EdgeInsets.all(16),
          child: Text(
            sceneText(station, scene),
            style: AppTypography.athar(color: palette.ink, fontSize: 20).copyWith(height: 2.0),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          evidence.length == 1 ? 'النص المصدري' : 'النصوص المصدرية (${arabicDigits(evidence.length)})',
          style: text.labelLarge?.copyWith(color: palette.inkSoft, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        for (final SeerahEvidence item in evidence) ...<Widget>[
          SourceQuoteTile(reference: item.source, source: sources?.byId(item.source.sourceId)),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
