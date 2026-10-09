// التبويب الثاني: رحلة السيرة النبوية من عام الفيل إلى الرفيق الأعلى.
// خريطة تاريخية تفاعلية مستقلة عن مسار الأحاديث، وشريط زمن بالحقب الثلاث،
// وبطاقة المحطة المختارة تفتح مشاهدها الثلاثة.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/json/json_reader.dart';
import '../../../core/text/arabic_digits.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/ui/app_shapes.dart';
import '../../../core/ui/smooth_sheet.dart';
import '../../../core/ui/smooth_surface.dart';
import '../../../core/ui/wide_action_button.dart';
import '../application/seerah_providers.dart';
import '../data/models/seerah_station.dart';
import '../domain/seerah_map.dart';
import '../domain/seerah_repository.dart';
import 'seerah_scene_screen.dart';
import 'widgets/seerah_labels.dart';
import 'widgets/seerah_map_view.dart';
import 'widgets/seerah_timeline.dart';

/// شاشة رحلة السيرة.
class SeerahJourneyScreen extends ConsumerWidget {
  const SeerahJourneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SeerahDataset> dataset = ref.watch(seerahDatasetProvider);
    final AsyncValue<SeerahLand> land = ref.watch(seerahLandProvider);
    final AsyncValue<SeerahRoute> route = ref.watch(seerahRouteProvider);
    final Object? error = dataset.error ?? land.error ?? route.error;
    final Widget body;
    if (error != null) {
      body = _ErrorView(
        error: error,
        onRetry: () {
          ref.invalidate(seerahDatasetProvider);
          ref.invalidate(seerahLandProvider);
          ref.invalidate(seerahRouteProvider);
        },
      );
    } else if (dataset.value == null || land.value == null || route.value == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = _JourneyBody(dataset: dataset.value!, land: land.value!, route: route.value!);
    }
    return Scaffold(body: SafeArea(bottom: false, child: body));
  }
}

class _JourneyBody extends ConsumerWidget {
  const _JourneyBody({required this.dataset, required this.land, required this.route});

  final SeerahDataset dataset;
  final SeerahLand land;
  final SeerahRoute route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final List<SeerahStationModel> stations = dataset.chronological;
    final String? chosen = ref.watch(selectedSeerahStationProvider);
    int selectedIndex = 0;
    for (int i = 0; i < stations.length; i++) {
      if (stations[i].id == chosen) {
        selectedIndex = i;
        break;
      }
    }
    final Set<String> visited = ref.watch(seerahVisitedProvider);
    final int visitedCount = stations.where((SeerahStationModel s) => visited.contains(s.id)).length;

    void select(int index) {
      ref.read(selectedSeerahStationProvider.notifier).select(stations[index].id);
    }

