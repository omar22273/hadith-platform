// زر مشاركة الحديث: يفتح ورقة سفلية بمعاينة النص المشكول مع تخريجه، وخيارين:
// نسخ إلى الحافظة، أو مشاركة عبر قائمة المشاركة القياسية في النظام.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/share/share_service.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_sheet.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../../hadith/domain/hadith_bundle.dart';
import '../../../hadith/domain/hadith_share_text.dart';

/// الزر.
class ShareHadithButton extends StatelessWidget {
  const ShareHadithButton({super.key, required this.bundle});

  /// الحديث وفهارسه.
  final HadithBundle bundle;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'مشاركة الحديث',
      icon: const Icon(Icons.ios_share_rounded),
      onPressed: () => unawaited(
        showSmoothSheet<void>(
          context: context,
          builder: (BuildContext sheetContext) => ShareHadithSheet(bundle: bundle),
        ),
      ),
    );
  }
}

/// ورقة المشاركة.
class ShareHadithSheet extends ConsumerWidget {
  const ShareHadithSheet({super.key, required this.bundle});

  /// الحديث وفهارسه.
  final HadithBundle bundle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final String shareText = buildHadithShareText(bundle);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);

    Future<void> copy() async {
      await Clipboard.setData(ClipboardData(text: shareText));
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('نُسخ الحديث مع تخريجه إلى الحافظة')));
    }

    Future<void> share() async {
      try {
        await ref.read(shareServiceProvider).shareText(shareText, subject: bundle.hadith.title);
        navigator.pop();
      } on Object {
        // تعذر فتح قائمة المشاركة: نسقط إلى النسخ فلا يضيع على المستخدم شيء.
        await copy();
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('مشاركة الحديث', style: AppTypography.heritageTitle(color: palette.ink, fontSize: 24)),
        const SizedBox(height: 10),
        SmoothSurface(
          color: palette.surfaceMuted,
          borderColor: palette.line,
          radius: AppShapes.radiusMedium,
          padding: const EdgeInsets.all(14),
          child: Text(
            shareText,
            style: text.bodyMedium?.copyWith(color: palette.ink, height: 1.9),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => unawaited(copy()),
                icon: const Icon(Icons.copy_rounded),
                label: const Text('نسخ'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => unawaited(share()),
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('مشاركة'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
