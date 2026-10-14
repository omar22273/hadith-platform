// المرحلة الثالثة: رتّب ألفاظ الحديث والحفظ التراكمي.
// - ترتيب العبارات: عبارات تامة المعنى من المتن المشكول، مبعثرة، تُلمس لتستقر
//   في حوض المتن بالترتيب (لمسة واحدة تضع العبارة). العبارة الموافقة ترتكز
//   بارتكاز ناعم، وغير الموافقة تهتز بلطف وتعود بلا توبيخ. والتقدم محكوم
//   بالإنجاز: زر «التالي ←» معطّل رمادي حتى يطابق التمرينُ المتنَ المشكول
//   تماماً، فيومض الحوض بالأخضر الهادئ ويهتز الجهاز اهتزازة خفيفة ويتفعّل الزر
//   بارزاً؛ والتمارين اللاحقة مقفلة حتى إتمام ما قبلها. وفي وضع التجربة يظهر
//   زر «تجاوز للاختبار ⚡» الذي يرتّب كل العبارات فوراً.
// - التلاشي التدريجي: إخفاء ٢٥٪ ثم ٥٠٪ ثم ٨٠٪ من الكلمات واستحضارها ذهنياً.

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
import '../../../../core/ui/rtl_inline.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../../../core/ui/testing_skip_button.dart';
import '../../../hadith/domain/practice_engine.dart';
import '../../../journey/application/pacing_notifier.dart';
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
    final bool cleared = ref.watch(practiceClearedProvider(hadithId));
    if (engine == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        _ModeSwitch(mode: state.practiceMode, onChanged: controller.setPracticeMode),
        const SizedBox(height: 10),
        _GateNote(
          cleared: cleared,
          done: state.completedDrills.where((int i) => i >= 0 && i < engine.drills.length).length,
          total: engine.drills.length,
        ),
        const SizedBox(height: 14),
        if (state.practiceMode == PracticeMode.reconstruction && ref.watch(testingSkipEnabledProvider)) ...<Widget>[
          TestingSkipButton(onPressed: () => controller.skipPracticeForTesting()),
          const SizedBox(height: 12),
        ],
        if (state.practiceMode == PracticeMode.reconstruction)
          _ReconstructionBoard(engine: engine, state: state, controller: controller)
        else
          _VanishingBoard(engine: engine, state: state, controller: controller),
      ],
    );
  }
}

/// يبيّن سبب قفل الخطوة التالية وتقدّم الترصيع، ثم يتحول إلى تأكيد هادئ.
class _GateNote extends StatelessWidget {
  const _GateNote({required this.cleared, required this.done, required this.total});