    Future<void> openScenes(SeerahStationModel station) async {
      ref.read(selectedSeerahStationProvider.notifier).select(station.id);
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext routeContext) => SeerahSceneScreen(stationId: station.id),
        ),
      );
    }

    Future<void> openCluster(SeerahPlaceCluster cluster) async {
      if (cluster.stations.length == 1) {
        ref.read(selectedSeerahStationProvider.notifier).select(cluster.stations.first.id);
        return;
      }
      final SeerahStationModel? picked = await showSmoothSheet<SeerahStationModel>(
        context: context,
        builder: (BuildContext sheetContext) => _ClusterSheet(cluster: cluster, visited: visited),
      );
      if (picked != null && context.mounted) {
        ref.read(selectedSeerahStationProvider.notifier).select(picked.id);
      }
    }

    final SeerahStationModel selected = stations[selectedIndex];
    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  dataset.title,
                  style: text.labelLarge?.copyWith(color: palette.amberText, fontWeight: FontWeight.w600),
                ),
                Text(
                  'رحلة السيرة',
                  style: AppTypography.heritageTitle(color: palette.ink, fontSize: 34),
                ),
                Text(
                  'لكل محطة ثلاثة مشاهد: المشهد الزماني، والمأزق، والقرار النبوي ونتيجته · '
                  'أتممتَ ${arabicDigits(visitedCount)} من ${arabicDigits(stations.length)}',
                  style: text.bodySmall?.copyWith(color: palette.inkSoft),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: SmoothSurface(
              elevated: true,
              padding: EdgeInsets.zero,
              child: ClipPath(
                clipper: ShapeBorderClipper(shape: AppShapes.rounded(AppShapes.radiusLarge)),
                child: SeerahMapView(
                  land: land,
                  route: route,
                  stations: stations,
                  selectedIndex: selectedIndex,
                  visited: visited,
                  onClusterTap: openCluster,
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 4),
            child: Text(
              'قرّب الخريطة بإصبعين، والمس موضعاً لتختار محطاته.',
              style: text.labelSmall?.copyWith(color: palette.inkSoft),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SeerahTimeline(
            stations: stations,
            selectedIndex: selectedIndex,
            visited: visited,
            onSelect: select,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          sliver: SliverToBoxAdapter(
            child: _SelectedStationCard(
              station: selected,
              total: stations.length,
              visited: visited.contains(selected.id),
              onOpen: () => openScenes(selected),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 28),
            child: Text(
              'الشواهد منقولة بنصها من أمهات كتب السيرة والحديث، وصياغة المشاهد مقتصرة عليها وتنتظر المراجعة العلمية. '
              'اليابسة على الخريطة من Natural Earth (ملكية عامة)، والمواضع تقريبية.',
              style: text.labelSmall?.copyWith(color: palette.inkSoft, height: 1.7),
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectedStationCard extends StatelessWidget {
  const _SelectedStationCard({
    required this.station,
    required this.total,
    required this.visited,
    required this.onOpen,
  });

  final SeerahStationModel station;
  final int total;
  final bool visited;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return SmoothSurface(
      elevated: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'المحطة ${arabicDigits(station.order)} من ${arabicDigits(total)} · ${epochLabel(station.epoch)}',
            style: text.labelMedium?.copyWith(color: palette.amberText, fontWeight: FontWeight.w600),
          ),
          Text(
            station.title,
            style: AppTypography.heritageTitle(color: palette.ink, fontSize: 28),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              SoftChip(label: station.place.name, icon: Icons.place_rounded),
              if (station.timeLabel != null) SoftChip(label: station.timeLabel!, icon: Icons.schedule_rounded),
              if (visited)
                SoftChip(
                  label: 'أتممتَ مشاهدها',
                  icon: Icons.verified_rounded,
                  background: palette.emeraldSoft,
                  foreground: palette.emeraldText,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            station.sceneDescription,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.athar(color: palette.ink, fontSize: 18),
          ),
          const SizedBox(height: 14),
          WideActionButton(
            label: visited ? 'أعد مشاهدة المشاهد الثلاثة' : 'ادخل المشاهد الثلاثة',
            subtitle: 'المشهد الزماني ← المأزق ← القرار النبوي ونتيجته',
            icon: Icons.theaters_rounded,
            onPressed: onOpen,
          ),
        ],
      ),
    );
  }
}

class _ClusterSheet extends StatelessWidget {
  const _ClusterSheet({required this.cluster, required this.visited});

  final SeerahPlaceCluster cluster;
  final Set<String> visited;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          cluster.name,
          style: AppTypography.heritageTitle(color: palette.ink, fontSize: 30),
        ),
        Text(
          'محطات هذا الموضع بترتيبها الزمني',
          style: text.bodySmall?.copyWith(color: palette.inkSoft),
        ),
        const SizedBox(height: 12),
        for (final SeerahStationModel station in cluster.stations) ...<Widget>[
          SmoothSurface(
            onTap: () => Navigator.of(context).pop(station),
            semanticLabel: 'المحطة ${arabicDigits(station.order)}: ${station.title}',
            radius: AppShapes.radiusMedium,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                Text(
                  arabicDigits(station.order),
                  style: text.titleLarge?.copyWith(color: palette.amberText, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        station.title,
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        epochLabel(station.epoch),
                        style: text.labelSmall?.copyWith(color: palette.inkSoft),
                      ),
                    ],
                  ),
                ),
                if (visited.contains(station.id)) Icon(Icons.verified_rounded, color: palette.emeraldText),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final String detail = switch (error) {
      SeerahIntegrityException(:final List<String> issues) => issues.join('\n'),
      JsonParseException(:final String message) => message,
      _ => error.toString(),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.map_outlined, size: 44, color: palette.inkSoft),
            const SizedBox(height: 12),
            Text(
              'تعذّر تجهيز رحلة السيرة',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'لم يُعرض شيء حتى لا يظهر مشهد بلا شاهده الموثق.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: palette.inkSoft),
            ),
            const SizedBox(height: 10),
            SelectableText(
              detail,
              textAlign: TextAlign.center,
              style: text.labelSmall?.copyWith(color: palette.inkSoft),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
