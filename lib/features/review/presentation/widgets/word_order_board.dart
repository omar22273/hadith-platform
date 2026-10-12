// تحدي ترتيب عبارات المتن المشكولة: تُلمس العبارة (أو تُسحب) من البلاطات المبعثرة
// إلى الموضع التالي في الحوض العلوي، فتثبت إن طابقته رسماً وضبطاً، وإلا اهتزت
// بلطف وعادت. فإن أخطأ ثلاث مرات متتالية في التمرين أومضت العبارة الصحيحة التالية
// بكهرماني هادئ؛ والقفل على حاله حتى يكتمل التمرين. وفي وضع التجربة يظهر زر
// «تجاوز للاختبار ⚡» الذي يرتّب كل العبارات فوراً.
// العبارات معروضة بضبطها كما في ملف الحديث حرفاً بحرف.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/text/arabic_digits.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/completion_flash.dart';
import '../../../../core/ui/gated_next_button.dart';
import '../../../../core/ui/hint_glow.dart';
import '../../../../core/ui/testing_skip_button.dart';
import '../../../hadith/domain/practice_engine.dart';
import '../../../journey/application/pacing_notifier.dart';
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
        'لا مقاطع للترتيب في بطاقات اليوم.',
        textAlign: TextAlign.center,
        style: text.bodyMedium?.copyWith(color: palette.inkSoft),
      );
    }
    final OrderChallenge challenge = deck.orderChallenges[state.index];
    final int limit = openChallengeLimit(state.completed, deck.orderChallenges.length);
    final bool hasNext = state.index + 1 < deck.orderChallenges.length;

    void attempt(int tileId) {
      final PlacementOutcome outcome = controller.place(tileId);
      switch (outcome) {
        case PlacementOutcome.mismatch:
          HapticFeedback.selectionClick();
        case PlacementOutcome.completed:
          // اكتمال المقطع: اهتزاز خفيف يوافق وميض النجاح الهادئ.
          HapticFeedback.lightImpact();
        case PlacementOutcome.placed:
        case PlacementOutcome.ignored:
          break;
      }
    }

    final bool testingSkip = ref.watch(testingSkipEnabledProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (testingSkip) ...<Widget>[
          TestingSkipButton(onPressed: () => controller.skipAllForTesting()),
          const SizedBox(height: 12),
        ],
        _ChallengePicker(
          count: deck.orderChallenges.length,
          selected: state.index,
          limit: limit,
          completed: state.completed,
          onSelect: controller.select,
        ),
        const SizedBox(height: 12),
        Text(
          '${challenge.hadithTitle} · ${challenge.label}',
          style: text.labelLarge?.copyWith(color: palette.amberText, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'المس العبارة لتنتقل إلى الحوض العلوي بالترتيب، أو اسحبها. العبارة غير المطابقة تعود بلطف.',
          style: text.bodySmall?.copyWith(color: palette.inkSoft),
        ),
        const SizedBox(height: 12),
        CompletionFlash(
          key: ValueKey<int>(state.index),
          completed: board.completed,
          child: _Line(board: board, onDrop: attempt),
        ),
        _MismatchNotice(board: board),
        const SizedBox(height: 10),
        if (board.completed)
          _CompletedBanner(mistakes: board.mistakes, onAgain: controller.reset)
        else ...<Widget>[
          Text(
            'العبارات المبعثرة',
            style: text.labelMedium?.copyWith(color: palette.inkSoft),
          ),
          const SizedBox(height: 8),
          _Pool(board: board, hintTile: board.hintTileId, onTapTile: attempt),
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
                label: const Text('ابدأ التمرين من جديد'),
              ),
            ],
          ),
        ],
        if (hasNext) ...<Widget>[
          const SizedBox(height: 12),
          // لا يتفعّل إلا إذا طابق المقطع الحالي المتن المشكول مطابقة تامة؛
          // والانتقال يمرّ عبر advance التي تتحقق من ذلك مرة ثانية في المتحكم.
          GatedNextButton(
            buttonKey: const ValueKey<String>('order-next-segment'),
            label: 'المقطع التالي',
            enabled: board.completed,
            onPressed: () {
              controller.advance();
            },
          ),
        ],
      ],
    );
  }
}

/// تنبيه بصري لطيف عند كلمة غير مطابقة: لا حمرة ولا توبيخ، وتعود الكلمة إلى
/// مكانها بين الكلمات المبعثرة. يزول بوضع الكلمة الصحيحة أو بالتراجع.
class _MismatchNotice extends StatelessWidget {
  const _MismatchNotice({required this.board});

