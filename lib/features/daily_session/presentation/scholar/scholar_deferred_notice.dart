// رسالة وقورة تحلّ محل طبقة طالب العلم حين لا تتوفر بياناتها بعد (الأسانيد وتراجم
// الرواة ومقارنة الروايات)، فلا تظهر شاشة فارغة ولا ينهار العرض.

import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

/// نص الرسالة المعتمد.
const String scholarDeferredMessage = 'سند الرواية يتاح في التحديث القادم';

/// الرسالة في وسط المساحة المتاحة.
class ScholarDeferredNotice extends StatelessWidget {
  const ScholarDeferredNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.hourglass_empty_rounded, size: 30, color: palette.amberText),
            const SizedBox(height: 10),
            Text(
              scholarDeferredMessage,
              key: const ValueKey<String>('scholar-deferred-message'),
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(color: palette.ink, height: 1.7),
            ),
          ],
        ),
      ),
    );
  }
}
