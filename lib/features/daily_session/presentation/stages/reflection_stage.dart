// المرحلة الرابعة: الإسقاط السلوكي. مأزق واقعي بخيارات دقيقة، وتغذية راجعة
// لطيفة بلا توبيخ، ثم العلة التربوية بمستندها والأثر السلوكي.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../../hadith/data/models/models.dart';
import '../../../hadith/domain/hadith_bundle.dart';
import '../../../hadith/presentation/widgets/source_quote_tile.dart';
import '../../application/session_controller.dart';
import '../../application/session_state.dart';

/// مرحلة الإسقاط.
class ReflectionStage extends ConsumerWidget {
  const ReflectionStage({super.key, required this.bundle});

  /// الحديث وفهارسه.
  final HadithBundle bundle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final Reflection reflection = bundle.hadith.reflection;
    final Scenario scenario = reflection.scenario;
    final String? chosen = ref.watch(
      sessionControllerProvider(bundle.hadith.id).select((SessionState s) => s.chosenOptionId),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        SmoothSurface(
          elevated: true,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionEyebrow('مأزق الموقف الواقعي', icon: Icons.forum_rounded),
              const SizedBox(height: 8),
              Text(
                scenario.situation,
                style: AppTypography.ui(color: palette.ink, fontSize: 16.5, height: 1.9),
              ),
              const SizedBox(height: 12),
              Text(
                scenario.question,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final ScenarioOption option in scenario.options) ...<Widget>[
          _OptionTile(
            option: option,
            selected: option.id == chosen,
            onTap: () => ref.read(sessionControllerProvider(bundle.hadith.id).notifier).chooseOption(option.id),
          ),
          const SizedBox(height: 10),
        ],
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: chosen == null
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: 8),
                    SmoothSurface(
                      color: palette.surfaceMuted,
                      borderColor: palette.line,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const SectionEyebrow('العلّة التربوية', icon: Icons.lightbulb_outline_rounded),
                          const SizedBox(height: 8),
                          Text(
                            scenario.takeaway,
                            style: AppTypography.ui(color: palette.ink, fontSize: 16, height: 1.9),
                          ),
                          const SizedBox(height: 10),
                          for (final SourceRef ref in scenario.basis) ...<Widget>[
                            SourceQuoteTile(reference: ref, source: bundle.sources.byId(ref.sourceId)),
                            const SizedBox(height: 6),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const SectionEyebrow('الأثر السلوكي', icon: Icons.self_improvement_rounded),
                    const SizedBox(height: 8),
                    for (final BehavioralImpact impact in reflection.impacts) ...<Widget>[
                      SmoothSurface(
                        radius: AppShapes.radiusMedium,
                        borderColor: palette.line,
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text(impact.text, style: text.bodyLarge?.copyWith(height: 1.85)),
                            const SizedBox(height: 8),
                            for (final SourceRef ref in impact.sources) ...<Widget>[
                              SourceQuoteTile(reference: ref, source: bundle.sources.byId(ref.sourceId)),
                              const SizedBox(height: 6),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.option, required this.selected, required this.onTap});

  final ScenarioOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final (Color tone, Color soft, String verdict, IconData icon) = switch (option.alignment) {
      OptionAlignment.aligned => (palette.emeraldText, palette.emeraldSoft, 'موافق لمقصد الحديث', Icons.verified_outlined),
      OptionAlignment.partial => (palette.amberText, palette.amberSoft, 'فيه خير ويحتاج تكميلاً', Icons.spa_rounded),
      OptionAlignment.misaligned => (palette.inkSoft, palette.surfaceMuted, 'بعيد عن مقصد الحديث', Icons.route_rounded),
    };
    return SmoothSurface(
      color: selected ? soft : palette.surface,
      borderColor: selected ? tone : palette.line,
      borderWidth: selected ? 1.6 : 1,
      radius: AppShapes.radiusMedium,
      elevated: !selected,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      semanticLabel: selected ? '${option.text}. $verdict. ${option.feedback}' : option.text,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(option.text, style: text.bodyLarge?.copyWith(height: 1.75, fontWeight: FontWeight.w500)),
          if (selected) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Icon(icon, size: 18, color: tone),
                const SizedBox(width: 6),
                Text(verdict, style: text.labelLarge?.copyWith(color: tone, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 4),
            Text(option.feedback, style: text.bodyMedium?.copyWith(color: palette.ink, height: 1.8)),
          ],
        ],
      ),
    );
  }
}
