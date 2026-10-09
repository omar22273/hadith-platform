// البطاقة السفلية لعقدة الوِرد: رقم الحديث وعنوانه ومَعلَم خطوته، وحالته،
// وزرّا البدء العريضان: «بدء وِرد التثبيت اللمسي» و«بدء مجلس السماع الشفاهي».

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/preferences/reception_mode.dart';
import '../../../../core/text/arabic_digits.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../../../core/ui/wide_action_button.dart';
import '../../../hadith/application/hadith_providers.dart';
import '../../application/journey_controller.dart';
import '../../application/pacing_notifier.dart';
import '../../domain/journey_snapshot.dart';
import 'journey_summary_card.dart';
import 'wird_labels.dart';

/// الإجراء المختار من البطاقة.
sealed class WirdAction {
  const WirdAction();
}

/// بدء وِرد التثبيت اللمسي.
final class StartTouchSession extends WirdAction {
  const StartTouchSession(this.hadithId);

  /// الحديث.
  final String hadithId;
}

/// بدء مجلس السماع.
final class StartOralSession extends WirdAction {
  const StartOralSession(this.hadithId);

  /// الحديث.
  final String hadithId;
}

/// مراجعة وِرد مكتمل دون احتسابه وِرداً جديداً.
final class ReviewSession extends WirdAction {
  const ReviewSession(this.hadithId);

  /// الحديث.
  final String hadithId;
}

/// الانتقال إلى ميدان المراجعة.
final class OpenReviewArena extends WirdAction {
  const OpenReviewArena();
}

/// البطاقة.
class WirdSheet extends ConsumerWidget {
  const WirdSheet({super.key, required this.nodeIndex});

