// التبويب الأول: مسار الأربعين النووية. طريق قوافل متعرج مخصص لأوراد
// الأحاديث وحدها، لا يتصل بمحطات السيرة ولا بحواضر الرواية.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_tab.dart';
import '../../../core/preferences/reception_mode.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/ui/app_shapes.dart';
import '../../../core/ui/smooth_sheet.dart';
import '../../daily_session/presentation/daily_hadith_session_screen.dart';
import '../../hadith/application/hadith_providers.dart';
import '../../hadith/data/models/models.dart';
import '../../hadith/domain/hadith_repository.dart';
import '../../oral_mode/presentation/oral_mode_screen.dart';
import '../application/journey_controller.dart';
import '../application/journey_progress_controller.dart';
import '../application/pacing_notifier.dart';
import '../domain/journey_snapshot.dart';
import 'widgets/caravan_trail_view.dart';
import 'widgets/journey_summary_card.dart';
import 'widgets/wird_sheet.dart';

/// شاشة مسار الأربعين.
class ArbaeenPathScreen extends ConsumerStatefulWidget {
  const ArbaeenPathScreen({super.key});

  @override
  ConsumerState<ArbaeenPathScreen> createState() => _ArbaeenPathScreenState();
}

class _ArbaeenPathScreenState extends ConsumerState<ArbaeenPathScreen> {
  Future<void> _openNode(int index) async {
    final WirdAction? action = await showSmoothSheet<WirdAction>(
      context: context,
      builder: (BuildContext sheetContext) => WirdSheet(nodeIndex: index),
    );
    if (!mounted || action == null) {
      return;
    }
    final Widget screen;
    switch (action) {
      case StartTouchSession(:final String hadithId):
        screen = DailyHadithSessionScreen(hadithId: hadithId, countsTowardJourney: true);
      case StartOralSession(:final String hadithId):
        screen = OralModeScreen(hadithId: hadithId, countsTowardJourney: true);
      case ReviewSession(:final String hadithId):
        screen = DailyHadithSessionScreen(hadithId: hadithId, countsTowardJourney: false);
      case OpenReviewArena():
        ref.read(appTabProvider.notifier).select(AppTab.review);
        return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (BuildContext routeContext) => screen),
    );
  }

  void _retry() {
    ref.invalidate(curriculumProvider);
    ref.invalidate(journeyProgressProvider);
    ref.invalidate(pacingProvider);
    ref.invalidate(journeyControllerProvider);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<JourneySnapshot> journey = ref.watch(journeyControllerProvider);
    final String? curriculumTitle = ref.watch(curriculumProvider).value?.title;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: journey.when(
          skipLoadingOnReload: true,
          loading: () => const _LoadingView(),
          error: (Object error, StackTrace stackTrace) => _ErrorView(error: error, onRetry: _retry),
          data: (JourneySnapshot snapshot) => CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(child: _Header(curriculumTitle: curriculumTitle)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: JourneySummaryCard(
                    snapshot: snapshot,
                    onOpenToday: () => _openNode(snapshot.caravanIndex),
                    onOpenReview: () => ref.read(appTabProvider.notifier).select(AppTab.review),
                    onBypassLock: () => unawaited(ref.read(pacingProvider.notifier).bypassTodayLock()),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: CaravanTrailView(
                  snapshot: snapshot,
                  onNodeTap: _openNode,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.curriculumTitle});

  final String? curriculumTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final ReceptionMode mode = ref.watch(receptionModeProvider);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (curriculumTitle != null)
            Text(
              curriculumTitle!,
              style: text.labelLarge?.copyWith(
                color: palette.amberText,
                fontWeight: FontWeight.w600,
              ),
            ),
          Text(
            'مسار الأربعين',
            style: AppTypography.heritageTitle(color: palette.ink, fontSize: 34),
          ),
          const SizedBox(height: 12),
          _ReceptionToggle(
            mode: mode,
            onChanged: (ReceptionMode value) =>
                ref.read(receptionModeProvider.notifier).select(value),
          ),
        ],
      ),
    );
  }
}

class _ReceptionToggle extends StatelessWidget {
  const _ReceptionToggle({required this.mode, required this.onChanged});

  final ReceptionMode mode;
  final ValueChanged<ReceptionMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    Widget option(ReceptionMode value, IconData icon, String label) {
      final bool selected = value == mode;
      return Expanded(
        child: Semantics(
          inMutuallyExclusiveGroup: true,
          checked: selected,
          button: true,
          label: label,
          child: Material(
            color: selected ? palette.ink : Colors.transparent,
            shape: AppShapes.rounded(AppShapes.radiusSmall),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onChanged(value),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(icon, size: 22, color: selected ? palette.paper : palette.inkSoft),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: selected ? palette.paper : palette.inkSoft,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: palette.surfaceMuted,
        shape: AppShapes.rounded(
          AppShapes.radiusMedium,
          side: BorderSide(color: palette.line),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          children: <Widget>[
            option(ReceptionMode.touch, Icons.touch_app_rounded, 'القراءة واللمس'),
            const SizedBox(width: 6),
            option(ReceptionMode.oral, Icons.headphones_rounded, 'السماع والمشافهة'),
          ],
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: 14),
          Text(
            'تجهيز المسار…',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: palette.inkSoft),
          ),
        ],
      ),
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
      ContentIntegrityException(:final List<String> issues) => issues.join('\n'),
      JsonParseException(:final String message) => message,
      _ => error.toString(),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.route_rounded, size: 44, color: palette.inkSoft),
            const SizedBox(height: 12),
            Text(
              'تعذّر تجهيز بيانات الأحاديث',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'لم يُعرض شيء حتى لا يظهر نص ناقص أو غير موثق.',
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
