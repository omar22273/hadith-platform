// زر «التالي ←» المقفل بالإنجاز: رمادي باهت معطّل (onPressed: null) ما لم يتحقق
// الشرط، فإذا تحقق تحوّل فوراً إلى زر زمردي عريض بارز. لا يوجد مسار لتفعيله
// دون تحقق الشرط؛ والمتحكمات تعيد التحقق بنفسها قبل أي انتقال.

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'app_shapes.dart';

/// زر انتقال مقفل حتى الإنجاز.
class GatedNextButton extends StatelessWidget {
  const GatedNextButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.buttonKey,
  });

  /// نص الزر.
  final String label;

  /// هل تحقق شرط الإنجاز.
  final bool enabled;

  /// الانتقال؛ لا يُربط بالزر إلا إذا كان [enabled].
  final VoidCallback onPressed;

  /// مفتاح الزر نفسه، لتمييزه في الاختبارات.
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Duration duration =
        MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 260);
    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOutCubic,
      width: double.infinity,
      height: enabled ? 62 : 50,
      child: FilledButton(
        key: buttonKey,
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
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 10),
            // arrow_forward ينعكس تلقائياً في الاتجاه من اليمين فيشير إلى اليسار «←».
            Icon(Icons.arrow_forward_rounded, size: enabled ? 26 : 20),
          ],
        ),
      ),
    );
  }
}
