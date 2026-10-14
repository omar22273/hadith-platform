// اختبارات اتجاه رسم المتن: العربية تُقرأ من اليمين إلى اليسار، فالكلمة الأولى في السطر
// يجب أن تقع على يمين الكلمة التي تليها، بما فيها الألفاظ الغريبة المظللة المتتابعة
// (مثل «ما يريبك» في الحديث 11 و«فأنى يستجاب له» في الحديث 10).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/core/theme/app_theme.dart';
import 'package:hadith_platform/features/daily_session/presentation/widgets/matn_text.dart';
import 'package:hadith_platform/features/hadith/data/models/models.dart';

HadithDailyModel _hadith(int number) {
  final String path = 'assets/data/hadith/nawawi40/nawawi40_${number.toString().padLeft(3, '0')}.json';
  return HadithDailyModel.fromJson(asJsonMap(jsonDecode(File(path).readAsStringSync()), path));
}

Future<void> _pump(
  WidgetTester tester,
  Matn matn,
  double width, {
  bool withGharib = true,
  ValueChanged<String>? onTap,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('ar'),
      supportedLocales: const <Locale>[Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            child: MatnText(matn: matn, onGharibTap: withGharib ? (onTap ?? (String id) {}) : null),
          ),
        ),
      ),
    ),
  );
}

/// مستطيل كل كلمة من الفقرة بترتيب ورودها المنطقي (الكلمات تفصلها مسافات).
List<Rect> _wordRects(WidgetTester tester) {
  final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: find.byType(MatnText), matching: find.byType(RichText)).first,
  );
  final String plain = paragraph.text.toPlainText();
  final List<Rect> rects = <Rect>[];
  int start = 0;
  for (final String word in plain.split(' ')) {
    final List<TextBox> boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: start + word.length),
    );
    expect(boxes, isNotEmpty, reason: 'no box for word "$word"');
    Rect rect = boxes.first.toRect();
    for (final TextBox box in boxes.skip(1)) {
      rect = rect.expandToInclude(box.toRect());
    }
    rects.add(rect);
    start += word.length + 1;
  }
  return rects;
}

bool _sameLine(Rect a, Rect b) => (a.center.dy - b.center.dy).abs() < a.height / 2;

void main() {
  testWidgets('hadith 11: «مَا» sits to the right of «يَرِيبُكَ», as an Arabic reader expects', (WidgetTester tester) async {
    final HadithDailyModel hadith = _hadith(11);
    await _pump(tester, hadith.matn, 380);
    final List<MatnToken> tokens = <MatnToken>[for (final MatnSegment s in hadith.matn.segments) ...s.tokens];
    final List<Rect> rects = _wordRects(tester);
    expect(rects.length, tokens.length);
    // دَعْ مَا يَرِيبُكَ إِلَى مَا لَا يَرِيبُكَ
    final int ma = tokens.indexWhere((MatnToken t) => t.core == 'مَا');
    expect(ma, greaterThanOrEqualTo(1));
    expect(tokens[ma - 1].core, 'دَعْ');
    expect(tokens[ma + 1].core, 'يَرِيبُكَ');
    expect(_sameLine(rects[ma], rects[ma + 1]), isTrue);
    expect(rects[ma].left, greaterThan(rects[ma + 1].left), reason: '«مَا» must be right of «يَرِيبُكَ»');
    if (_sameLine(rects[ma - 1], rects[ma])) {
      expect(rects[ma - 1].left, greaterThan(rects[ma].left), reason: '«دَعْ» is right of «مَا»');
    }
    for (int i = 0; i + 1 < rects.length; i++) {
      if (_sameLine(rects[i], rects[i + 1])) {
        expect(rects[i].left, greaterThan(rects[i + 1].left), reason: 'word $i (${tokens[i].core}) must be right of word ${i + 1}');
      } else {
        expect(rects[i + 1].top, greaterThan(rects[i].top), reason: 'word ${i + 1} wraps below word $i');
      }
    }
  });

  testWidgets('hadith 10: «فَأَنَّى» is right of «يُسْتَجَابُ»', (WidgetTester tester) async {
    final HadithDailyModel hadith = _hadith(10);
    await _pump(tester, hadith.matn, 380);
    final List<MatnToken> tokens = <MatnToken>[for (final MatnSegment s in hadith.matn.segments) ...s.tokens];
    final List<Rect> rects = _wordRects(tester);
    final int first = tokens.indexWhere((MatnToken t) => t.core.contains('فَأَنَّى'));
    expect(first, greaterThanOrEqualTo(0));
    expect(tokens[first + 1].core, contains('يُسْتَجَابُ'));
    if (_sameLine(rects[first], rects[first + 1])) {
      expect(rects[first].left, greaterThan(rects[first + 1].left));
    }
  });

  testWidgets('touching a highlighted gharib word, including the joining space, reports that word', (WidgetTester tester) async {
    final HadithDailyModel hadith = _hadith(11);
    final List<String> taps = <String>[];
    await _pump(tester, hadith.matn, 380, onTap: taps.add);
    final List<Rect> rects = _wordRects(tester);
    final Offset origin = tester.getTopLeft(
      find.descendant(of: find.byType(MatnText), matching: find.byType(RichText)).first,
    );
    for (final GharibEntry entry in hadith.matn.gharib) {
      int offset = 0;
      for (final MatnSegment segment in hadith.matn.segments) {
        if (segment.id == entry.anchor.segmentId) {
          break;
        }
        offset += segment.tokens.length;
      }
      final Rect word = rects[offset + entry.anchor.tokenIndex];
      await tester.tapAt(origin + word.center);
      await tester.pump();
      expect(taps.last, entry.id, reason: entry.headword);
    }
    expect(taps.length, hadith.matn.gharib.length);
  });

  for (final double width in <double>[300, 380]) {
    testWidgets('all 42 hadiths flow right-to-left at width $width, gharib words included', (WidgetTester tester) async {
      for (int number = 1; number <= 42; number++) {
        final HadithDailyModel hadith = _hadith(number);
        await _pump(tester, hadith.matn, width);
        final List<MatnToken> tokens = <MatnToken>[for (final MatnSegment s in hadith.matn.segments) ...s.tokens];
        final List<Rect> rects = _wordRects(tester);
        expect(rects.length, tokens.length, reason: 'hadith $number');
        for (int i = 0; i + 1 < rects.length; i++) {
          if (_sameLine(rects[i], rects[i + 1])) {
            expect(
              rects[i].left,
              greaterThan(rects[i + 1].left),
              reason: 'hadith $number: word $i (${tokens[i].core}) must be right of word ${i + 1} (${tokens[i + 1].core})',
            );
          }
        }
      }
    });
  }
}
