// اختبارات وِرد الأذكار: سلامة بيانات البذرة وأن نصها وفضلها جزء حرفي من
// شواهدها، ومتحكم العدّ والقفل النهائي والانتقال التلقائي، والشاشة الهادئة:
// رأس بلا شرائح وشريط تقدم رفيع، وسحب أفقي بين الأذكار، ونصف سفلي يحتسب أي
// نقرة باهتزاز خفيف، واهتزاز مزدوج وهالة خضراء وقفل وانتقال تلقائي عند بلوغ
// العدد المسنون، وورقة التخريج والفضل والمصدر، ثم شارة إتمام الوِرد.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/app/app_shell_screen.dart';
import 'package:hadith_platform/core/content/models/content_models.dart';
import 'package:hadith_platform/core/json/json_reader.dart';
import 'package:hadith_platform/core/theme/feedback_colors.dart';
import 'package:hadith_platform/features/adhkar/application/adhkar_providers.dart';
import 'package:hadith_platform/features/adhkar/application/adhkar_wird_controller.dart';
import 'package:hadith_platform/features/adhkar/data/models/adhkar.dart';
import 'package:hadith_platform/features/adhkar/domain/adhkar_integrity.dart';
import 'package:hadith_platform/features/adhkar/presentation/adhkar_screen.dart';
import 'package:smooth_corner/smooth_corner.dart';

import '../../support/app_harness.dart';

JsonMap _load(String path) => asJsonMap(jsonDecode(File(path).readAsStringSync()), path);

/// يسجل كل اهتزاز بنوعه.
List<String> _recordHaptics(WidgetTester tester) {
  final List<String> haptics = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
    if (call.method == 'HapticFeedback.vibrate') {
      haptics.add(call.arguments as String);
    }
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return haptics;
}

Finder _navLabel(String label) {
  return find.descendant(of: find.byType(AppBottomBar), matching: find.text(label));
}

/// موضع الذكر في الرأس، مثل «١ / ٢».
String _progress(WidgetTester tester) {
  return tester.widget<Text>(find.byKey(const ValueKey<String>('adhkar-progress'))).data!;
}

/// عنوان الذكر الحالي في الرأس.
String _title(WidgetTester tester) {
  return tester.widget<Text>(find.byKey(const ValueKey<String>('adhkar-title'))).data!;
}

/// متحكم صفحات الأذكار.
PageController _pages(WidgetTester tester) {
  return tester.widget<PageView>(find.byKey(const ValueKey<String>('adhkar-pages'))).controller!;
}

/// يسحب الصفحة أفقياً. الواجهة من اليمين إلى اليسار: صفحة الذكر التالي عن
/// يسار الحالية، فيكون السحب إليها بإصبع يتحرك نحو اليمين.
Future<void> _swipe(WidgetTester tester, {required bool toNext}) async {
  await tester.drag(find.byKey(const ValueKey<String>('adhkar-pages')), Offset(toNext ? 320 : -320, 0));
  await settle(tester);
}

const String _firstId = 'sayyid_al_istighfar';
const String _secondId = 'tasbih_dubur_al_salah';

Finder _zone(String id) => find.byKey(ValueKey<String>('dhikr-tap-zone-$id'));

/// يفتح تبويب الأذكار ويعيد الحاوية.
Future<ProviderContainer> _openAdhkar(WidgetTester tester, {Size size = const Size(412, 2200)}) async {
  final ProviderContainer container = await pumpApp(tester, size: size);
  await tester.tap(_navLabel('وِرد الأذكار'));
  await settle(tester);
  await container.read(adhkarCatalogProvider.future);
  await settle(tester);
  return container;
}

