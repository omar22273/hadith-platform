// المرحلة الثالثة: التثبيت الحركي والحفظ التراكمي.
// - ترصيع المتن: مصفوفة كلمات مشكولة مبعثرة تُلمس لتستقر في حوض المتن بالترتيب.
//   الكلمة الموافقة ترتكز بارتكاز ناعم، وغير الموافقة تهتز بلطف وتعود بلا توبيخ.
// - التلاشي التدريجي: إخفاء ٢٥٪ ثم ٥٠٪ ثم ٨٠٪ من الكلمات واستحضارها ذهنياً.

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
import '../../application/session_controller.dart';
import '../../application/session_state.dart';

/// مرحلة التثبيت.
class PracticeStage extends ConsumerWidget {
  const PracticeStage({super.key, required this.hadithId});

  /// الحديث.
  final String hadithId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PracticeEngine? engine = ref.watch(practiceEngineProvider(hadithId));
    final SessionState state = ref.watch(sessionControllerProvider(hadithId));
    final SessionController controller = ref.read(sessionControllerProvider(hadithId).notifier);
    if (engine == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        _ModeSwitch(mode: state.practiceMode, onChanged: controller.setPracticeMode),
        const SizedBox(height: 14),
        if (state.practiceMode == PracticeMode.reconstruction)
          _ReconstructionBoard(engine: engine, state: state, controller: controller)
        else
          _VanishingBoard(engine: engine, state: state, controller: controller),
      ],
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged});

  final PracticeMode mode;
  final ValueChanged<PracticeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    Widget tile(PracticeMode value, IconData icon, String title, String subtitle) {
      final bool selected = value == mode;
      return Expanded(
        child: SmoothSurface(
          color: selected ? palette.amberSoft : palette.surface,
          borderColor: selected ? palette.amber : palette.line,
          borderWidth: selected ? 1.6 : 1,
          radius: AppShapes.radiusMedium,
          padding: const EdgeInsets.all(12),
          onTap: () => onChanged(value),
          semanticLabel: title,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: selected ? palette.amberText : palette.inkSoft),
              const SizedBox(height: 4),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: palette.inkSoft),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: <Widget>[
        tile(PracticeMode.reconstruction, Icons.view_module_rounded, 'ترصيع المتن', 'رتّب الكلمات في الحوض'),
        const SizedBox(width: 10),
        tile(PracticeMode.vanishing, Icons.blur_on_rounded, 'التلاشي التدريجي', 'استحضر ما خُفي'),
      ],
    );
  }
}

class _ReconstructionBoard extends StatelessWidget {
  const _ReconstructionBoard({
    required this.engine,
    required this.state,
    required this.controller,
  });

