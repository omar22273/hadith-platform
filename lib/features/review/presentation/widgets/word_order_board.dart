// تحدي ترتيب كلمات المتن المشكولة بالسحب والإفلات: تُسحب الكلمة من البلاطات
// المبعثرة إلى الموضع التالي في السطر، فتثبت إن طابقته رسماً وضبطاً، وإلا
// اهتزت بلطف وعادت. ويغني اللمس عن السحب لمن يشق عليه السحب.
// الكلمات معروضة بضبطها كما في ملف الحديث حرفاً بحرف.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/text/arabic_digits.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../../hadith/domain/practice_engine.dart';
import '../../application/review_controllers.dart';
import '../../domain/review_deck.dart';
import '../../domain/review_sessions.dart';

/// لوحة الترتيب.
class WordOrderBoard extends ConsumerWidget {
  const WordOrderBoard({super.key, required this.deck});

  /// مادة المراجعة.
  final ReviewDeck deck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final OrderChallengeState state = ref.watch(orderChallengeProvider);
    final OrderChallengeController controller = ref.read(orderChallengeProvider.notifier);
    final OrderBoard? board = state.board;
    if (board == null || deck.orderChallenges.isEmpty) {
      return Text(
        'لا مقاطع للترتيب في الأوراد المكتملة بعد.',
        textAlign: TextAlign.center,
        style: text.bodyMedium?.copyWith(color: palette.inkSoft),
      );
    }
    final OrderChallenge challenge = deck.orderChallenges[state.index];

    void attempt(int tileId) {
      final PlacementOutcome outcome = controller.place(tileId);
      switch (outcome) {
        case PlacementOutcome.mismatch:
          HapticFeedback.selectionClick();
        case PlacementOutcome.completed:
          HapticFeedback.mediumImpact();
        case PlacementOutcome.placed:
        case PlacementOutcome.ignored:
          break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ChallengePicker(deck: deck, selected: state.index, onSelect: controller.select),
        const SizedBox(height: 12),
        Text(
          '${challenge.hadithTitle} · ${challenge.label}',
          style: text.labelLarge?.copyWith(color: palette.amberText, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'اسحب كل كلمة إلى الموضع التالي في السطر، أو المسها. الكلمة غير المطابقة تعود بلطف.',
          style: text.bodySmall?.copyWith(color: palette.inkSoft),
        ),
        const SizedBox(height: 12),
        SmoothSurface(
          color: board.completed ? palette.emeraldSoft : palette.surface,
          borderColor: board.completed ? palette.emerald.withValues(alpha: 0.5) : palette.line,
          padding: const EdgeInsets.all(14),
          child: _Line(board: board, onDrop: attempt),
        ),
        const SizedBox(height: 14),
        if (board.completed)
          _CompletedBanner(
            mistakes: board.mistakes,
            hasNext: state.index + 1 < deck.orderChallenges.length,
            onNext: () => controller.select(state.index + 1),
            onAgain: controller.reset,
          )
        else ...<Widget>[
          Text(
            'الكلمات المبعثرة',
            style: text.labelMedium?.copyWith(color: palette.inkSoft),
          ),
          const SizedBox(height: 8),
          _Pool(board: board, onTapTile: attempt),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            children: <Widget>[
              TextButton.icon(
                onPressed: board.placedTiles.isEmpty ? null : controller.undo,
                icon: const Icon(Icons.undo_rounded),
                label: const Text('تراجع'),
              ),
              TextButton.icon(
                onPressed: controller.reset,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('ابدأ المقطع من جديد'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ChallengePicker extends StatelessWidget {
  const _ChallengePicker({required this.deck, required this.selected, required this.onSelect});

  final ReviewDeck deck;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: deck.orderChallenges.length,
        separatorBuilder: (BuildContext context, int index) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final bool active = index == selected;
          return ChoiceChip(
            selected: active,
            onSelected: (bool value) => onSelect(index),
            label: Text('المقطع ${arabicDigits(index + 1)}'),
            selectedColor: palette.amberSoft,
            backgroundColor: palette.surface,
            side: BorderSide(color: active ? palette.amber : palette.line),
            shape: AppShapes.rounded(AppShapes.radiusSmall),
            showCheckmark: false,
            labelStyle: AppTypography.ui(
              color: active ? palette.amberText : palette.inkSoft,
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            ),
          );
        },
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.board, required this.onDrop});

  final OrderBoard board;
  final ValueChanged<int> onDrop;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextStyle word = AppTypography.matnOf(context, color: palette.ink, fontSize: 22);
    final List<Widget> children = <Widget>[];
    for (int position = 0; position < board.drill.tokens.length; position++) {
      if (position < board.placedTiles.length) {
        final PracticeTile tile = board.drill.tiles[board.placedTiles[position]];
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(tile.token.core, style: word.copyWith(color: palette.emeraldText)),
          ),
        );
      } else if (position == board.nextPosition) {
        children.add(
          DragTarget<int>(
            onWillAcceptWithDetails: (DragTargetDetails<int> details) => !board.isUsed(details.data),
            onAcceptWithDetails: (DragTargetDetails<int> details) => onDrop(details.data),
            builder: (BuildContext context, List<int?> candidates, List<dynamic> rejected) {
              final bool hovering = candidates.isNotEmpty;
              return Semantics(
                label: 'الموضع ${arabicDigits(position + 1)}: أفلت الكلمة هنا',
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  constraints: const BoxConstraints(minWidth: 64, minHeight: 46),
                  margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  decoration: ShapeDecoration(
                    color: hovering ? palette.amberSoft : palette.surfaceMuted,
                    shape: AppShapes.rounded(
                      AppShapes.radiusSmall,
                      side: BorderSide(color: hovering ? palette.amber : palette.amber.withValues(alpha: 0.5), width: 1.4),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    arabicDigits(position + 1),
                    style: AppTypography.ui(color: palette.amberText, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              );
            },
          ),
        );
      } else {
        children.add(
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 20),
            decoration: BoxDecoration(
              color: palette.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }
    }
    return Wrap(
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 4,
      children: children,
    );
  }
}

class _Pool extends StatelessWidget {
  const _Pool({required this.board, required this.onTapTile});

  final OrderBoard board;
  final ValueChanged<int> onTapTile;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final PracticeTile tile in board.drill.tiles)
          if (!board.isUsed(tile.id))
            _ShakingTile(
              key: ValueKey<String>('tile-${tile.id}'),
              shakeTick: board.lastMismatchTile == tile.id ? board.mismatchTick : 0,
              child: _DraggableTile(tile: tile, onTap: () => onTapTile(tile.id)),
            ),
      ],
    );
  }
}

class _DraggableTile extends StatelessWidget {
  const _DraggableTile({required this.tile, required this.onTap});

  final PracticeTile tile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Widget face = _TileFace(label: tile.token.core, palette: palette);
    return Semantics(
      button: true,
      label: 'الكلمة ${tile.token.core}. المسها لوضعها في الموضع التالي',
      child: ExcludeSemantics(
        child: Draggable<int>(
          data: tile.id,
          feedback: Material(
            color: Colors.transparent,
            child: Transform.scale(scale: 1.08, child: face),
          ),
          childWhenDragging: Opacity(opacity: 0.35, child: face),
          child: GestureDetector(onTap: onTap, child: face),
        ),
      ),
    );
  }
}

class _TileFace extends StatelessWidget {
  const _TileFace({required this.label, required this.palette});

