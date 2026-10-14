// اختبار العناصر المضمّنة في النص العربي: المربعات المتجاورة (كلمات مخفية في لوحة التلاشي)
// تُرسم بترتيب القراءة العربي، فالأول على يمين الثاني.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/core/ui/rtl_inline.dart';

void main() {
  testWidgets('adjacent placeholders and words keep right-to-left order', (WidgetTester tester) async {
    final List<InlineSpan> spans = <InlineSpan>[];
    const TextStyle style = TextStyle(fontSize: 20);
    // كلمة، ثم ثلاثة مربعات مخفية متجاورة، ثم كلمة.
    spans.add(const TextSpan(text: 'قَالَ', style: style));
    for (int i = 0; i < 3; i++) {
      spans.add(const TextSpan(text: ' ', style: style));
      addRtlSafePlaceholder(
        spans,
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: SizedBox(key: ValueKey<String>('box-$i'), width: 30, height: 20),
        ),
        style: style,
      );
    }
    spans.add(const TextSpan(text: ' ', style: style));
    spans.add(const TextSpan(text: 'رَسُولُ', style: style));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const <Locale>[Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 400,
              child: Text.rich(TextSpan(children: spans), textDirection: TextDirection.rtl),
            ),
          ),
        ),
      ),
    );
    final List<double> lefts = <double>[
      for (int i = 0; i < 3; i++) tester.getTopLeft(find.byKey(ValueKey<String>('box-$i'))).dx,
    ];
    expect(lefts[0], greaterThan(lefts[1]));
    expect(lefts[1], greaterThan(lefts[2]));
  });
}