  final PracticeEngine engine;
  final SessionState state;
  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    if (engine.drills.isEmpty) {
      return Text('لا مقاطع ترصيع لهذا الحديث.', style: text.bodyMedium);
    }
    final int index = state.drillIndex.clamp(0, engine.drills.length - 1).toInt();
    final ChunkDrill drill = engine.drills[index];
    final Set<int> placed = state.placedTiles.toSet();
    final bool complete = state.placedTiles.length == drill.tokens.length;
    final TextStyle wordStyle = AppTypography.matnOf(context, color: palette.ink, fontSize: 23, fontWeight: FontWeight.w700);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: engine.drills.length,
            separatorBuilder: (BuildContext context, int _) => const SizedBox(width: 8),
            itemBuilder: (BuildContext context, int i) {
              final bool current = i == index;
              final bool done = state.completedDrills.contains(i);
              return ChoiceChip(
                selected: current,
                onSelected: (bool _) => controller.selectDrill(i),
                avatar: done ? Icon(Icons.check_rounded, size: 16, color: palette.emeraldText) : null,
                label: Text(arabicDigits(i + 1)),
                shape: AppShapes.rounded(AppShapes.radiusSmall),
                selectedColor: palette.amberSoft,
                backgroundColor: palette.surface,
                side: BorderSide(color: current ? palette.amber : palette.line),
                showCheckmark: false,
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          drill.chunk.label,
          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          constraints: const BoxConstraints(minHeight: 96),
          decoration: ShapeDecoration(
            color: complete ? palette.emeraldSoft : palette.surfaceMuted,
            shape: AppShapes.rounded(
              AppShapes.radiusLarge,
              side: BorderSide(
                color: complete ? palette.emerald : palette.amber.withValues(alpha: 0.5),
                width: 1.4,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              for (int position = 0; position < state.placedTiles.length; position++)
                TweenAnimationBuilder<double>(
                  key: ValueKey<String>('placed-$index-$position'),
                  tween: Tween<double>(begin: 0.6, end: 1),
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutBack,
                  builder: (BuildContext context, double scale, Widget? child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Text(drill.tokens[position].raw, style: wordStyle),
                ),
              if (!complete)
                Container(
                  width: 52,
                  height: 26,
                  decoration: ShapeDecoration(
                    color: palette.amberSoft,
                    shape: AppShapes.rounded(AppShapes.radiusSmall),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (complete)
          SmoothSurface(
            color: palette.emeraldSoft,
            radius: AppShapes.radiusMedium,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                Icon(Icons.verified_outlined, color: palette.emeraldText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'استقر المقطع في موضعه.',
                    style: text.bodyMedium?.copyWith(color: palette.emeraldText, fontWeight: FontWeight.w600),
                  ),
                ),
                if (index + 1 < engine.drills.length)
                  TextButton(onPressed: controller.nextDrill, child: const Text('المقطع التالي')),
              ],
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: <Widget>[
              for (final PracticeTile tile in drill.tiles)
                if (!placed.contains(tile.id))
                  _Tile(
                    key: ValueKey<String>('tile-$index-${tile.id}'),
                    label: tile.token.core,
                    style: wordStyle,
                    shakeTick: tile.id == state.mistakeTileId ? state.mistakeTick : 0,
                    onTap: () {
                      final PlacementResult result = controller.placeTile(tile.id);
                      switch (result) {
                        case PlacementResult.placed:
                          HapticFeedback.selectionClick();
                        case PlacementResult.completedDrill:
                          HapticFeedback.mediumImpact();
                        case PlacementResult.mismatch:
                          HapticFeedback.lightImpact();
                        case PlacementResult.ignored:
                          break;
                      }
                    },
                  ),
            ],
          ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextButton.icon(
              onPressed: state.placedTiles.isEmpty ? null : controller.undoTile,
              icon: const Icon(Icons.undo_rounded),
              label: const Text('تراجع'),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: state.placedTiles.isEmpty ? null : controller.resetDrill,
              icon: const Icon(Icons.replay_rounded),
              label: const Text('من البداية'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.label,
    required this.style,
    required this.shakeTick,
    required this.onTap,
  });

  final String label;
  final TextStyle style;
  final int shakeTick;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(shakeTick),
      tween: Tween<double>(begin: shakeTick == 0 ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 420),
      builder: (BuildContext context, double t, Widget? child) {
        final double offset = math.sin(t * math.pi * 5) * (1 - t) * 7;
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: SmoothSurface(
        color: palette.surface,
        borderColor: palette.line,
        radius: AppShapes.radiusMedium,
        elevated: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        onTap: onTap,
        semanticLabel: label,
        child: Text(label, style: style.copyWith(height: 1.9)),
      ),
    );
  }
}

class _VanishingBoard extends StatelessWidget {
  const _VanishingBoard({
    required this.engine,
    required this.state,
    required this.controller,
  });

  final PracticeEngine engine;
  final SessionState state;
  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    if (engine.levels.isEmpty || engine.words.isEmpty) {
      return Text('لا مستويات تلاشٍ لهذا الحديث.', style: text.bodyMedium);
    }
    final int level = state.vanishingLevel.clamp(0, engine.levels.length - 1).toInt();
    final Set<int> hidden = engine.hiddenAt(level);
    final int recalled = hidden.where(state.revealed.contains).length;
    final TextStyle style = AppTypography.matnOf(context, color: palette.ink, fontSize: 25, fontWeight: FontWeight.w700);

    final List<InlineSpan> spans = <InlineSpan>[];
    for (int w = 0; w < engine.words.length; w++) {
      final VanishWord word = engine.words[w];
      if (w > 0) {
        spans.add(TextSpan(text: ' ', style: style));
      }
      if (hidden.contains(w) && !state.revealed.contains(w)) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Semantics(
              button: true,
              label: 'كلمة مخفية، المس بعد استحضارها لتظهر',
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  controller.reveal(w);
                },
                child: Container(
                  width: math.max(36, word.token.core.length * 11.0),
                  height: 30,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: ShapeDecoration(
                    color: palette.amberSoft,
                    shape: AppShapes.rounded(
                      AppShapes.radiusSmall,
                      side: BorderSide(color: palette.amber.withValues(alpha: 0.45)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      } else {
        final bool recalledWord = hidden.contains(w);
        spans.add(
          TextSpan(
            text: word.token.raw,
            style: recalledWord ? style.copyWith(color: palette.amberText) : style,
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: 8,
          children: <Widget>[
            for (int i = 0; i < engine.levels.length; i++)
              ChoiceChip(
                selected: i == level,
                onSelected: (bool _) => controller.setVanishingLevel(i),
                label: Text('إخفاء ${arabicDigits(engine.levels[i])}٪'),
                shape: AppShapes.rounded(AppShapes.radiusSmall),
                selectedColor: palette.amberSoft,
                backgroundColor: palette.surface,
                side: BorderSide(color: i == level ? palette.amber : palette.line),
                showCheckmark: false,
              ),
          ],
        ),
        const SizedBox(height: 12),
        SmoothSurface(
          elevated: true,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
          child: Text.rich(
            TextSpan(children: spans),
            textAlign: TextAlign.justify,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'استحضرتَ ${arabicDigits(recalled)} من ${arabicDigits(hidden.length)}',
                style: text.bodyMedium?.copyWith(color: palette.inkSoft),
              ),
            ),
            TextButton.icon(
              onPressed: state.revealed.isEmpty ? null : controller.hideAgain,
              icon: const Icon(Icons.visibility_off_outlined),
              label: const Text('أخفِ من جديد'),
            ),
          ],
        ),
        Text(
          'استحضر الكلمة في ذهنك أو بلسانك، ثم المس موضعها لتتحقق.',
          style: text.labelSmall?.copyWith(color: palette.inkSoft),
        ),
      ],
    );
  }
}

