// شاشة مجلس السماع والمشافهة: واجهة عالية الوضوح لغير القراء وكبار السن،
// بخط كبير ومساحات لمس عملاقة: السرد القصصي، والتلقين بالترديد، والمأزق الصوتي.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/speech_service.dart';
import '../../../core/text/arabic_digits.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/ui/app_shapes.dart';
import '../../../core/ui/smooth_surface.dart';
import '../../../core/ui/wide_action_button.dart';
import '../../daily_session/presentation/widgets/closing_view.dart';
import '../../hadith/application/content_providers.dart';
import '../../hadith/data/models/models.dart';
import '../../hadith/domain/hadith_bundle.dart';
import '../../recitation/application/recitation_controller.dart';
import '../application/oral_controller.dart';
import '../domain/oral_script.dart';

/// شاشة المجلس.
class OralModeScreen extends ConsumerWidget {
  const OralModeScreen({
    super.key,
    required this.hadithId,
    required this.countsTowardJourney,
  });

  /// الحديث.
  final String hadithId;

  /// هل هو وِرد اليوم.
  final bool countsTowardJourney;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<HadithBundle> bundle = ref.watch(hadithBundleProvider(hadithId));
    return MediaQuery.withClampedTextScaling(
      minScaleFactor: 1.1,
      child: Scaffold(
        body: SafeArea(
          child: bundle.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace stackTrace) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'لم يُعرض المجلس لخلل في البيانات:\n$error',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (HadithBundle data) => _OralBody(
              bundle: data,
              countsTowardJourney: countsTowardJourney,
            ),
          ),
        ),
      ),
    );
  }
}

class _OralBody extends ConsumerWidget {
  const _OralBody({required this.bundle, required this.countsTowardJourney});

  final HadithBundle bundle;
  final bool countsTowardJourney;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final String id = bundle.hadith.id;
    final OralState state = ref.watch(oralControllerProvider(id));
    final OralController controller = ref.read(oralControllerProvider(id).notifier);
    final RecitationState recitation = ref.watch(recitationControllerProvider(id));

