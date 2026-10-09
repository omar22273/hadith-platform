// شاشة الختام: قفل الفجر الزمني بحسب حصة اليوم، وحكمة مختارة عشوائياً من
// بنك العبارات التراثية الموثقة، ولمحة تشويق لحديث الغد، وزر مباشر إلى
// ميدان المراجعة للتثبيت.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_tab.dart';
import '../../../../core/storage/install_salt.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../../hadith/application/hadith_providers.dart';
import '../../../hadith/data/models/models.dart';
import '../../../hadith/domain/hadith_bundle.dart';
import '../../../journey/application/journey_controller.dart';
import '../../../journey/domain/journey_snapshot.dart';
import '../../../journey/presentation/widgets/journey_summary_card.dart';
import '../../../journey/presentation/widgets/wird_labels.dart';
import '../../domain/wisdom_picker.dart';

/// الختام.
class ClosingView extends ConsumerWidget {
  const ClosingView({
    super.key,
    required this.hadithId,
    required this.countedTowardJourney,
    required this.onBack,
  });

  /// الحديث المكتمل.
  final String hadithId;

  /// هل كان وِرد اليوم (لا مراجعة).
  final bool countedTowardJourney;

  /// العودة إلى المسار.
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final JourneySnapshot? snapshot = ref.watch(journeyControllerProvider).value;
    final CurriculumManifest? curriculum = ref.watch(curriculumProvider).value;
    final CurriculumItem? next = countedTowardJourney ? snapshot?.nextItem : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: <Widget>[
        Icon(
          countedTowardJourney ? Icons.wb_twilight_rounded : Icons.replay_rounded,
          size: 48,
          color: palette.amberText,
        ),
        const SizedBox(height: 10),
        Text(
          countedTowardJourney
              ? (curriculum?.dailyCap.completionMessage ?? '')
              : 'انتهت مراجعة الوِرد. المراجعة لا تُحسب وِرداً جديداً.',
          textAlign: TextAlign.center,
          style: AppTypography.heritageTitle(color: palette.ink, fontSize: 25),
        ),
        const SizedBox(height: 18),
        if (countedTowardJourney && snapshot != null) ...<Widget>[
          if (snapshot.todayKind == TodayKind.capReached)
            _FajrLockCard(snapshot: snapshot)
          else if (snapshot.todayKind == TodayKind.available)
            _RemainingCard(snapshot: snapshot),
          const SizedBox(height: 14),
        ],
        _WisdomCard(hadithId: hadithId),
        const SizedBox(height: 14),
        if (countedTowardJourney) ...<Widget>[
          if (next != null)
            _TeaserCard(item: next)
          else if (snapshot?.todayKind == TodayKind.curriculumFinished)
            SmoothSurface(
              color: palette.emeraldSoft,
              radius: AppShapes.radiusLarge,
              padding: const EdgeInsets.all(16),
              child: Text(
                'أتممتَ الأوراد المُعدّة في هذا الإصدار. تُضاف الأحاديث التالية مع اكتمال توثيقها ومراجعتها.',
                style: text.bodyMedium?.copyWith(color: palette.ink, height: 1.8),
              ),
            ),
          const SizedBox(height: 20),
        ],
        FilledButton.icon(
          onPressed: () => openAppTab(context, ref, AppTab.review),
          icon: const Icon(Icons.psychology_alt_rounded),
          label: const Text('إلى ميدان المراجعة'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.route_rounded),
          label: const Text('العودة إلى مسار الأربعين'),
        ),
      ],
    );
  }
}

class _FajrLockCard extends StatelessWidget {
  const _FajrLockCard({required this.snapshot});

  final JourneySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final DateTime? unlockAt = snapshot.nextUnlockAt;
    return SmoothSurface(
      color: palette.surfaceMuted,
      borderColor: palette.line,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.lock_clock, color: palette.inkSoft),
              const SizedBox(width: 8),
              Text(
                'قفل الفجر',
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'أُغلق فتح الأحاديث الجديدة حتى الفجر؛ حصتك اليوم ${hadithCountLabel(snapshot.pacing.dailyQuota)}، والوِرد الذي يرسخ خير من أوراد تتزاحم.',
            style: text.bodyMedium?.copyWith(color: palette.ink, height: 1.8),
          ),
          if (unlockAt != null) FajrCountdown(target: unlockAt, usesFallback: snapshot.unlockUsesFallback),
        ],
      ),
    );
  }
}

class _RemainingCard extends StatelessWidget {
  const _RemainingCard({required this.snapshot});

  final JourneySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final int remaining = snapshot.pacing.remainingToday;
    return SmoothSurface(
      color: palette.amberSoft,
      borderColor: palette.amber.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          Icon(Icons.wb_twilight_rounded, color: palette.amberText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              remaining > 0
                  ? 'بقي من حصة اليوم ${hadithCountLabel(remaining)}؛ تجده في مسار الأربعين.'
                  : 'قفل الفجر متخطّى لأغراض التجربة؛ الوِرد التالي متاح في مسار الأربعين.',
              style: text.bodyMedium?.copyWith(color: palette.ink, height: 1.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _WisdomCard extends ConsumerWidget {
  const _WisdomCard({required this.hadithId});

  final String hadithId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final WisdomCatalog? catalog = ref.watch(wisdomCatalogProvider).value;
    final SourceCatalog? sources = ref.watch(sourceCatalogProvider).value;
    if (catalog == null || catalog.entries.isEmpty) {
      return const SizedBox.shrink();
    }
    final WisdomEntry entry = pickWisdom(
      catalog,
      day: ref.read(clockProvider)(),
      hadithId: hadithId,
      installSalt: ref.watch(installSaltProvider),
    );
    return SmoothSurface(
      gradient: LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: <Color>[palette.amberSoft, palette.surface],
      ),
      borderColor: palette.amber.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionEyebrow('من بنك العبارات التراثية', icon: Icons.format_quote_rounded),
          const SizedBox(height: 10),
          Text(
            '«${entry.text}»',
            style: AppTypography.athar(color: palette.ink, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '— ${entry.speaker}',
            style: text.titleSmall?.copyWith(color: palette.amberText, fontWeight: FontWeight.w700),
          ),
          Text(
            'نقله ${formatCitation(sources?.byId(entry.source.sourceId), entry.source)}',
            style: text.labelSmall?.copyWith(color: palette.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _TeaserCard extends ConsumerWidget {
  const _TeaserCard({required this.item});

  final CurriculumItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final String? teaser = ref.watch(hadithProvider(item.hadithId)).value?.teaser.text;
    return SmoothSurface(
      color: palette.ink,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'لمحة من وِرد الغد',
            style: text.labelLarge?.copyWith(color: palette.amberSoft, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            teaser ?? '…',
            style: AppTypography.ui(color: palette.paper, fontSize: 18, height: 1.85, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
