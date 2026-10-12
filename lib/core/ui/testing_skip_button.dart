// زر «تجاوز للاختبار ⚡»: يظهر في شاشتي ترتيب المتن حين يكون وضع التجربة
// («تخطي قفل الفجر دائماً» في الإعدادات) مفعّلاً. يرتّب كل العبارات ترتيباً
// صحيحاً ويفتح «التالي» فوراً، لمعاينة بقية الشاشات دون إهدار وقت. المتحكمات
// تعيد التحقق من تفعيل وضع التجربة بنفسها، فلا يعمل الزر بدونه.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'app_shapes.dart';

/// الزر.
class TestingSkipButton extends StatelessWidget {
  const TestingSkipButton({super.key, required this.onPressed});

  /// ما يُنفَّذ عند اللمس.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: OutlinedButton.icon(
        key: const ValueKey<String>('testing-skip'),
        onPressed: () {
          HapticFeedback.mediumImpact();
          onPressed();
        },
        icon: const Icon(Icons.bolt_rounded),
        label: const Text('تجاوز للاختبار ⚡'),
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.amberText,
          backgroundColor: palette.amberSoft,
          side: BorderSide(color: palette.amber),
          shape: AppShapes.rounded(AppShapes.radiusSmall),
          textStyle: AppTypography.ui(color: palette.amberText, fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