  /// موضع العقدة.
  final int nodeIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final JourneySnapshot? snapshot = ref.watch(journeyControllerProvider).value;
    final ReceptionMode preferred = ref.watch(receptionModeProvider);
    if (snapshot == null || nodeIndex >= snapshot.nodes.length) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final WirdNode node = snapshot.nodes[nodeIndex];
    final PathSegment segment = snapshot.segments[node.segmentIndex];
    final String? hadithId = node.item?.hadithId;
    final String? milestone = hadithId == null ? null : ref.watch(hadithProvider(hadithId)).value?.milestone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '${wirdNumberLabel(node)} من ${arabicDigits(snapshot.plannedCount)} · ${segment.title}',
          style: text.labelMedium?.copyWith(
            color: palette.amberText,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          wirdTitle(node),
          style: AppTypography.heritageTitle(color: palette.ink, fontSize: 32),
        ),
        if (milestone != null)
          Row(
            children: <Widget>[
              Icon(Icons.flag_outlined, size: 18, color: palette.inkSoft),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  milestone,
                  style: text.bodyMedium?.copyWith(color: palette.inkSoft),
                ),
              ),
            ],
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: <Widget>[
            _StatusChip(node: node),
            SoftChip(label: segment.rangeLabel, icon: Icons.format_list_numbered_rtl_rounded),
          ],
        ),
        const SizedBox(height: 18),
        ..._body(context, ref, snapshot, node, preferred),
      ],
    );
  }

  List<Widget> _body(
    BuildContext context,
    WidgetRef ref,
    JourneySnapshot snapshot,
    WirdNode node,
    ReceptionMode preferred,
  ) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final String? hadithId = node.item?.hadithId;
    switch (node.status) {
      case WirdNodeStatus.today:
        final WideActionButton touch = WideActionButton(
          label: 'بدء وِرد التثبيت اللمسي',
          subtitle: 'السياق، والمتن والغريب، والترصيع والتلاشي، والإسقاط السلوكي',
          icon: Icons.touch_app_rounded,
          tone: preferred == ReceptionMode.touch ? WideActionTone.primary : WideActionTone.secondary,
          onPressed: () => Navigator.of(context).pop(StartTouchSession(hadithId!)),
        );
        final WideActionButton oral = WideActionButton(
          label: 'بدء مجلس السماع الشفاهي',
          subtitle: 'سرد مسموع، وتلقين بالترديد، وموقف يُعرض بالصوت',
          icon: Icons.headphones_rounded,
          tone: preferred == ReceptionMode.oral ? WideActionTone.primary : WideActionTone.secondary,
          giant: preferred == ReceptionMode.oral,
          onPressed: () => Navigator.of(context).pop(StartOralSession(hadithId!)),
        );
        final List<WideActionButton> ordered =
            preferred == ReceptionMode.oral ? <WideActionButton>[oral, touch] : <WideActionButton>[touch, oral];
        return <Widget>[
          ordered[0],
          const SizedBox(height: 10),
          ordered[1],
        ];
      case WirdNodeStatus.afterDawn:
        return <Widget>[
          SmoothSurface(
            color: palette.surfaceMuted,
            borderColor: palette.line,
            radius: AppShapes.radiusMedium,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'بلغتَ حصة اليوم (${hadithCountLabel(snapshot.pacing.dailyQuota)}). يُفتح هذا الوِرد عند الفجر؛ وِرد يرسخ خير من أوراد تتزاحم.',
                  style: text.bodyMedium?.copyWith(color: palette.ink, height: 1.8),
                ),
                if (snapshot.nextUnlockAt != null)
                  FajrCountdown(target: snapshot.nextUnlockAt!, usesFallback: snapshot.unlockUsesFallback),
              ],
            ),
          ),
          const SizedBox(height: 12),
          WideActionButton(
            label: 'إلى ميدان المراجعة',
            subtitle: 'ثبّت ما حفظت حتى يُفتح الوِرد التالي',
            icon: Icons.psychology_alt_rounded,
            onPressed: () => Navigator.of(context).pop(const OpenReviewArena()),
          ),
          TextButton.icon(
            onPressed: () {
              unawaited(ref.read(pacingProvider.notifier).bypassTodayLock());
              Navigator.of(context).maybePop();
            },
            icon: const Icon(Icons.science_outlined, size: 18),
            label: const Text('تخطي القفل يدوياً (لأغراض التجربة)'),
          ),
        ];
      case WirdNodeStatus.completed:
        return <Widget>[
          WideActionButton(
            label: 'مراجعة الوِرد',
            subtitle: 'تُعرض المراحل الأربع كما هي، ولا تُحسب وِرداً جديداً',
            icon: Icons.replay_rounded,
            tone: WideActionTone.secondary,
            onPressed: () => Navigator.of(context).pop(ReviewSession(hadithId!)),
          ),
          const SizedBox(height: 10),
          WideActionButton(
            label: 'تثبيت في ميدان المراجعة',
            icon: Icons.psychology_alt_rounded,
            tone: WideActionTone.quiet,
            onPressed: () => Navigator.of(context).pop(const OpenReviewArena()),
          ),
        ];
      case WirdNodeStatus.upcoming:
        return <Widget>[
          Text(
            'يُفتح هذا الوِرد بعد إتمام ما قبله من الأوراد، بالوتيرة التي اخترتها.',
            style: text.bodyMedium?.copyWith(color: palette.inkSoft, height: 1.8),
          ),
        ];
      case WirdNodeStatus.inPreparation:
        return <Widget>[
          Text(
            'هذا الحديث قيد الإعداد والمراجعة العلمية، ولا يُعرض متنه ولا عنوانه حتى يكتمل توثيقه من مصادره.',
            style: text.bodyMedium?.copyWith(color: palette.inkSoft, height: 1.8),
          ),
        ];
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.node});

  final WirdNode node;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    switch (node.status) {
      case WirdNodeStatus.completed:
        return SoftChip(
          label: wirdStatusLine(node),
          icon: Icons.verified_outlined,
          background: palette.emeraldSoft,
          foreground: palette.emeraldText,
        );
      case WirdNodeStatus.today:
      case WirdNodeStatus.afterDawn:
        return SoftChip(
          label: wirdStatusLine(node),
          icon: node.status == WirdNodeStatus.today ? Icons.wb_twilight_rounded : Icons.lock_clock,
          background: palette.amberSoft,
          foreground: palette.amberText,
        );
      case WirdNodeStatus.upcoming:
      case WirdNodeStatus.inPreparation:
        return SoftChip(
          label: wirdStatusLine(node),
          icon: Icons.lock_outline_rounded,
          background: palette.lockedSoft,
          foreground: palette.locked,
        );
    }
  }
}
