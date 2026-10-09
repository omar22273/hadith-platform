// اختبارات السيناريوهات التثبيتية: مواقف الإسقاط السلوكي من الأوراد المكتملة
// بخياراتها وتغذيتها الراجعة كما في ملفات الأحاديث، بلا درجات ولا توبيخ؛
// ويجوز تغيير الاختيار لقراءة تغذية الخيارات الأخرى.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/text/arabic_digits.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/feedback_colors.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../../../core/content/source_catalog_provider.dart';
import '../../../../core/content/widgets/source_quote_tile.dart';
import '../../../hadith/data/models/models.dart';
import '../../application/review_controllers.dart';
import '../../domain/review_deck.dart';
import '../../domain/review_sessions.dart';

/// عرض المواقف.
class ScenarioQuizView extends ConsumerWidget {
  const ScenarioQuizView({super.key, required this.deck});

  /// مادة المراجعة.
  final ReviewDeck deck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final ScenarioQuizSession session = ref.watch(scenarioQuizProvider);
    final ScenarioQuizController controller = ref.read(scenarioQuizProvider.notifier);
    if (deck.scenarios.isEmpty) {
      return Text(
        'لا مواقف في الأوراد المكتملة بعد.',
        textAlign: TextAlign.center,
        style: text.bodyMedium?.copyWith(color: palette.inkSoft),
      );
    }
    final int index = session.index >= deck.scenarios.length ? 0 : session.index;
    final ScenarioCard card = deck.scenarios[index];
    final Scenario scenario = card.scenario;
    final String? chosenId = session.choices[index];
    ScenarioOption? chosen;
    for (final ScenarioOption option in scenario.options) {
      if (option.id == chosenId) {
        chosen = option;
      }
    }
    final ScenarioOption? aligned = scenario.alignedOption;

