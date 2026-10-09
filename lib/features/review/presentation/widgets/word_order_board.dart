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
import '../../../../core/theme/feedback_colors.dart';
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
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
          'اسحب كل كلمة إلى الموضع التالي في السطر، أو المسها. الكلمة غير المطابقة تعود بلطف.',
          style: text.bodySmall?.copyWith(color: palette.inkSoft),
        ),
        const SizedBox(height: 12),
        _CompletionFlash(
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
        if (hasNext) ...<Widget>[
          const SizedBox(height: 12),
          // لا يتفعّل إلا إذا طابق المقطع الحالي المتن المشكول مطابقة تامة؛
          // والانتقال يمرّ عبر advance التي تتحقق من ذلك مرة ثانية في المتحكم.
          _NextSegmentButton(
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
                        'ليست هذه الكلمة التالية في المتن، فعادت إلى مكانها. جرّب كلمة أخرى.',
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

/// زر «المقطع التالي ←»: رمادي معطّل ما لم يكتمل المقطع، ثم عريض بارز زمردي.
class _NextSegmentButton extends StatelessWidget {
  const _NextSegmentButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      height: enabled ? 62 : 50,
      child: FilledButton(
        key: const ValueKey<String>('order-next-segment'),
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: palette.emerald,
          foregroundColor: palette.onAccent,
          disabledBackgroundColor: palette.lockedSoft,
          disabledForegroundColor: palette.locked,
          elevation: enabled ? 2 : 0,
          shape: AppShapes.rounded(AppShapes.radiusMedium),
          textStyle: AppTypography.ui(
            color: palette.onAccent,
            fontSize: enabled ? 18 : 15,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Flexible(child: Text('المقطع التالي', overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 10),
            // arrow_forward ينعكس تلقائياً في الاتجاه من اليمين فيشير إلى اليسار «←».
            Icon(Icons.arrow_forward_rounded, size: enabled ? 26 : 20),
          ],
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
                ? 'المقطع ${arabicDigits(index + 1)} مقفل حتى إتمام ما قبله'
                : 'المقطع ${arabicDigits(index + 1)}${done ? '، مكتمل' : ''}',
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

/// وميض أخضر عند اكتمال المقطع، ثم يستقر على أخضر هادئ. بلا حركة إن طُلب تقليلها.
class _CompletionFlash extends StatefulWidget {
  const _CompletionFlash({super.key, required this.completed, required this.child});

  final bool completed;
  final Widget child;

  @override
  State<_CompletionFlash> createState() => _CompletionFlashState();
}

class _CompletionFlashState extends State<_CompletionFlash> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didUpdateWidget(_CompletionFlash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.completed && !oldWidget.completed) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    } else if (!widget.completed) {
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final FeedbackColors feedback = FeedbackColors.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        // وميض: يرتفع اللون الأخضر سريعاً ثم يهدأ إلى الأخضر الفاتح.
        final double pulse = widget.completed ? (1 - Curves.easeOut.transform(_controller.value)) : 0;
        final Color fill = widget.completed
            ? Color.lerp(palette.emeraldSoft, feedback.rightBorder.withValues(alpha: 0.55), pulse)!
            : palette.surface;
        return SmoothSurface(
          color: fill,
          borderColor: widget.completed ? feedback.rightBorder : palette.line,
          borderWidth: widget.completed ? 2 : 1,
          padding: const EdgeInsets.all(14),
          child: child!,
        );
      },
      child: widget.child,
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
          mistakes == 0 ? 'رتّبتَ المقطع كاملاً من أول محاولة. بارك الله في حفظك.' : 'اكتمل المقطع. التكرار يرسّخ الحفظ.',
          textAlign: TextAlign.center,
          style: text.titleSmall?.copyWith(color: palette.emeraldText, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Align(
          child: TextButton.icon(
            onPressed: onAgain,
            icon: const Icon(Icons.replay_rounded),
            label: const Text('أعد المقطع'),
          ),
        ),
      ],
    );
  }
}
