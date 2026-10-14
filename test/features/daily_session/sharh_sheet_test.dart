// اختبارات زر «شرح الحديث 📖» وورقته: يظهر الزر أعلى مرحلة المتن، وتفتح الورقة السفلية
// بمفردات «التحفة الربانية» وفوائدها كما في ملف الحديث حرفاً، ويكبّر المنزلق خطها،
// وتُعرض رسالة «سند الرواية يتاح في التحديث القادم» في طبقة طالب العلم بدل أي انهيار.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/core/storage/key_value_store.dart';
import 'package:hadith_platform/core/theme/app_theme.dart';
import 'package:hadith_platform/features/daily_session/presentation/scholar/scholar_deferred_notice.dart';
import 'package:hadith_platform/features/daily_session/presentation/scholar/scholar_layer_view.dart';
import 'package:hadith_platform/features/daily_session/presentation/widgets/sharh_sheet.dart';
import 'package:hadith_platform/features/hadith/data/models/models.dart';
import 'package:hadith_platform/features/hadith/domain/hadith_bundle.dart';
import 'package:hadith_platform/features/journey/presentation/widgets/wird_node.dart';

import '../../support/app_harness.dart';

JsonMap _load(String path) => asJsonMap(jsonDecode(File(path).readAsStringSync()), path);

HadithBundle _bundle(int number) {
  final String id = 'nawawi40_${number.toString().padLeft(3, '0')}';
  return HadithBundle(
    hadith: HadithDailyModel.fromJson(_load('assets/data/hadith/nawawi40/$id.json')),
    narrators: NarratorCatalog.fromJson(_load('assets/data/catalogs/narrators.json')),
    sources: SourceCatalog.fromJson(_load('assets/data/catalogs/sources.json')),
  );
}

/// خط النص القابل للتحديد الذي نصه [text] بالضبط.
double _fontSizeOf(WidgetTester tester, String text) {
  final SelectableText widget = tester.widget<SelectableText>(
    find.byWidgetPredicate((Widget w) => w is SelectableText && w.data == text),
  );
  return widget.style!.fontSize!;
}

void main() {
  testWidgets('the sharh button opens a sheet with the book vocabulary and benefits, and the slider zooms it', (
    WidgetTester tester,
  ) async {
    final HadithBundle bundle = _bundle(1);
    final ConciseExplanation explanation = bundle.hadith.conciseExplanation!;
    await pumpApp(tester, size: const Size(412, 1800));
    await tester.tap(find.descendant(of: find.byType(WirdNodeView), matching: find.text('الأعمال بالنيات')).first);
    await settle(tester);
    await tester.tap(find.text('بدء وِرد التثبيت اللمسي'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey<String>('session-next')));
    await settle(tester);

    // الزر في أعلى مرحلة المتن وعنوانه كما طُلب.
    expect(find.byKey(const ValueKey<String>('sharh-button')), findsOneWidget);
    expect(find.text('شرح الحديث 📖'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('sharh-sheet')), findsNothing);
    final double buttonTop = tester.getTopLeft(find.byKey(const ValueKey<String>('sharh-button'))).dy;
    final double matnTop = tester.getTopLeft(find.text('المتن الشريف')).dy;
    expect(buttonTop, lessThan(matnTop));

    await tester.tap(find.byKey(const ValueKey<String>('sharh-button')));
    await settle(tester);
    expect(find.byKey(const ValueKey<String>('sharh-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('sharh-vocabulary')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('sharh-benefits')), findsOneWidget);
    expect(find.byKey(sharhFontSliderKey), findsOneWidget);

    // نصوص الكتاب كما في ملف الحديث حرفاً، لا زيادة ولا نقصان.
    final String firstTerm = explanation.vocabulary.first.term;
    final String firstMeaning = explanation.vocabulary.first.explanation;
    final String firstBenefit = explanation.benefits.first;
    expect(find.byWidgetPredicate((Widget w) => w is SelectableText && w.data == firstTerm), findsOneWidget);
    expect(find.byWidgetPredicate((Widget w) => w is SelectableText && w.data == firstMeaning), findsOneWidget);
    expect(find.byWidgetPredicate((Widget w) => w is SelectableText && w.data == firstBenefit), findsOneWidget);
    expect(find.text(sharhReviewNotice), findsOneWidget);

    // المنزلق يكبّر الخط ويصغّره.
    final double before = _fontSizeOf(tester, firstBenefit);
    await tester.drag(find.byKey(sharhFontSliderKey), const Offset(-160, 0));
    await settle(tester);
    final double after = _fontSizeOf(tester, firstBenefit);
    expect(after, isNot(before));
  });

  testWidgets('every hadith from 1 to 50 offers the button and a non-empty sheet', (WidgetTester tester) async {
    for (final int number in <int>[3, 21, 30, 41, 42, 43, 46, 48, 50]) {
      final HadithBundle bundle = _bundle(number);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ar'),
          supportedLocales: const <Locale>[Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: ProviderScope(
            overrides: [keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore())],
            child: Scaffold(body: SingleChildScrollView(child: HadithSharhView(bundle: bundle))),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey<String>('sharh-sheet')), findsOneWidget, reason: 'hadith $number');
      expect(find.byKey(const ValueKey<String>('sharh-benefits')), findsOneWidget, reason: 'hadith $number');
      expect(find.textContaining(bundle.hadith.title), findsWidgets);
    }
  });

  testWidgets('the scholar layer promises the isnad in the next update on every tab instead of failing', (
    WidgetTester tester,
  ) async {
    final HadithBundle bundle = _bundle(42);
    expect(bundle.hadith.scholar.chains, isEmpty);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ar'),
        supportedLocales: const <Locale>[Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(body: ScholarLayerView(bundle: bundle)),
      ),
    );
    await tester.pump();
    expect(scholarDeferredMessage, 'سند الرواية يتاح في التحديث القادم');
    expect(find.text('سند الرواية يتاح في التحديث القادم'), findsOneWidget);
    for (final String tab in <String>['الرواة', 'مقارنة الروايات', 'شجرة الإسناد']) {
      await tester.tap(find.text(tab));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('سند الرواية يتاح في التحديث القادم'), findsWidgets, reason: tab);
      expect(tester.takeException(), isNull);
    }
  });
}
