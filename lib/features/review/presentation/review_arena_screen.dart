// التبويب الثالث: ميدان المراجعة. تفعيل الاسترجاع وتثبيت الأوراد المكتملة
// بثلاثة أقسام: بطاقات غريب الألفاظ، وتحدي ترتيب كلمات المتن المشكولة
// بالسحب والإفلات، واختبارات السيناريوهات التثبيتية.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_tab.dart';
import '../../../core/text/arabic_digits.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/ui/app_shapes.dart';
import '../../../core/ui/smooth_surface.dart';
import '../../../core/ui/wide_action_button.dart';
import '../application/review_controllers.dart';
import '../domain/review_deck.dart';
import 'widgets/flashcard_deck_view.dart';
import 'widgets/scenario_quiz_view.dart';
import 'widgets/word_order_board.dart';

/// شاشة ميدان المراجعة.
class ReviewArenaScreen extends ConsumerWidget {
  const ReviewArenaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ReviewDeck> deck = ref.watch(reviewDeckProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: deck.when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stackTrace) => _ErrorView(
            error: error,
            onRetry: () => ref.invalidate(reviewDeckProvider),
          ),
          data: (ReviewDeck value) => value.isEmpty ? const _EmptyArena() : _Arena(deck: value),
        ),
      ),
    );
  }
}

class _Arena extends ConsumerWidget {
  const _Arena({required this.deck});

  final ReviewDeck deck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final ReviewMode mode = ref.watch(reviewModeProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, end: 4, bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'تثبيت ما تلقّيت',
                style: text.labelLarge?.copyWith(color: palette.amberText, fontWeight: FontWeight.w600),
              ),
              Text(
                'ميدان المراجعة',
                style: AppTypography.heritageTitle(color: palette.ink, fontSize: 34),
              ),
              Text(
                'من ${arabicDigits(deck.hadithCount)} ${deck.hadithCount == 1 ? 'حديث مكتمل' : 'أحاديث مكتملة'} · '
                '${arabicDigits(deck.flashcards.length)} لفظة · ${arabicDigits(deck.orderChallenges.length)} مقطعاً · '
                '${arabicDigits(deck.scenarios.length)} موقفاً',
                style: text.bodySmall?.copyWith(color: palette.inkSoft),
              ),
            ],
          ),
        ),
        _ModeSelector(
          mode: mode,
          onChanged: (ReviewMode value) => ref.read(reviewModeProvider.notifier).select(value),
        ),
        const SizedBox(height: 16),
        // حالة كل قسم محفوظة في متحكمه (Riverpod)، فالتنقل بين الأقسام لا يضيّع
        // موضع المستخدم فيها.
        AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 220),
          child: KeyedSubtree(
            key: ValueKey<ReviewMode>(mode),
            child: switch (mode) {
              ReviewMode.flashcards => FlashcardDeckView(deck: deck),
              ReviewMode.wordOrder => WordOrderBoard(deck: deck),
              ReviewMode.scenarios => ScenarioQuizView(deck: deck),
            },
          ),
        ),
      ],
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.mode, required this.onChanged});

  final ReviewMode mode;
  final ValueChanged<ReviewMode> onChanged;

  static const Map<ReviewMode, IconData> _icons = <ReviewMode, IconData>{
    ReviewMode.flashcards: Icons.style_rounded,
    ReviewMode.wordOrder: Icons.swap_horiz_rounded,
    ReviewMode.scenarios: Icons.forum_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: palette.surfaceMuted,
        shape: AppShapes.rounded(AppShapes.radiusMedium, side: BorderSide(color: palette.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          children: <Widget>[
            for (final ReviewMode option in ReviewMode.values) ...<Widget>[
              if (option.index > 0) const SizedBox(width: 6),
              Expanded(
                child: Semantics(
                  inMutuallyExclusiveGroup: true,
                  checked: option == mode,
                  button: true,
                  label: option.label,
                  child: Material(
                    color: option == mode ? palette.ink : Colors.transparent,
                    shape: AppShapes.rounded(AppShapes.radiusSmall),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => onChanged(option),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: ExcludeSemantics(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Icon(
                                  _icons[option],
                                  size: 20,
                                  color: option == mode ? palette.paper : palette.inkSoft,
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    option.label,
                                    maxLines: 1,
                                    style: AppTypography.ui(
                                      color: option == mode ? palette.paper : palette.inkSoft,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      height: 1.3,
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
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyArena extends ConsumerWidget {
  const _EmptyArena();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: <Widget>[
        Text(
          'ميدان المراجعة',
          style: AppTypography.heritageTitle(color: palette.ink, fontSize: 34),
        ),
        const SizedBox(height: 16),
        SmoothSurface(
          elevated: true,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Icon(Icons.psychology_alt_outlined, size: 48, color: palette.amberText),
              const SizedBox(height: 10),
              Text(
                'يُفتح الميدان بعد أول وِرد',
                textAlign: TextAlign.center,
                style: AppTypography.heritageTitle(color: palette.ink, fontSize: 24),
              ),
              const SizedBox(height: 6),
              Text(
                'المراجعة تثبيت لما تلقّيته: بطاقات الغريب، وترتيب كلمات المتن، ومواقف الإسقاط، كلها من الأوراد التي أتممتها.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: palette.inkSoft, height: 1.8),
              ),
              const SizedBox(height: 16),
              WideActionButton(
                label: 'إلى وِرد اليوم',
                icon: Icons.auto_stories_rounded,
                onPressed: () => ref.read(appTabProvider.notifier).select(AppTab.arbaeen),
              ),
            ],
          ),
        ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.psychology_alt_outlined, size: 44, color: palette.inkSoft),
            const SizedBox(height: 12),
            Text(
              'تعذّر تجهيز مادة المراجعة',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SelectableText(
              error.toString(),
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
