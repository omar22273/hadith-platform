// شاشة دورة الوِرد اليومي ذات المراحل الأربع. التنقل بين المراحل بمحرك
// PageView يقوده متحكم Riverpod: المتحكم يملك المرحلة، والصفحات تتبعه.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../hadith/application/content_providers.dart';
import '../../hadith/domain/content_repository.dart';
import '../../hadith/domain/hadith_bundle.dart';
import '../application/session_controller.dart';
import '../application/session_state.dart';
import 'scholar/scholar_layer_view.dart';
import 'stages/context_stage.dart';
import 'stages/matn_stage.dart';
import 'stages/practice_stage.dart';
import 'stages/reflection_stage.dart';
import 'widgets/closing_view.dart';
import 'widgets/session_header.dart';

/// شاشة الوِرد.
class DailyHadithSessionScreen extends ConsumerStatefulWidget {
  const DailyHadithSessionScreen({
    super.key,
    required this.hadithId,
    required this.countsTowardJourney,
  });

  /// الحديث.
  final String hadithId;

  /// هل هو وِرد اليوم (يُسجَّل في المسار) أم مراجعة.
  final bool countsTowardJourney;

  @override
  ConsumerState<DailyHadithSessionScreen> createState() => _DailyHadithSessionScreenState();
}

class _DailyHadithSessionScreenState extends ConsumerState<DailyHadithSessionScreen> {
  final PageController _pages = PageController();
  bool _finishing = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _syncPage(SessionStage? previous, SessionStage next) {
    if (!_pages.hasClients) {
      return;
    }
    final int target = next.index;
    if ((_pages.page ?? 0).round() == target) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(target);
    } else {
      unawaited(
        _pages.animateToPage(
          target,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOutCubic,
        ),
      );
    }
  }

  Future<void> _finish() async {
    if (_finishing) {
      return;
    }
    setState(() => _finishing = true);
    try {
      await ref
          .read(sessionControllerProvider(widget.hadithId).notifier)
          .finish(countsTowardJourney: widget.countsTowardJourney);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر حفظ إتمام الوِرد على الجهاز. حاول مرة أخرى.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _finishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<HadithBundle> bundle = ref.watch(hadithBundleProvider(widget.hadithId));
    return Scaffold(
      body: SafeArea(
        child: bundle.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stackTrace) => _SessionError(error: error),
          data: _buildSession,
        ),
      ),
    );
  }

  Widget _buildSession(HadithBundle bundle) {
    final AppPalette palette = AppPalette.of(context);
    final SessionState state = ref.watch(sessionControllerProvider(widget.hadithId));
    final SessionController controller = ref.read(sessionControllerProvider(widget.hadithId).notifier);
    ref.listen<SessionStage>(
      sessionControllerProvider(widget.hadithId).select((SessionState s) => s.stage),
      _syncPage,
    );

    if (state.finished) {
      return ClosingView(
        hadithId: widget.hadithId,
        countedTowardJourney: widget.countsTowardJourney,
        onBack: () => Navigator.of(context).maybePop(),
      );
    }

    final bool lastStage = state.stage == SessionStage.reflection;
    final bool canFinish = state.chosenOptionId != null && !_finishing;
    return Column(
      children: <Widget>[
        SessionHeader(
          bundle: bundle,
          state: state,
          isReview: !widget.countsTowardJourney,
          onBack: () => Navigator.of(context).maybePop(),
          onToggleScholar: controller.toggleScholarLayer,
          onStageTap: controller.goTo,
        ),
        Expanded(
          // تبقى صفحات المراحل حية تحت طبقة طالب العلم، فيعود المستخدم إلى مرحلته نفسها.
          child: IndexedStack(
            index: state.scholarLayerOpen ? 1 : 0,
            children: <Widget>[
              PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                children: <Widget>[
                  ContextStage(bundle: bundle),
                  MatnStage(bundle: bundle),
                  PracticeStage(hadithId: widget.hadithId),
                  ReflectionStage(bundle: bundle),
                ],
              ),
              if (state.scholarLayerOpen) ScholarLayerView(bundle: bundle) else const SizedBox.shrink(),
            ],
          ),
        ),
        if (!state.scholarLayerOpen)
          DecoratedBox(
            decoration: BoxDecoration(
              color: palette.paper,
              border: Border(top: BorderSide(color: palette.line)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: state.stage.index == 0 ? null : controller.previous,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('السابق'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: lastStage
                        ? FilledButton.icon(
                            onPressed: canFinish ? _finish : null,
                            icon: _finishing
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.check_rounded),
                            label: Text(
                              state.chosenOptionId == null
                                  ? 'اختر موقفك لإتمام الوِرد'
                                  : (widget.countsTowardJourney ? 'إتمام الوِرد' : 'إنهاء المراجعة'),
                            ),
                          )
                        : FilledButton.icon(
                            onPressed: controller.next,
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: Text('التالي: ${SessionStage.values[state.stage.index + 1].title}'),
                          ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SessionError extends StatelessWidget {
  const _SessionError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final String detail = switch (error) {
      ContentIntegrityException(:final List<String> issues) => issues.join('\n'),
      UnknownHadithException(:final String hadithId) => 'الحديث $hadithId ليس في المنهج.',
      _ => error.toString(),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.fact_check_outlined, size: 44, color: palette.inkSoft),
            const SizedBox(height: 12),
            Text('لم يُعرض الوِرد', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'كشف فحص السلامة خللاً في البيانات، فلم يُعرض شيء منها حتى يُصحح.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: palette.inkSoft),
            ),
            const SizedBox(height: 10),
            SelectableText(
              detail,
              textAlign: TextAlign.center,
              style: text.labelSmall?.copyWith(color: palette.inkSoft),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('العودة'),
            ),
          ],
        ),
      ),
    );
  }
}