    if (state.finished) {
      return ClosingView(
        hadithId: id,
        countedTowardJourney: countsTowardJourney,
        onBack: () => Navigator.of(context).maybePop(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 16, 4),
          child: Row(
            children: <Widget>[
              IconButton(
                iconSize: 30,
                onPressed: () {
                  controller.stop();
                  Navigator.of(context).maybePop();
                },
                tooltip: 'العودة إلى المسار',
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'مجلس السماع والمشافهة',
                      style: text.titleSmall?.copyWith(color: palette.amberText, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      bundle.hadith.title,
                      style: AppTypography.heritageTitle(color: palette.ink, fontSize: 28),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              for (final OralStep step in OralStep.values) ...<Widget>[
                if (step.index > 0) const SizedBox(width: 8),
                Expanded(
                  child: _StepTab(
                    step: step,
                    selected: step == state.step,
                    onTap: () => controller.selectStep(step),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: <Widget>[
              switch (state.step) {
                OralStep.story => _StoryPanel(state: state),
                OralStep.talqin => _TalqinPanel(
                    state: state,
                    chunks: controller.chunks,
                    chunkText: controller.currentChunkText,
                    recitation: recitation,
                    onMove: controller.moveChunk,
                  ),
                OralStep.dilemma => _DilemmaPanel(
                    scenario: bundle.hadith.reflection.scenario,
                    state: state,
                    onChoose: (String optionId) {
                      HapticFeedback.selectionClick();
                      unawaited(controller.choose(optionId));
                    },
                  ),
              },
            ],
          ),
        ),
        _ControlBar(
          state: state,
          onPlay: () {
            if (state.playing) {
              controller.stop();
              return;
            }
            switch (state.step) {
              case OralStep.story:
                unawaited(controller.playStory());
              case OralStep.talqin:
                unawaited(controller.startTalqin());
              case OralStep.dilemma:
                unawaited(controller.playDilemma());
            }
          },
          onPace: () => controller.setPace(
            state.pace == SpeechPace.normal ? SpeechPace.slow : SpeechPace.normal,
          ),
          onFinish: state.canFinish
              ? () => unawaited(_finishOral(context, controller, countsTowardJourney))
              : null,
          finishLabel: countsTowardJourney ? 'إتمام المجلس' : 'إنهاء المراجعة',
        ),
      ],
    );
  }
}

Future<void> _finishOral(BuildContext context, OralController controller, bool countsTowardJourney) async {
  try {
    await controller.finish(countsTowardJourney: countsTowardJourney);
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر حفظ إتمام المجلس على الجهاز. حاول مرة أخرى.')),
      );
    }
  }
}

class _StepTab extends StatelessWidget {
  const _StepTab({required this.step, required this.selected, required this.onTap});

  final OralStep step;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final IconData icon = switch (step) {
      OralStep.story => Icons.auto_stories_rounded,
      OralStep.talqin => Icons.record_voice_over_rounded,
      OralStep.dilemma => Icons.forum_rounded,
    };
    return SmoothSurface(
      color: selected ? palette.ink : palette.surface,
      borderColor: selected ? palette.ink : palette.line,
      radius: AppShapes.radiusMedium,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      onTap: onTap,
      semanticLabel: step.label,
      child: Column(
        children: <Widget>[
          Icon(icon, size: 30, color: selected ? palette.paper : palette.amberText),
          const SizedBox(height: 4),
          Text(
            step.label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: selected ? palette.paper : palette.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _CaptionCard extends StatelessWidget {
  const _CaptionCard({required this.text, required this.index, required this.count, required this.placeholder});

  final String text;
  final int index;
  final int count;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return SmoothSurface(
      elevated: true,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 150),
            child: Center(
              child: Text(
                text.isEmpty ? placeholder : text,
                textAlign: TextAlign.center,
                style: AppTypography.ui(
                  color: text.isEmpty ? palette.inkSoft : palette.ink,
                  fontSize: 26,
                  height: 1.8,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          if (count > 0) ...<Widget>[
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                for (int i = 0; i < count; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: i <= index ? palette.amber : palette.line,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _VoiceNote extends StatelessWidget {
  const _VoiceNote({required this.voiceAvailable});

  final bool? voiceAvailable;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        voiceAvailable == false
            ? 'لا يتوفر صوت عربي على هذا الجهاز، فتظهر الجمل مكبّرة بالتتابع.'
            : 'صوت آلي تجريبي يروي القصة والمأزق فقط. المتن لا يُقرأ بهذا الصوت، ويُسمع من تسجيل قارئ متقن.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: palette.inkSoft, height: 1.7),
      ),
    );
  }
}

class _StoryPanel extends StatelessWidget {
  const _StoryPanel({required this.state});

  final OralState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _CaptionCard(
          text: state.caption,
          index: state.captionIndex,
          count: state.captionCount,
          placeholder: 'اضغط زر الاستماع لتسمع قصة الحديث وسياقه.',
        ),
        _VoiceNote(voiceAvailable: state.voiceAvailable),
      ],
    );
  }
}

class _TalqinPanel extends StatelessWidget {
  const _TalqinPanel({
    required this.state,
    required this.chunks,
    required this.chunkText,
    required this.recitation,
    required this.onMove,
  });

  final OralState state;
  final List<PracticeChunk> chunks;
  final String chunkText;
  final RecitationState recitation;
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    if (chunks.isEmpty) {
      return Text('لا مقاطع تلقين لهذا الحديث.', style: text.titleMedium);
    }
    final int index = state.chunkIndex >= chunks.length ? chunks.length - 1 : state.chunkIndex;
    final String phaseLabel = switch (state.phase) {
      TalqinPhase.idle => 'اضغط زر البدء لتبدأ الترديد',
      TalqinPhase.listening => recitation.canPlayChunks ? 'استمع إلى القارئ' : 'تهيّأ للقراءة',
      TalqinPhase.repeating => 'ردّد الآن بصوتك · ${arabicDigits(state.secondsLeft)}',
      TalqinPhase.resting => 'أحسنت، التقط نفَسك',
      TalqinPhase.done => 'اكتمل التلقين بمقاطعه كلها',
    };
    final Color phaseColor = state.phase == TalqinPhase.repeating ? palette.amberText : palette.inkSoft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'المقطع ${arabicDigits(index + 1)} من ${arabicDigits(chunks.length)} · ${chunks[index].label}',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        SmoothSurface(
          elevated: true,
          borderColor: state.phase == TalqinPhase.repeating ? palette.amber : null,
          borderWidth: 2,
          padding: const EdgeInsets.all(20),
          child: Text(
            chunkText,
            textAlign: TextAlign.center,
            style: AppTypography.matn(color: palette.ink, fontSize: 34, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            for (int r = 1; r <= OralState.rounds; r++) ...<Widget>[
              if (r > 1) const SizedBox(width: 8),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: r <= state.round ? palette.emerald : palette.lockedSoft,
                  border: Border.all(color: r <= state.round ? palette.emerald : palette.line),
                ),
              ),
            ],
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                phaseLabel,
                style: text.titleLarge?.copyWith(color: phaseColor, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: WideActionButton(
                label: 'السابق',
                icon: Icons.arrow_back_rounded,
                tone: WideActionTone.quiet,
                giant: true,
                onPressed: index > 0 ? () => onMove(-1) : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: WideActionButton(
                label: 'التالي',
                icon: Icons.arrow_forward_rounded,
                tone: WideActionTone.quiet,
                giant: true,
                onPressed: index + 1 < chunks.length ? () => onMove(1) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          recitation.canPlayChunks
              ? 'يُسمع المقطع بصوت ${recitation.reciter ?? 'القارئ'}، ثم تردده أنت ثلاث مرات.'
              : 'لم تُسجَّل تلاوة المتن بعد بصوت قارئ متقن، ولا يُقرأ المتن بصوت آلي. اقرأ المقطع المكبّر بصوتك وردّده مع العدّ ثلاث مرات.',
          style: text.bodyMedium?.copyWith(color: palette.inkSoft, height: 1.7),
        ),
      ],
    );
  }
}

class _DilemmaPanel extends StatelessWidget {
  const _DilemmaPanel({required this.scenario, required this.state, required this.onChoose});

  final Scenario scenario;
  final OralState state;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _CaptionCard(
          text: state.caption,
          index: state.captionIndex,
          count: state.captionCount,
          placeholder: scenario.question,
        ),
        const SizedBox(height: 14),
        for (int i = 0; i < scenario.options.length; i++) ...<Widget>[
          _GiantOption(
            ordinal: optionOrdinal(i),
            option: scenario.options[i],
            selected: scenario.options[i].id == state.chosenOptionId,
            onTap: () => onChoose(scenario.options[i].id),
          ),
          const SizedBox(height: 12),
        ],
        if (state.chosenOptionId != null)
          SmoothSurface(
            color: palette.surfaceMuted,
            borderColor: palette.line,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'العلّة التربوية',
                  style: text.titleMedium?.copyWith(color: palette.amberText, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  scenario.takeaway,
                  style: AppTypography.ui(color: palette.ink, fontSize: 21, height: 1.8),
                ),
              ],
            ),
          ),
        _VoiceNote(voiceAvailable: state.voiceAvailable),
      ],
    );
  }
}

class _GiantOption extends StatelessWidget {
  const _GiantOption({
    required this.ordinal,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final String ordinal;
  final ScenarioOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final Color tone = switch (option.alignment) {
      OptionAlignment.aligned => palette.emeraldText,
      OptionAlignment.partial => palette.amberText,
      OptionAlignment.misaligned => palette.inkSoft,
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 96),
      child: SmoothSurface(
        color: selected ? palette.amberSoft : palette.surface,
        borderColor: selected ? palette.amber : palette.line,
        borderWidth: selected ? 2 : 1,
        radius: AppShapes.radiusLarge,
        elevated: !selected,
        padding: const EdgeInsets.all(18),
        onTap: onTap,
        semanticLabel: selected
            ? 'الخيار $ordinal: ${option.text}. ${option.feedback}'
            : 'الخيار $ordinal: ${option.text}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'الخيار $ordinal',
              style: text.titleSmall?.copyWith(color: palette.amberText, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              option.text,
              style: AppTypography.ui(color: palette.ink, fontSize: 21, height: 1.7, fontWeight: FontWeight.w500),
            ),
            if (selected) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                option.feedback,
                style: AppTypography.ui(color: tone, fontSize: 19, height: 1.7, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.state,
    required this.onPlay,
    required this.onPace,
    required this.onFinish,
    required this.finishLabel,
  });

  final OralState state;
  final VoidCallback onPlay;
  final VoidCallback onPace;
  final VoidCallback? onFinish;
  final String finishLabel;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final String playLabel = state.playing
        ? 'إيقاف'
        : switch (state.step) {
            OralStep.story => 'استمع إلى القصة',
            OralStep.talqin => 'ابدأ الترديد',
            OralStep.dilemma => 'استمع إلى المأزق',
          };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Semantics(
                  button: true,
                  label: playLabel,
                  child: Material(
                    color: state.playing ? palette.amber : palette.ink,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onPlay,
                      child: SizedBox.square(
                        dimension: 96,
                        child: Icon(
                          state.playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                          size: 56,
                          color: palette.paper,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        playLabel,
                        style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: onPace,
                        icon: Icon(
                          state.pace == SpeechPace.slow ? Icons.slow_motion_video_rounded : Icons.timer_outlined,
                        ),
                        label: Text(state.pace == SpeechPace.slow ? 'السرعة: متمهّلة' : 'السرعة: عادية'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            WideActionButton(
              label: finishLabel,
              subtitle: onFinish == null ? 'اختر موقفك في المأزق أولاً' : null,
              icon: Icons.check_rounded,
              tone: WideActionTone.primary,
              giant: true,
              onPressed: onFinish,
            ),
          ],
        ),
      ),
    );
  }
}