void main() {
  final JsonMap raw = _load('assets/data/adhkar/adhkar_catalog.json');
  final AdhkarCatalog catalog = AdhkarCatalog.fromJson(raw);
  final SourceCatalog sources = SourceCatalog.fromJson(_load('assets/data/catalogs/sources.json'));

  group('the seed data', () {
    test('holds exactly the two requested adhkar with their prophetic counts', () {
      final List<DhikrItem> items = catalog.itemsInOrder;
      expect(items.map((DhikrItem i) => i.id).toList(), <String>['sayyid_al_istighfar', 'tasbih_dubur_al_salah']);
      expect(items.map((DhikrItem i) => i.count).toList(), <int>[1, 33]);
      expect(items.map((DhikrItem i) => i.order).toList(), <int>[1, 2]);
    });

    test('round-trips and passes the integrity checks against the source catalog', () {
      expect(catalog.toJson(), equals(raw));
      expect(checkAdhkarCatalog(catalog, sources: sources), isEmpty);
    });

    test('every dhikr text is a verbatim part of one of its evidence quotes, each with a locator', () {
      for (final DhikrItem item in catalog.items) {
        expect(item.evidence.any((SourceRef r) => (r.quote ?? '').contains(item.text)), isTrue, reason: item.id);
        for (final SourceRef reference in item.evidence) {
          expect(reference.quote?.trim(), isNotEmpty);
          expect(reference.locator?.trim(), isNotEmpty);
          expect(sources.byId(reference.sourceId), isNotNull, reason: reference.sourceId);
        }
        expect(item.review.status, ReviewStatus.pendingScholarlyReview);
        // نص كامل التشكيل: لا كلمة عربية بلا حركة سوى الحروف المفردة.
        expect(RegExp('[ً-ْ]').hasMatch(item.text), isTrue, reason: item.id);
      }
    });

    test('every dhikr carries a virtue that is a verbatim part of one of its evidence quotes', () {
      for (final DhikrItem item in catalog.items) {
        final String? virtue = item.virtue;
        expect(virtue, isNotNull, reason: item.id);
        expect(virtue!.trim(), isNotEmpty, reason: item.id);
        expect(item.evidence.any((SourceRef r) => (r.quote ?? '').contains(virtue)), isTrue, reason: item.id);
        expect(RegExp('[ً-ْ]').hasMatch(virtue), isTrue, reason: 'vocalized: ${item.id}');
      }
    });

    test('a virtue that is blank or not in the quotes is rejected', () {
      final DhikrItem first = catalog.items.first;
      AdhkarCatalog withVirtue(String virtue) => AdhkarCatalog(
            schemaVersion: catalog.schemaVersion,
            id: catalog.id,
            title: catalog.title,
            items: <DhikrItem>[
              DhikrItem.fromJson(<String, dynamic>{...first.toJson(), 'virtue': virtue}),
            ],
          );
      expect(checkAdhkarCatalog(withVirtue('فضل لا أصل له في الشاهد'), sources: sources), contains(contains('virtue')));
      expect(checkAdhkarCatalog(withVirtue('   '), sources: sources), contains(contains('virtue')));
    });

    test('a dhikr whose text is not in its quotes, or a duplicate id, or a bad count, is rejected', () {
      final DhikrItem first = catalog.items.first;
      DhikrItem edited({String? text, int? count, String? id}) {
        return DhikrItem.fromJson(<String, dynamic>{
          ...first.toJson(),
          if (text != null) 'text': text,
          if (count != null) 'count': count,
          if (id != null) 'id': id,
        });
      }

      AdhkarCatalog withItems(List<DhikrItem> items) => AdhkarCatalog(
            schemaVersion: catalog.schemaVersion,
            id: catalog.id,
            title: catalog.title,
            items: items,
          );

      expect(checkAdhkarCatalog(withItems(<DhikrItem>[edited(text: 'نص لا أصل له في الشاهد')]), sources: sources),
          contains(contains('verbatim part')));
      expect(checkAdhkarCatalog(withItems(<DhikrItem>[first, first]), sources: sources), contains(contains('Duplicate')));
      expect(checkAdhkarCatalog(withItems(<DhikrItem>[edited(count: 0)]), sources: sources), contains(contains('count')));
    });

    test('the JSON schema covers the adhkar catalog', () {
      final JsonMap schema = _load('assets/data/schema/hadith_platform.schema.json');
      final JsonMap defs = asJsonMap(schema['\$defs'], 'defs');
      expect(defs.containsKey('AdhkarCatalog'), isTrue);
      expect(defs.containsKey('DhikrItem'), isTrue);
    });
  });

  group('the wird controller', () {
    testWidgets('counts to the prophetic number, then locks permanently and advances on its own', (WidgetTester tester) async {
      final ProviderContainer container = await _openAdhkar(tester);
      final AdhkarWirdController wird = container.read(adhkarWirdProvider.notifier);
      expect(container.read(adhkarWirdProvider).index, 0);

      // الذكر الأول عدده واحد: أول لمسة تكمله وتقفله.
      expect(wird.tap(), DhikrTapResult.completed);
      expect(container.read(adhkarWirdProvider).countOf(0), 1);
      for (int i = 0; i < 5; i++) {
        expect(wird.tap(), DhikrTapResult.locked);
      }
      expect(container.read(adhkarWirdProvider).countOf(0), 1, reason: 'never exceeds the prophetic count');

      // قبل انقضاء المهلة يبقى على الذكر المكتمل، ثم ينتقل إلى الثاني وحده.
      await tester.pump(const Duration(milliseconds: 500));
      expect(container.read(adhkarWirdProvider).index, 0);
      await tester.pump(const Duration(milliseconds: 1200));
      expect(container.read(adhkarWirdProvider).index, 1);

      // الذكر الثاني ثلاث وثلاثون: 32 احتساب ثم إكمال في الثالثة والثلاثين.
      for (int i = 0; i < 32; i++) {
        expect(wird.tap(), DhikrTapResult.counted, reason: 'tap ${i + 1}');
      }
      expect(container.read(adhkarWirdProvider).isComplete(container.read(adhkarItemsProvider)), isFalse);
      expect(wird.tap(), DhikrTapResult.completed);
      expect(wird.tap(), DhikrTapResult.locked);
      expect(container.read(adhkarWirdProvider).countOf(1), 33);
      expect(container.read(adhkarWirdProvider).isComplete(container.read(adhkarItemsProvider)), isTrue);

      // الوِرد كله مكتمل فلا انتقال بعده، ويبقى على الذكر الأخير.
      await tester.pump(const Duration(seconds: 2));
      expect(container.read(adhkarWirdProvider).index, 1);

      // وِرد جديد يعيد كل شيء إلى الصفر ويفك القفل.
      wird.restart();
      expect(container.read(adhkarWirdProvider).index, 0);
      expect(container.read(adhkarWirdProvider).counts, <int>[0, 0]);
      expect(wird.tap(), DhikrTapResult.completed);
    });

    testWidgets('choosing another dhikr cancels the pending automatic advance', (WidgetTester tester) async {
      final ProviderContainer container = await _openAdhkar(tester);
      final AdhkarWirdController wird = container.read(adhkarWirdProvider.notifier);
      expect(wird.tap(), DhikrTapResult.completed);
      wird.select(1);
      wird.select(0);
      await tester.pump(const Duration(seconds: 3));
      expect(container.read(adhkarWirdProvider).index, 0, reason: 'the user chose; nothing moves them');
      wird.select(99);
      wird.select(-1);
      expect(container.read(adhkarWirdProvider).index, 0);
    });
  });

  group('the adhkar screen', () {
    final List<DhikrItem> items = catalog.itemsInOrder;

    testWidgets('the header is only the current title with a thin position bar, and no chips', (WidgetTester tester) async {
      await _openAdhkar(tester);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(FilterChip), findsNothing);
      expect(find.byType(ActionChip), findsNothing);
      expect(find.byKey(const ValueKey<String>('adhkar-pill-0')), findsNothing);

      expect(_title(tester), items.first.title);
      expect(_progress(tester), '١ / ٢');
      final LinearProgressIndicator bar =
          tester.widget<LinearProgressIndicator>(find.byKey(const ValueKey<String>('adhkar-progress-bar')));
      expect(bar.value, 0.5);
      expect(bar.minHeight, lessThanOrEqualTo(4), reason: 'a very thin bar');
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      // لا تخريج ولا مصدر على الشاشة: كلها في ورقة المعلومات.
      expect(find.textContaining(items.first.evidence.first.quote!), findsNothing);
      expect(find.text('التخريج'), findsNothing);
      expect(find.text('المصدر'), findsNothing);
    });

    testWidgets('the dhikr text is large, vocalized and centered', (WidgetTester tester) async {
      await _openAdhkar(tester);
      final Finder text = find.byKey(const ValueKey<String>('dhikr-text-$_firstId'));
      expect(tester.widget<Text>(text).data, items.first.text);
      expect(tester.widget<Text>(text).style!.fontSize, greaterThanOrEqualTo(30));
      expect(tester.widget<Text>(text).textAlign, TextAlign.center);
      expect(find.byKey(const ValueKey<String>('dhikr-text-scroll-$_firstId')), findsOneWidget);
      final Rect page = tester.getRect(find.byKey(const ValueKey<String>('adhkar-pages')));
      expect(tester.getCenter(text).dx, closeTo(page.center.dx, 1));
    });

    testWidgets('swiping the whole page moves between adhkar and updates the header', (WidgetTester tester) async {
      final ProviderContainer container = await _openAdhkar(tester);
      await _swipe(tester, toNext: true);
      expect(container.read(adhkarWirdProvider).index, 1);
      expect(_title(tester), items[1].title);
      expect(_progress(tester), '٢ / ٢');
      expect(tester.widget<LinearProgressIndicator>(find.byKey(const ValueKey<String>('adhkar-progress-bar'))).value, 1.0);

      await _swipe(tester, toNext: false);
      expect(container.read(adhkarWirdProvider).index, 0);
      expect(_title(tester), items.first.title);
      expect(_progress(tester), '١ / ٢');
    });

    testWidgets('the lower half is one tap zone: a tap anywhere in it counts with a light haptic', (WidgetTester tester) async {
      final List<String> haptics = _recordHaptics(tester);
      final ProviderContainer container = await _openAdhkar(tester);
      await _swipe(tester, toNext: true);
      expect(container.read(adhkarWirdProvider).index, 1);

      final Rect pages = tester.getRect(find.byKey(const ValueKey<String>('adhkar-pages')));
      final Rect zone = tester.getRect(_zone(_secondId));
      expect(zone.top, greaterThanOrEqualTo(pages.center.dy - 0.5), reason: 'it starts at the middle of the page');
      expect(zone.bottom, lessThanOrEqualTo(pages.bottom + 0.5));
      expect(zone.width, greaterThan(pages.width - 40), reason: 'it spans the page width');
      expect(zone.height, greaterThan(pages.height / 2 - 30), reason: 'it fills the lower half');

      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('dhikr-remaining-$_secondId'))).data, 'باقٍ ٣٣');

      for (final Offset point in <Offset>[
        zone.topLeft + const Offset(24, 24),
        zone.center,
        zone.bottomRight - const Offset(24, 24),
      ]) {
        await tester.tapAt(point);
        await tester.pump(const Duration(milliseconds: 60));
      }
      await settle(tester);

      expect(container.read(adhkarWirdProvider).countOf(1), 3);
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('dhikr-remaining-$_secondId'))).data, 'باقٍ ٣٠');
      expect(haptics.where((String h) => h == 'HapticFeedbackType.selectionClick'), hasLength(3));
      expect(haptics.where((String h) => h == 'HapticFeedbackType.mediumImpact'), isEmpty);

      // لمسة على نص الذكر في النصف العلوي لا تُحتسب.
      haptics.clear();
      await tester.tapAt(tester.getCenter(find.byKey(const ValueKey<String>('dhikr-text-$_secondId'))));
      await tester.pump(const Duration(milliseconds: 60));
      expect(container.read(adhkarWirdProvider).countOf(1), 3);
      expect(haptics, isEmpty);
    });

    testWidgets('reaching the number gives a double medium haptic, a green halo and a permanent lock', (WidgetTester tester) async {
      final List<String> haptics = _recordHaptics(tester);
      final ProviderContainer container = await _openAdhkar(tester);
      await _swipe(tester, toNext: true);

      final Finder zone = _zone(_secondId);
      AnimatedContainer surface() =>
          tester.widget<AnimatedContainer>(find.byKey(const ValueKey<String>('dhikr-zone-surface-$_secondId')));
      List<BoxShadow> shadows() => (surface().decoration! as ShapeDecoration).shadows!.cast<BoxShadow>();
      final FeedbackColors feedback =
          FeedbackColors.of(tester.element(find.byKey(const ValueKey<String>('dhikr-zone-surface-$_secondId'))));

      // قبل الإتمام: ظل هادئ لا هالة خضراء.
      expect(shadows().any((BoxShadow s) => s.color == feedback.rightBorder.withValues(alpha: 0.5)), isFalse);

      for (int i = 0; i < 32; i++) {
        await tester.tap(zone);
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(haptics.where((String h) => h == 'HapticFeedbackType.mediumImpact'), isEmpty, reason: 'not yet');
      expect(container.read(adhkarWirdProvider).countOf(1), 32);
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('dhikr-remaining-$_secondId'))).data, 'باقٍ ١');

      haptics.clear();
      await tester.tap(zone);
      await tester.pump();
      // الاهتزاز الأول فوراً والثاني بعد فاصل قصير: مزدوج، ولا نقرة خفيفة معه.
      expect(haptics, <String>['HapticFeedbackType.mediumImpact']);
      await tester.pump(const Duration(milliseconds: 200));
      expect(haptics, <String>['HapticFeedbackType.mediumImpact', 'HapticFeedbackType.mediumImpact']);
      await tester.pump(const Duration(milliseconds: 600));

      // الهالة الخضراء والحد الأخضر وعبارة الإتمام بدل «باقٍ».
      expect(container.read(adhkarWirdProvider).countOf(1), 33);
      expect(shadows().any((BoxShadow s) => s.color == feedback.rightBorder.withValues(alpha: 0.5)), isTrue);
      final SmoothRectangleBorder border = (surface().decoration! as ShapeDecoration).shape as SmoothRectangleBorder;
      expect(border.side.color, feedback.rightBorder);
      expect(find.byKey(const ValueKey<String>('dhikr-complete-$_secondId')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('dhikr-remaining-$_secondId')), findsNothing);

      // القفل نهائي: لا عدّ ولا اهتزاز ولو كثرت اللمسات، والمنطقة نفسها بلا استجابة.
      haptics.clear();
      expect(tester.widget<GestureDetector>(zone).onTap, isNull);
      for (int i = 0; i < 5; i++) {
        await tester.tap(zone, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 30));
      }
      expect(container.read(adhkarWirdProvider).countOf(1), 33);
      expect(haptics, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('completing a dhikr locks it and slides to the next page on its own', (WidgetTester tester) async {
      final List<String> haptics = _recordHaptics(tester);
      final ProviderContainer container = await _openAdhkar(tester);
      expect(_pages(tester).page, 0);

      // الذكر الأول عدده واحد: لمسة واحدة تكمله بالاهتزاز المزدوج لا الخفيف.
      await tester.tap(_zone(_firstId));
      await tester.pump(const Duration(milliseconds: 300));
      expect(haptics, <String>['HapticFeedbackType.mediumImpact', 'HapticFeedbackType.mediumImpact']);
      expect(container.read(adhkarWirdProvider).countOf(0), 1);
      expect(find.byKey(const ValueKey<String>('dhikr-complete-$_firstId')), findsOneWidget);

      // يبقى على الذكر المكتمل لحظة تُرى فيها الهالة، ثم تنزلق الصفحة وحدها.
      expect(_pages(tester).page, 0);
      expect(_title(tester), items.first.title);
      await tester.pump(const Duration(milliseconds: 1400));
      await settle(tester);
      expect(container.read(adhkarWirdProvider).index, 1);
      expect(_pages(tester).page, closeTo(1, 0.001));
      expect(_title(tester), items[1].title);
      expect(_progress(tester), '٢ / ٢');

      // الذكر الأول بقي مقفلاً خلفنا، والثاني مفتوح للعدّ.
      expect(container.read(adhkarWirdProvider).isDone(items, 0), isTrue);
      expect(container.read(adhkarWirdProvider).countOf(1), 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the info button opens the sheet with takhrij, the prophetic virtue and the source', (WidgetTester tester) async {
      await _openAdhkar(tester);
      final DhikrItem first = items.first;
      await tester.tap(find.byKey(const ValueKey<String>('adhkar-info')));
      await settle(tester);

      final Finder sheet = find.byKey(const ValueKey<String>('dhikr-info-sheet'));
      expect(sheet, findsOneWidget);
      for (final String heading in <String>['التخريج', 'الفضل النبوي', 'المصدر']) {
        expect(find.descendant(of: sheet, matching: find.text(heading)), findsOneWidget, reason: heading);
      }
      // الإحالة مرة واحدة في التخريج ولو حمل الحديث شاهدين، ونصاهما كلاهما في المصدر.
      expect(find.descendant(of: sheet, matching: find.textContaining('رقم ٦٣٠٦')), findsWidgets);
      for (final SourceRef reference in first.evidence) {
        expect(find.descendant(of: sheet, matching: find.textContaining(reference.quote!)), findsWidgets);
      }
      final Finder virtue = find.descendant(of: find.byKey(const ValueKey<String>('dhikr-info-virtue')), matching: find.textContaining(first.virtue!));
      expect(virtue, findsOneWidget);

      // لا عبارة مراجعة علمية ولا علامة استفهام مسودة في الورقة ولا خلفها.
      expect(find.textContaining('بانتظار المراجعة'), findsNothing);
      expect(find.textContaining('[?]'), findsNothing);

      // لمس ما حول الورقة يغلقها فتعود الشاشة هادئة.
      await tester.tapAt(const Offset(200, 40));
      await settle(tester);
      expect(sheet, findsNothing);
    });

    testWidgets('the sheet follows the current dhikr: two sources and its own virtue for the second', (WidgetTester tester) async {
      await _openAdhkar(tester);
      await _swipe(tester, toNext: true);
      final DhikrItem second = items[1];
      await tester.tap(find.byKey(const ValueKey<String>('adhkar-info')));
      await settle(tester);

      final Finder sheet = find.byKey(const ValueKey<String>('dhikr-info-sheet'));
      expect(find.descendant(of: sheet, matching: find.text(second.title)), findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.text('المصادر')), findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.textContaining(second.virtue!)), findsWidgets);
      expect(find.descendant(of: sheet, matching: find.textContaining('رقم ٥٩٦')), findsWidgets);
      expect(find.descendant(of: sheet, matching: find.textContaining('رقم ٨٤٣')), findsWidgets);
    });

    testWidgets('finishing both adhkar shows the wird-complete banner, and a new wird returns to the first page', (WidgetTester tester) async {
      _recordHaptics(tester);
      final ProviderContainer container = await _openAdhkar(tester);
      expect(find.byKey(const ValueKey<String>('adhkar-wird-complete')), findsNothing);

      await tester.tap(_zone(_firstId));
      await tester.pump(const Duration(milliseconds: 1500));
      await settle(tester);
      expect(container.read(adhkarWirdProvider).index, 1);

      for (int i = 0; i < 33; i++) {
        await tester.tap(_zone(_secondId), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 20));
      }
      await settle(tester);

      expect(container.read(adhkarWirdProvider).isComplete(container.read(adhkarItemsProvider)), isTrue);
      expect(find.byKey(const ValueKey<String>('adhkar-wird-complete')), findsOneWidget);
      expect(_progress(tester), '٢ / ٢');
      expect(container.read(adhkarWirdProvider).index, 1, reason: 'nowhere left to advance to');

      await tester.tap(find.byKey(const ValueKey<String>('adhkar-restart')));
      await settle(tester);
      expect(find.byKey(const ValueKey<String>('adhkar-wird-complete')), findsNothing);
      expect(container.read(adhkarWirdProvider).counts, <int>[0, 0]);
      expect(_pages(tester).page, closeTo(0, 0.001));
      expect(_title(tester), items.first.title);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a quick back-and-forth of the current dhikr leaves the page on the chosen one', (WidgetTester tester) async {
      final ProviderContainer container = await _openAdhkar(tester);
      final AdhkarWirdController wird = container.read(adhkarWirdProvider.notifier);
      wird.select(1);
      await tester.pump(const Duration(milliseconds: 40));
      wird.select(0);
      await settle(tester);
      expect(container.read(adhkarWirdProvider).index, 0);
      expect(_pages(tester).page, closeTo(0, 0.001));
      expect(_title(tester), items.first.title);
    });

    testWidgets('the screen survives a narrow phone with the largest fonts, and a long text scrolls inside', (WidgetTester tester) async {
      await pumpApp(tester, size: const Size(360, 740), systemTextScale: 1.3);
      await tester.tap(_navLabel('وِرد الأذكار'));
      await settle(tester);
      expect(find.byType(AdhkarScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      // نص سيد الاستغفار طويل: يتمرر داخل منطقته ولا يدفع العدّاد خارج الشاشة.
      final Finder scroll = find.descendant(
        of: find.byKey(const ValueKey<String>('dhikr-text-scroll-$_firstId')),
        matching: find.byType(Scrollable),
      );
      final ScrollableState scrollable = tester.state<ScrollableState>(scroll);
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      await tester.drag(scroll, const Offset(0, -200));
      await tester.pump(const Duration(milliseconds: 100));
      expect(scrollable.position.pixels, greaterThan(0));

      await _swipe(tester, toNext: true);
      expect(tester.takeException(), isNull);
      final Rect ring = tester.getRect(find.byKey(const ValueKey<String>('dhikr-remaining-$_secondId')));
      expect(ring.bottom, lessThanOrEqualTo(740));
      expect(ring.left, greaterThanOrEqualTo(0));
      expect(ring.right, lessThanOrEqualTo(360));

      await tester.tap(find.byKey(const ValueKey<String>('adhkar-info')));
      await settle(tester);
      expect(find.byKey(const ValueKey<String>('dhikr-info-sheet')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
