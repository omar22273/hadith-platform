// شريط التلاوة تحت المتن: زر الاستماع، ومؤشر دائري لطيف أثناء جلب المقطع من
// شبكة التوزيع أو تخزينه مؤقتاً، ورسالة هادئة مع إعادة المحاولة عند انتهاء
// المهلة أو تعذر الاتصال.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_player_service.dart';
import '../../../core/theme/app_palette.dart';
import '../application/recitation_controller.dart';

/// الشريط.
class RecitationBar extends ConsumerWidget {
  const RecitationBar({super.key, required this.hadithId});

  /// الحديث.
  final String hadithId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final RecitationState recitation = ref.watch(recitationControllerProvider(hadithId));
    final RecitationController controller = ref.read(recitationControllerProvider(hadithId).notifier);

    if (!recitation.canPlay) {
      return Row(
        children: <Widget>[
          Icon(Icons.mic_none_rounded, size: 18, color: palette.inkSoft),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'التلاوة المتقنة قيد التسجيل بصوت قارئ؛ ولا يُقرأ المتن بصوت آلي.',
              style: text.labelSmall?.copyWith(color: palette.inkSoft),
            ),
          ),
        ],
      );
    }

    final AudioFailureKind? failure = recitation.failure;
    if (failure != null) {
      return Row(
        children: <Widget>[
          Icon(
            failure == AudioFailureKind.timeout ? Icons.timer_off_outlined : Icons.cloud_off_rounded,
            size: 20,
            color: palette.amberText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              failure == AudioFailureKind.timeout
                  ? 'انتهت مهلة جلب التلاوة؛ الاتصال بطيء أو منقطع.'
                  : 'تعذّر الوصول إلى خادم التلاوات الآن.',
              style: text.labelSmall?.copyWith(color: palette.ink),
            ),
          ),
          TextButton.icon(
            onPressed: () => unawaited(controller.retry()),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('أعد المحاولة'),
          ),
        ],
      );
    }

    final bool busy = recitation.isBusy;
    return Row(
      children: <Widget>[
        FilledButton.icon(
          onPressed: busy && !recitation.playing
              ? null
              : () {
                  if (recitation.playing) {
                    unawaited(controller.stop());
                  } else {
                    unawaited(controller.playAll());
                  }
                },
          icon: busy
              ? SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: palette.amber),
                )
              : Icon(recitation.playing ? Icons.stop_rounded : Icons.volume_up_rounded),
          label: Text(
            recitation.phase == AudioPhase.loading
                ? 'جارٍ جلب التلاوة…'
                : recitation.phase == AudioPhase.buffering
                    ? 'تخزين مؤقت…'
                    : (recitation.playing ? 'إيقاف' : 'استمع إلى التلاوة'),
          ),
        ),
        const SizedBox(width: 10),
        if (recitation.reciter != null)
          Expanded(
            child: Text(
              'بصوت ${recitation.reciter}',
              style: text.labelSmall?.copyWith(color: palette.inkSoft),
            ),
          ),
      ],
    );
  }
}
