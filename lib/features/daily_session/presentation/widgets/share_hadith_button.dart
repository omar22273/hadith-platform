// زر مشاركة الحديث: يفتح ورقة سفلية بمعاينة بطاقة الاقتباس المشكولة، وخيارات:
// نسخ النص مع تخريجه، أو مشاركة البطاقة صورةً (PNG عالية الدقة) إلى تطبيقات
// المراسلة، أو مشاركة النص عبر قائمة المشاركة القياسية.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/share/png_capture.dart';
import '../../../../core/share/share_service.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/smooth_sheet.dart';
import '../../../hadith/domain/hadith_bundle.dart';
import '../../../hadith/domain/hadith_share_text.dart';
import 'hadith_quote_card.dart';

/// دقة التقاط الصورة بالنسبة إلى العرض المنطقي للبطاقة (٣٦٠ → ١٠٨٠ بكسل).
const double hadithImagePixelRatio = 3;

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
class ShareHadithSheet extends ConsumerStatefulWidget {
  const ShareHadithSheet({super.key, required this.bundle});

  /// الحديث وفهارسه.
  final HadithBundle bundle;

  @override
  ConsumerState<ShareHadithSheet> createState() => _ShareHadithSheetState();
}

class _ShareHadithSheetState extends ConsumerState<ShareHadithSheet> {
  final GlobalKey _cardKey = GlobalKey(debugLabel: 'hadith-quote-card');
  bool _busy = false;
  String? _error;

  String get _shareText => buildHadithShareText(widget.bundle);

  Future<void> _copy() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    await Clipboard.setData(ClipboardData(text: _shareText));
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('نُسخ الحديث مع تخريجه إلى الحافظة')));
  }

  Future<void> _shareAsText() async {
    final NavigatorState navigator = Navigator.of(context);
    try {
      await ref.read(shareServiceProvider).shareText(_shareText, subject: widget.bundle.hadith.title);
      navigator.pop();
    } on Object {
      // تعذر فتح قائمة المشاركة: نسقط إلى النسخ فلا يضيع على المستخدم شيء.
      await _copy();
    }
  }

  Future<void> _shareImage() async {
    if (_busy) {
      return;
    }
    final NavigatorState navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final List<int> png = await captureBoundaryPng(_cardKey, pixelRatio: hadithImagePixelRatio);
      await ref.read(shareServiceProvider).shareFile(
            bytes: png,
            fileName: '${widget.bundle.hadith.id}.png',
            mimeType: 'image/png',
            subject: widget.bundle.hadith.title,
          );
      navigator.pop();
    } on Object {
      if (mounted) {
        setState(() => _error = 'تعذّر إنشاء الصورة. يمكنك مشاركة الحديث نصاً أو نسخه.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('مشاركة الحديث', style: AppTypography.heritageTitle(color: palette.ink, fontSize: 24)),
        const SizedBox(height: 10),
        // المعاينة هي البطاقة نفسها التي تُلتقط صورةً: ما تراه هو ما يُرسل.
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: RepaintBoundary(
              key: _cardKey,
              child: HadithQuoteCard(bundle: widget.bundle),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => unawaited(_copy()),
                icon: const Icon(Icons.copy_rounded),
                label: const Text('نسخ'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                key: const ValueKey<String>('share-as-image'),
                onPressed: _busy ? null : () => unawaited(_shareImage()),
                icon: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4))
                    : const Icon(Icons.image_outlined),
                label: const Text('مشاركة كصورة'),
              ),
            ),
          ],
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            _error!,
            key: const ValueKey<String>('share-image-error'),
            textAlign: TextAlign.center,
            style: AppTypography.ui(color: palette.amberText, fontSize: 13, height: 1.6),
          ),
        ],
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: _busy ? null : () => unawaited(_shareAsText()),
          icon: const Icon(Icons.ios_share_rounded),
          label: const Text('مشاركة كنص'),
        ),
      ],
    );
  }
}