  final bool cleared;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final String message = cleared
        ? 'اكتمل ترصيع المتن كله، وانفتحت الخطوة التالية.'
        : 'أتمّ ترتيب عبارات المتن لتُفتح الخطوة التالية · ${arabicDigits(done)} من ${arabicDigits(total)}';
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        key: const ValueKey<String>('practice-gate-note'),
        decoration: ShapeDecoration(
          color: cleared ? palette.emeraldSoft : palette.lockedSoft,
          shape: AppShapes.rounded(
            AppShapes.radiusSmall,
            side: BorderSide(color: cleared ? palette.emerald.withValues(alpha: 0.5) : palette.line),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: <Widget>[
              Icon(
                cleared ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                size: 20,
                color: cleared ? palette.emeraldText : palette.locked,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.ui(
                    color: cleared ? palette.emeraldText : palette.inkSoft,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
        tile(PracticeMode.reconstruction, Icons.view_module_rounded, 'ترتيب العبارات', 'رتّب عبارات المتن في الحوض'),
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

  void _attempt(int tileId) {
    final PlacementResult result = controller.placeTile(tileId);
    switch (result) {
      case PlacementResult.placed:
        HapticFeedback.selectionClick();
      case PlacementResult.completedDrill:
        // آخر كلمة في موضعها: اهتزازة خفيفة تواكب وميض النجاح الهادئ.
        HapticFeedback.lightImpact();
      case PlacementResult.mismatch:
        HapticFeedback.selectionClick();
      case PlacementResult.ignored:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    if (engine.drills.isEmpty) {
      return Text('لا عبارات للترتيب في هذا الحديث.', style: text.bodyMedium);
    }
    final int index = state.drillIndex.clamp(0, engine.drills.length - 1).toInt();
    final ChunkDrill drill = engine.drills[index];
    final Set<int> placed = state.placedTiles.toSet();
    // مطابقة تامة: كل عبارات التمرين موضوعة، وكلٌّ في موضعها الصحيح (لا تُقبل
    // البلاطة في المتحكم إلا إن وافقت موضعها).
    final bool complete = state.placedTiles.length == drill.tokens.length;
    final bool hasNext = index + 1 < engine.drills.length;
    final int limit = openDrillLimit(engine.drills.length, state.completedDrills);
    final TextStyle wordStyle = AppTypography.matnOf(context, color: palette.ink, fontSize: 22, fontWeight: FontWeight.w700);
    // بعد ثلاث محاولات خاطئة متتالية في التمرين تومض العبارة الصحيحة التالية
    // بكهرماني هادئ؛ القفل كما هو: لا تُوضع العبارة عنه ولا يتفعّل «التالي».
    final int? hintTile = drill.hintTile(state.placedTiles, state.mistakeStreak);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: engine.drills.length,
            separatorBuilder: (BuildContext context, int _) => const SizedBox(width: 8),
            itemBuilder: (BuildContext context, int i) {
              final bool current = i == index;
              final bool done = state.completedDrills.contains(i);
              final bool locked = i > limit;
              final Color foreground = locked
                  ? palette.locked
                  : (done ? palette.emeraldText : (current ? palette.amberText : palette.inkSoft));
              return Semantics(
                enabled: !locked,
                label: locked
                    ? 'التمرين ${arabicDigits(i + 1)} مقفل حتى إتمام ما قبله'
                    : 'التمرين ${arabicDigits(i + 1)}${done ? '، مكتمل' : ''}',
                child: ExcludeSemantics(
                  child: ChoiceChip(
                    selected: current && !locked,
                    // null يعطّل الرقاقة فلا تُنقر وتظهر رمادية.
                    onSelected: locked ? null : (bool _) => controller.selectDrill(i),
                    avatar: Icon(
                      locked ? Icons.lock_rounded : (done ? Icons.check_circle_rounded : Icons.edit_note_rounded),
                      size: 18,
                      color: foreground,
                    ),
                    label: Text(arabicDigits(i + 1)),
                    shape: AppShapes.rounded(AppShapes.radiusSmall),
                    selectedColor: palette.amberSoft,
                    backgroundColor: locked ? palette.lockedSoft : (done ? palette.emeraldSoft : palette.surface),
                    disabledColor: palette.lockedSoft,
                    side: BorderSide(
                      color: locked
                          ? palette.line
                          : (current ? palette.amber : (done ? palette.emerald : palette.line)),
                    ),
                    showCheckmark: false,
                    labelStyle: AppTypography.ui(
                      color: foreground,
                      fontSize: 13,
                      fontWeight: current ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          drill.label,
          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        CompletionFlash(
          key: ValueKey<String>('practice-flash-$index'),
          completed: complete,
          minHeight: 68,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          idleColor: palette.surfaceMuted,
          idleBorderColor: palette.amber.withValues(alpha: 0.5),
          idleBorderWidth: 1.4,
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int position = 0; position < state.placedTiles.length; position++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey<String>('placed-$index-$position'),
                      tween: Tween<double>(begin: 0.9, end: 1),
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutBack,
                      builder: (BuildContext context, double scale, Widget? child) =>
                          Transform.scale(scale: scale, alignment: AlignmentDirectional.centerStart, child: child),
                      child: Text(drill.tokens[position].raw, style: wordStyle.copyWith(height: 1.8)),
                    ),
                  ),
                if (!complete)
                  Container(
                    height: 34,
                    alignment: AlignmentDirectional.centerStart,
                    padding: const EdgeInsetsDirectional.only(start: 12),
                    decoration: ShapeDecoration(
                      color: palette.amberSoft,
                      shape: AppShapes.rounded(AppShapes.radiusSmall),
                    ),
                    child: Text(
                      'العبارة ${arabicDigits(state.placedTiles.length + 1)}',
                      style: AppTypography.ui(color: palette.amberText, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (complete)
          Semantics(
            liveRegion: true,
            container: true,
            child: SmoothSurface(
              color: palette.emeraldSoft,
              radius: AppShapes.radiusMedium,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  Icon(Icons.verified_outlined, color: palette.emeraldText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'استقرت العبارات في مواضعها.',
                      style: text.bodyMedium?.copyWith(color: palette.emeraldText, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final PracticeTile tile in drill.tiles)
                if (!placed.contains(tile.id))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _Tile(
                      key: ValueKey<String>('tile-$index-${tile.id}'),
                      label: tile.token.core,
                      style: wordStyle,
                      shakeTick: tile.id == state.mistakeTileId ? state.mistakeTick : 0,
                      hinted: tile.id == hintTile,
                      onTap: () => _attempt(tile.id),
                    ),
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
        const SizedBox(height: 8),
        // معطّل رمادي ما لم يطابق المقطع المتن تماماً، ثم عريض بارز. والمتحكم
        // يعيد التحقق من المطابقة قبل أن ينقل.
        GatedNextButton(
          buttonKey: const ValueKey<String>('practice-next'),
          label: hasNext ? 'المقطع التالي' : 'إتمام التثبيت والمتابعة',
          enabled: complete,
          onPressed: () {
            controller.advanceFromDrill();
          },
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
    required this.hinted,
    required this.onTap,
  });

  final String label;
  final TextStyle style;
  final int shakeTick;

  /// هل هي العبارة الصحيحة التالية بعد ثلاث محاولات خاطئة متتالية.
  final bool hinted;
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
      child: HintGlow(
        active: hinted,
        child: SmoothSurface(
          color: palette.surface,
          borderColor: palette.line,
          radius: AppShapes.radiusMedium,
          elevated: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          onTap: onTap,
          semanticLabel: hinted ? '$label، تلميح: هذه العبارة التالية' : label,
          child: Text(label, textAlign: TextAlign.start, style: style.copyWith(height: 1.8)),
        ),
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
        addRtlSafePlaceholder(
          spans,
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
          style: style,
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
            textDirection: TextDirection.rtl,
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