  final String label;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: palette.surface,
        shape: AppShapes.rounded(AppShapes.radiusSmall, side: BorderSide(color: palette.line)),
        shadows: <BoxShadow>[
          BoxShadow(color: palette.shadow, blurRadius: 6, offset: const Offset(0, 2), spreadRadius: -2),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Text(
          label,
          style: AppTypography.matnOf(context, color: palette.ink, fontSize: 22),
        ),
      ),
    );
  }
}

class _ShakingTile extends StatelessWidget {
  const _ShakingTile({super.key, required this.shakeTick, required this.child});

  final int shakeTick;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (shakeTick == 0 || MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(shakeTick),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      builder: (BuildContext context, double value, Widget? shaking) {
        final double offset = math.sin(value * math.pi * 6) * 6 * (1 - value);
        return Transform.translate(offset: Offset(offset, 0), child: shaking);
      },
      child: child,
    );
  }
}

class _CompletedBanner extends StatelessWidget {
  const _CompletedBanner({
    required this.mistakes,
    required this.hasNext,
    required this.onNext,
    required this.onAgain,
  });

  final int mistakes;
  final bool hasNext;
  final VoidCallback onNext;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          mistakes == 0 ? 'رتّبتَ المقطع كاملاً من أول محاولة. بارك الله في حفظك.' : 'اكتمل المقطع. التكرار يرسّخ الحفظ.',
          textAlign: TextAlign.center,
          style: text.titleSmall?.copyWith(color: palette.emeraldText, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onAgain,
                icon: const Icon(Icons.replay_rounded),
                label: const Text('أعد المقطع'),
              ),
            ),
            if (hasNext) ...<Widget>[
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onNext,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('المقطع التالي'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
