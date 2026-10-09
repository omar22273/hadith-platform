// اختبارات السيناريوهات التثبيتية: مواقف الإسقاط السلوكي من الأوراد المكتملة
// بخياراتها وتغذيتها الراجعة كما في ملفات الأحاديث، بلا درجات ولا توبيخ؛
// ويجوز تغيير الاختيار لقراءة تغذية الخيارات الأخرى.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/text/arabic_digits.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_surface.dart';
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
            selected: option.id == chosenId,
            onTap: () => controller.choose(option.id),
          ),
          const SizedBox(height: 8),
        ],
        if (chosen != null) ...<Widget>[
          const SizedBox(height: 6),
          SmoothSurface(
            color: _toneOf(chosen.alignment, palette).background,
            borderColor: _toneOf(chosen.alignment, palette).border,
            radius: AppShapes.radiusMedium,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  chosen.feedback,
                  style: text.bodyMedium?.copyWith(color: palette.ink, height: 1.8),
                ),
                const SizedBox(height: 8),
                Text(
                  scenario.takeaway,
                  style: AppTypography.athar(color: palette.emeraldText, fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Tone {
  const _Tone(this.background, this.border);

  final Color background;
  final Color border;
}

_Tone _toneOf(OptionAlignment alignment, AppPalette palette) {
  switch (alignment) {
    case OptionAlignment.aligned:
      return _Tone(palette.emeraldSoft, palette.emerald.withValues(alpha: 0.45));
    case OptionAlignment.partial:
      return _Tone(palette.amberSoft, palette.amber.withValues(alpha: 0.45));
    case OptionAlignment.misaligned:
      return _Tone(palette.surfaceMuted, palette.line);
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
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: SmoothSurface(
        onTap: onTap,
        color: selected ? palette.amberSoft : palette.surface,
        borderColor: selected ? palette.amber : palette.line,
        borderWidth: selected ? 1.6 : 1,
        radius: AppShapes.radiusMedium,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              color: selected ? palette.amberText : palette.locked,
            ),
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
    );
  }
}