    void choose(ScenarioOption option) {
      controller.choose(option.id);
      // اهتزاز لمسي لحظي: خفيف للصواب، وأقوى قليلاً لغيره.
      unawaited(
        option.alignment == OptionAlignment.aligned
            ? HapticFeedback.lightImpact()
            : HapticFeedback.heavyImpact(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'الموقف ${arabicDigits(index + 1)} من ${arabicDigits(deck.scenarios.length)} · ${card.hadithTitle}',
                style: text.labelMedium?.copyWith(color: palette.amberText, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: 'الموقف السابق',
              onPressed: index > 0 ? () => controller.goTo(index - 1) : null,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            IconButton(
              tooltip: 'الموقف التالي',
              onPressed: index + 1 < deck.scenarios.length ? () => controller.goTo(index + 1) : null,
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SmoothSurface(
          elevated: true,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                scenario.situation,
                style: AppTypography.athar(color: palette.ink, fontSize: 19),
              ),
              const SizedBox(height: 10),
              Text(
                scenario.question,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final ScenarioOption option in scenario.options) ...<Widget>[
          _OptionTile(
            option: option,
            chosen: chosen,
            onTap: () => choose(option),
          ),
          const SizedBox(height: 8),
        ],
        if (chosen != null) ...<Widget>[
          const SizedBox(height: 6),
          _FeedbackCard(scenario: scenario, chosen: chosen, aligned: aligned),
        ],
      ],
    );
  }
}

/// بطاقة التغذية الراجعة: تعليق الخيار المختار، ثم سبب صحة الخيار النبوي.
class _FeedbackCard extends ConsumerWidget {
  const _FeedbackCard({required this.scenario, required this.chosen, required this.aligned});

  final Scenario scenario;
  final ScenarioOption chosen;
  final ScenarioOption? aligned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final FeedbackColors feedback = FeedbackColors.of(context);
    final bool right = chosen.alignment == OptionAlignment.aligned;
    final _Tone tone = _toneOf(chosen.alignment, palette, feedback);
    final sources = ref.watch(sourceCatalogProvider).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SmoothSurface(
          color: tone.background,
          borderColor: tone.border,
          borderWidth: 1.6,
          radius: AppShapes.radiusMedium,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    right ? Icons.check_circle_rounded : (chosen.alignment == OptionAlignment.partial ? Icons.info_rounded : Icons.cancel_rounded),
                    color: tone.foreground,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    right ? 'الخيار النبوي' : (chosen.alignment == OptionAlignment.partial ? 'قريب ويحتاج تكميلاً' : 'ليس هذا مقصد الحديث'),
                    style: text.titleSmall?.copyWith(color: tone.foreground, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                chosen.feedback,
                style: text.bodyMedium?.copyWith(color: palette.ink, height: 1.8),
              ),
            ],
          ),
        ),
        if (!right && aligned != null) ...<Widget>[
          const SizedBox(height: 10),
          SmoothSurface(
            color: feedback.rightFill,
            borderColor: feedback.rightBorder,
            borderWidth: 1.6,
            radius: AppShapes.radiusMedium,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'لماذا هذا هو الخيار النبوي؟',
                  style: text.titleSmall?.copyWith(color: feedback.rightText, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  aligned!.text,
                  style: text.bodyMedium?.copyWith(color: palette.ink, fontWeight: FontWeight.w700, height: 1.7),
                ),
                const SizedBox(height: 6),
                Text(
                  aligned!.feedback,
                  style: text.bodyMedium?.copyWith(color: palette.ink, height: 1.8),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        SmoothSurface(
          color: palette.surface,
          borderColor: palette.line,
          radius: AppShapes.radiusMedium,
          padding: const EdgeInsets.all(14),
          child: Text(
            scenario.takeaway,
            style: AppTypography.athar(color: palette.emeraldText, fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        for (final basis in scenario.basis) ...<Widget>[
          const SizedBox(height: 8),
          SourceQuoteTile(reference: basis, source: sources?.byId(basis.sourceId)),
        ],
      ],
    );
  }
}

class _Tone {
  const _Tone(this.background, this.border, this.foreground);

  final Color background;
  final Color border;
  final Color foreground;
}

_Tone _toneOf(OptionAlignment alignment, AppPalette palette, FeedbackColors feedback) {
  switch (alignment) {
    case OptionAlignment.aligned:
      return _Tone(feedback.rightFill, feedback.rightBorder, feedback.rightText);
    case OptionAlignment.partial:
      return _Tone(palette.amberSoft, palette.amber, palette.amberText);
    case OptionAlignment.misaligned:
      return _Tone(feedback.wrongFill, feedback.wrongBorder, feedback.wrongText);
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.option, required this.chosen, required this.onTap});

  final ScenarioOption option;
  final ScenarioOption? chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final FeedbackColors feedback = FeedbackColors.of(context);
    final bool selected = chosen?.id == option.id;
    // بعد الاختيار: يتلوّن الخيار المختار بحسب صحته، ويُظهَر الخيار النبوي بالأخضر.
    final bool revealRight = chosen != null && !selected && option.alignment == OptionAlignment.aligned;
    final _Tone? tone = selected
        ? _toneOf(option.alignment, palette, feedback)
        : (revealRight ? _toneOf(OptionAlignment.aligned, palette, feedback) : null);
    final IconData icon = tone == null
        ? Icons.radio_button_unchecked_rounded
        : (option.alignment == OptionAlignment.aligned
            ? Icons.check_circle_rounded
            : (selected && option.alignment == OptionAlignment.misaligned
                ? Icons.cancel_rounded
                : Icons.info_rounded));
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 220),
        child: SmoothSurface(
          key: ValueKey<String>('${option.id}-${tone?.border.toARGB32() ?? 0}'),
          onTap: onTap,
          color: tone?.background ?? palette.surface,
          borderColor: tone?.border ?? palette.line,
          borderWidth: tone == null ? 1 : 2,
          radius: AppShapes.radiusMedium,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Icon(icon, color: tone?.foreground ?? palette.locked),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  option.text,
                  style: text.bodyMedium?.copyWith(color: palette.ink, height: 1.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
