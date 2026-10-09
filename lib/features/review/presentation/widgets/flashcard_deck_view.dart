// بطاقات غريب الألفاظ التفاعلية: وجه البطاقة اللفظة كما ضُبطت في المتن،
// وظهرها البيان من كتب الغريب والشروح بإحالته. تُقلب باللمس بحركة ثلاثية
// الأبعاد، وما يحتاج إعادة يعود إلى آخر الطابور بلا عقاب.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/text/arabic_digits.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../application/review_controllers.dart';
import '../../domain/review_deck.dart';
import '../../domain/review_sessions.dart';

/// منصة البطاقات.
class FlashcardDeckView extends ConsumerWidget {
  const FlashcardDeckView({super.key, required this.deck});

  /// مادة المراجعة.
  final ReviewDeck deck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final FlashcardSession session = ref.watch(flashcardSessionProvider);
    final FlashcardSessionController controller = ref.read(flashcardSessionProvider.notifier);
    if (deck.flashcards.isEmpty) {
      return const _Note(text: 'لا ألفاظ غريبة في الأوراد المكتملة بعد.');
    }
    final int? current = session.current;
    if (current == null || current >= deck.flashcards.length) {
      return SmoothSurface(
        color: palette.emeraldSoft,
        borderColor: palette.emerald.withValues(alpha: 0.4),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Icon(Icons.verified_rounded, size: 40, color: palette.emeraldText),
            const SizedBox(height: 8),
            Text(
              'أتممتَ البطاقات كلها',
              textAlign: TextAlign.center,
              style: AppTypography.heritageTitle(color: palette.ink, fontSize: 24),
            ),
            Text(
              'عرفتَ ${arabicDigits(session.known)} · أعدتَ ${arabicDigits(session.repeats)} مرة',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: palette.inkSoft),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: controller.restart,
              icon: const Icon(Icons.replay_rounded),
              label: const Text('ابدأ الجولة من جديد'),
            ),
          ],
        ),
      );
    }
    final GharibCard card = deck.flashcards[current];
    final int done = deck.flashcards.length - session.queue.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              'البطاقة ${arabicDigits(done + 1)} من ${arabicDigits(deck.flashcards.length)}',
              style: text.labelMedium?.copyWith(color: palette.inkSoft),
            ),
            const Spacer(),
            Text(
              'عرفتَ ${arabicDigits(session.known)}',
              style: text.labelMedium?.copyWith(color: palette.emeraldText, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: deck.flashcards.isEmpty ? 0 : done / deck.flashcards.length,
            minHeight: 5,
            color: palette.emerald,
            backgroundColor: palette.line,
          ),
        ),
        const SizedBox(height: 14),
        _FlipCard(card: card, flipped: session.flipped, onTap: controller.flip),
        const SizedBox(height: 14),
        if (session.flipped)
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: controller.repeatLater,
                  icon: const Icon(Icons.update_rounded),
                  label: const Text('أعدها لاحقاً'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: controller.markKnown,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('عرفتُها'),
                ),
              ),
            ],
          )
        else
          FilledButton.icon(
            onPressed: controller.flip,
            icon: const Icon(Icons.flip_rounded),
            label: const Text('اقلب البطاقة'),
          ),
      ],
    );
  }
}

class _FlipCard extends StatelessWidget {
  const _FlipCard({required this.card, required this.flipped, required this.onTap});

  final GharibCard card;
  final bool flipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      label: flipped
          ? 'بيان «${card.headword}»: ${card.meaning}. ${card.citation}'
          : 'اللفظة «${card.headword}» من حديث ${card.hadithTitle}. المس لقلب البطاقة',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: flipped ? 1 : 0),
            duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 420),
            curve: Curves.easeInOutCubic,
            builder: (BuildContext context, double value, Widget? child) {
              final double angle = value * math.pi;
              final bool showBack = angle > math.pi / 2;
              final Matrix4 transform = Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(angle);
              return Transform(
                alignment: Alignment.center,
                transform: transform,
                child: showBack
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(math.pi),
                        child: _CardFace(card: card, back: true),
                      )
                    : _CardFace(card: card, back: false),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.card, required this.back});

  final GharibCard card;
  final bool back;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 240),
      child: SmoothSurface(
        elevated: true,
        radius: AppShapes.radiusLarge,
        gradient: back
            ? null
            : LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: <Color>[palette.amberSoft, palette.surface],
              ),
        borderColor: back ? palette.emerald.withValues(alpha: 0.45) : palette.amber.withValues(alpha: 0.45),
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: back
              ? <Widget>[
                  Text(
                    card.headword,
                    textAlign: TextAlign.center,
                    style: AppTypography.matnOf(context, color: palette.amberText, fontSize: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    card.meaning,
                    textAlign: TextAlign.center,
                    style: AppTypography.athar(color: palette.ink, fontSize: 20),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    card.citation,
                    textAlign: TextAlign.center,
                    style: text.labelSmall?.copyWith(color: palette.inkSoft),
                  ),
                ]
              : <Widget>[
                  Text(
                    'من حديث: ${card.hadithTitle}',
                    textAlign: TextAlign.center,
                    style: text.labelMedium?.copyWith(color: palette.inkSoft),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    card.headword,
                    textAlign: TextAlign.center,
                    style: AppTypography.matnOf(context, color: palette.ink, fontSize: 34, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'ما معنى هذه اللفظة؟ المس البطاقة لترى البيان.',
                    textAlign: TextAlign.center,
                    style: text.bodySmall?.copyWith(color: palette.inkSoft),
                  ),
                ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: palette.inkSoft),
      ),
    );
  }
}