  final OrderBoard board;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final int? tileId = board.lastMismatchTile;
    final Widget? notice = tileId == null || board.completed
        ? null
        : Semantics(
            liveRegion: true,
            container: true,
            child: DecoratedBox(
              key: const ValueKey<String>('order-mismatch-notice'),
              decoration: ShapeDecoration(
                color: palette.amberSoft,
                shape: AppShapes.rounded(
                  AppShapes.radiusSmall,
                  side: BorderSide(color: palette.amber.withValues(alpha: 0.45)),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.info_outline_rounded, size: 20, color: palette.amberText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ليست هذه العبارة التالية في المتن، فعادت إلى مكانها. جرّب عبارة أخرى.',
                        style: AppTypography.ui(color: palette.amberText, fontSize: 13, height: 1.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: Padding(
          key: ValueKey<int>(notice == null ? -1 : board.mismatchTick),
          padding: EdgeInsets.only(top: notice == null ? 0 : 10),
          child: notice ?? const SizedBox(width: double.infinity),
        ),
      ),
    );
  }
}

class _ChallengePicker extends StatelessWidget {
  const _ChallengePicker({
    required this.count,
    required this.selected,
    required this.limit,
    required this.completed,
    required this.onSelect,
  });

  final int count;
  final int selected;
  final int limit;
  final Set<int> completed;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: count,
        separatorBuilder: (BuildContext context, int index) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final bool active = index == selected;
          final bool locked = index > limit;
          final bool done = completed.contains(index);
          final Color foreground = locked
              ? palette.locked
              : (done ? palette.emeraldText : (active ? palette.amberText : palette.inkSoft));
          return Semantics(
            enabled: !locked,
            label: locked
                ? 'التمرين ${arabicDigits(index + 1)} مقفل حتى إتمام ما قبله'
                : 'التمرين ${arabicDigits(index + 1)}${done ? '، مكتمل' : ''}',
            child: ExcludeSemantics(
              child: ChoiceChip(
                selected: active && !locked,
                // null يعطّل الرقاقة فلا تُنقر وتظهر رمادية.
                onSelected: locked ? null : (bool value) => onSelect(index),
                avatar: Icon(
                  locked ? Icons.lock_rounded : (done ? Icons.check_circle_rounded : Icons.edit_note_rounded),
                  size: 18,
                  color: foreground,
                ),
                label: Text('المقطع ${arabicDigits(index + 1)}'),
                selectedColor: palette.amberSoft,
                backgroundColor: locked ? palette.lockedSoft : (done ? palette.emeraldSoft : palette.surface),
                disabledColor: palette.lockedSoft,
                side: BorderSide(
                  color: locked ? palette.line : (active ? palette.amber : (done ? palette.emerald : palette.line)),
                ),
                shape: AppShapes.rounded(AppShapes.radiusSmall),
                showCheckmark: false,
                labelStyle: AppTypography.ui(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
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
    final TextStyle phrase = AppTypography.matnOf(context, color: palette.ink, fontSize: 21);
    final List<Widget> children = <Widget>[];
    for (int position = 0; position < board.drill.tokens.length; position++) {
      if (position < board.placedTiles.length) {
        final PracticeTile tile = board.drill.tiles[board.placedTiles[position]];
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(
              tile.token.core,
              key: ValueKey<String>('placed-phrase-$position'),
              style: phrase.copyWith(color: palette.emeraldText, height: 1.8),
            ),
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
                label: 'الموضع ${arabicDigits(position + 1)}: أفلت العبارة هنا',
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  constraints: const BoxConstraints(minHeight: 46),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: ShapeDecoration(
                    color: hovering ? palette.amberSoft : palette.surfaceMuted,
                    shape: AppShapes.rounded(
                      AppShapes.radiusSmall,
                      side: BorderSide(color: hovering ? palette.amber : palette.amber.withValues(alpha: 0.5), width: 1.4),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'العبارة ${arabicDigits(position + 1)}',
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
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: palette.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _Pool extends StatelessWidget {
  const _Pool({required this.board, required this.hintTile, required this.onTapTile});

  final OrderBoard board;

  /// العبارة التي تومض بتلميح كهرماني بعد ثلاث محاولات خاطئة متتالية.
  final int? hintTile;
  final ValueChanged<int> onTapTile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final PracticeTile tile in board.drill.tiles)
          if (!board.isUsed(tile.id))
            _ShakingTile(
              key: ValueKey<String>('tile-${tile.id}'),
              shakeTick: board.lastMismatchTile == tile.id ? board.mismatchTick : 0,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DraggableTile(
                  tile: tile,
                  hinted: tile.id == hintTile,
                  onTap: () => onTapTile(tile.id),
                ),
              ),
            ),
      ],
    );
  }
}

class _DraggableTile extends StatelessWidget {
  const _DraggableTile({required this.tile, required this.hinted, required this.onTap});

  final PracticeTile tile;
  final bool hinted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Widget face = _TileFace(label: tile.token.core, palette: palette);
    return Semantics(
      button: true,
      label: hinted
          ? 'العبارة ${tile.token.core}. تلميح: هذه العبارة التالية. المسها لوضعها'
          : 'العبارة ${tile.token.core}. المسها لوضعها في الموضع التالي',
      child: ExcludeSemantics(
        child: Draggable<int>(
          data: tile.id,
          feedback: Material(
            color: Colors.transparent,
            child: Transform.scale(scale: 1.08, child: face),
          ),
          childWhenDragging: Opacity(opacity: 0.35, child: face),
          child: GestureDetector(
            onTap: onTap,
            child: HintGlow(active: hinted, radius: AppShapes.radiusSmall, child: face),
          ),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          label,
          style: AppTypography.matnOf(context, color: palette.ink, fontSize: 21).copyWith(height: 1.8),
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
  const _CompletedBanner({required this.mistakes, required this.onAgain});

  final int mistakes;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          mistakes == 0 ? 'رتّبتَ العبارات كاملةً من أول محاولة. بارك الله في حفظك.' : 'اكتمل الترتيب. التكرار يرسّخ الحفظ.',
          textAlign: TextAlign.center,
          style: text.titleSmall?.copyWith(color: palette.emeraldText, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Align(
          child: TextButton.icon(
            onPressed: onAgain,
            icon: const Icon(Icons.replay_rounded),
            label: const Text('أعد التمرين'),
          ),
        ),
      ],
    );
  }
}
