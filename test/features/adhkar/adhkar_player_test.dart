// اختبارات مشغّل التركيز لفئات الأذكار: متحكم العدّ والقفل النهائي والانتقال التلقائي
// لكل فئة على حدة، والشاشة الهادئة: رأس بلا شرائح وشريط تقدم رفيع، وسحب أفقي بين
// الأذكار، ونصف سفلي يحتسب أي نقرة باهتزاز خفيف، واهتزاز مزدوج وهالة خضراء وقفل
// وانتقال تلقائي عند بلوغ العدد المسنون، وورقة التخريج والفضل والمصدر، وشارة الإتمام.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/core/content/models/content_models.dart';
import 'package:hadith_platform/core/theme/feedback_colors.dart';
import 'package:hadith_platform/features/adhkar/application/adhkar_providers.dart';
import 'package:hadith_platform/features/adhkar/application/adhkar_wird_controller.dart';
import 'package:hadith_platform/features/adhkar/data/models/adhkar.dart';
import 'package:hadith_platform/features/adhkar/domain/adhkar_category.dart';
import 'package:smooth_corner/smooth_corner.dart';

import '../../support/adhkar_support.dart';
import '../../support/app_harness.dart';

/// فئة الاختبار الأساسية: أذكار الصباح والمساء.
const AdhkarCategory _morning = AdhkarCategories.morningEvening;

/// أذكارها بالترتيب: ٠ سيد الاستغفار (١)، ١ المئة (١٠٠)، ٢ اللهم بك أصبحنا (١)،
/// ٥ بسم الله الذي لا يضر (٣).
const int _istighfarIndex = 0;
const int _hundredIndex = 1;
const int _asbahnaIndex = 2;
const int _threeIndex = 5;

Finder _zone(String id) => find.byKey(ValueKey<String>('dhikr-tap-zone-$id'));

/// موضع الذكر في الرأس، مثل «١ / ١٣».
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

/// ينقل الوِرد إلى ذكر بعينه فتتبعه الصفحة.
Future<void> _goTo(WidgetTester tester, ProviderContainer container, AdhkarCategory category, int index) async {
  container.read(adhkarWirdProvider(category.id).notifier).select(index);
  await settle(tester);
}

void main() {
  final List<DhikrItem> morning = loadCategory(_morning).itemsInOrder;

  group('the wird controller', () {
    testWidgets('counts to the prophetic number, then locks permanently and advances on its own',
        (WidgetTester tester) async {
      final ProviderContainer container = makeContainer();
      await container.read(adhkarCatalogProvider(_morning.id).future);
      final AdhkarWirdController wird = container.read(adhkarWirdProvider(_morning.id).notifier);
      AdhkarWirdState state() => container.read(adhkarWirdProvider(_morning.id));
      List<DhikrItem> items() => container.read(adhkarItemsProvider(_morning.id));
      expect(items(), hasLength(morning.length));
      expect(state().index, 0);
      expect(state().counts, everyElement(0));

      // الذكر الأول عدده واحد: أول لمسة تكمله وتقفله.
      expect(wird.tap(), DhikrTapResult.completed);
      expect(state().countOf(0), 1);
      for (int i = 0; i < 5; i++) {
        expect(wird.tap(), DhikrTapResult.locked);
      }
      expect(state().countOf(0), 1, reason: 'never exceeds the prophetic count');

      // قبل انقضاء المهلة يبقى على الذكر المكتمل، ثم ينتقل إلى الثاني وحده.
      await tester.pump(const Duration(milliseconds: 500));
      expect(state().index, 0);
      await tester.pump(const Duration(milliseconds: 1200));
      expect(state().index, 1);

      // الذكر الثاني مئة مرة: ٩٩ احتساب ثم إكمال في المئة.
      expect(morning[1].count, 100);
      for (int i = 0; i < 99; i++) {
        expect(wird.tap(), DhikrTapResult.counted, reason: 'tap ${i + 1}');
      }
      expect(state().isComplete(items()), isFalse);
      expect(wird.tap(), DhikrTapResult.completed);
      expect(wird.tap(), DhikrTapResult.locked);
      expect(state().countOf(1), 100);

      // بقية الأذكار: كل ذكر يُكمل بعدده المنصوص، والوِرد يكتمل بآخرها.
      for (int i = 2; i < morning.length; i++) {
        wird.select(i);
        for (int t = 0; t < morning[i].count; t++) {
          expect(wird.tap(), t == morning[i].count - 1 ? DhikrTapResult.completed : DhikrTapResult.counted,
              reason: '${morning[i].id} tap ${t + 1}');
        }
        expect(wird.tap(), DhikrTapResult.locked);
        expect(state().countOf(i), morning[i].count);
      }
      expect(state().isComplete(items()), isTrue);
      expect(state().doneCount(items()), morning.length);

      // الوِرد كله مكتمل فلا انتقال بعده، ويبقى على الذكر الأخير.
      await tester.pump(const Duration(seconds: 2));
      expect(state().index, morning.length - 1);

      // وِرد جديد يعيد كل شيء إلى الصفر ويفك القفل.
      wird.restart();
      expect(state().index, 0);
      expect(state().counts, everyElement(0));
      expect(state().counts, hasLength(morning.length));
      expect(wird.tap(), DhikrTapResult.completed);
    });

    testWidgets('choosing another dhikr cancels the pending automatic advance', (WidgetTester tester) async {
      final ProviderContainer container = makeContainer();
      await container.read(adhkarCatalogProvider(_morning.id).future);
      final AdhkarWirdController wird = container.read(adhkarWirdProvider(_morning.id).notifier);
      AdhkarWirdState state() => container.read(adhkarWirdProvider(_morning.id));
      expect(wird.tap(), DhikrTapResult.completed);
      wird.select(1);
      wird.select(0);
      await tester.pump(const Duration(seconds: 3));
      expect(state().index, 0, reason: 'the user chose; nothing moves them');
      wird.select(99);
      wird.select(-1);
      expect(state().index, 0);
    });

    test('every category counts its first dhikr to exactly its own number, then locks it', () async {
      final ProviderContainer container = makeContainer();
      for (final AdhkarCategory category in AdhkarCategories.all) {
        await container.read(adhkarCatalogProvider(category.id).future);
        final AdhkarWirdController wird = container.read(adhkarWirdProvider(category.id).notifier);
        final DhikrItem first = container.read(adhkarItemsProvider(category.id)).first;
        for (int t = 1; t < first.count; t++) {
          expect(wird.tap(), DhikrTapResult.counted, reason: '${category.id} tap $t');
        }
        expect(wird.tap(), DhikrTapResult.completed, reason: category.id);
        expect(wird.tap(), DhikrTapResult.locked, reason: category.id);
        expect(container.read(adhkarWirdProvider(category.id)).countOf(0), first.count, reason: category.id);
      }
    });

    test('each category keeps its own wird: counting in one never touches another', () async {
      final ProviderContainer container = makeContainer();
      const AdhkarCategory sleep = AdhkarCategories.sleep;
      await container.read(adhkarCatalogProvider(_morning.id).future);
      await container.read(adhkarCatalogProvider(sleep.id).future);
      expect(container.read(adhkarWirdProvider(_morning.id).notifier).tap(), DhikrTapResult.completed);
      expect(container.read(adhkarWirdProvider(_morning.id)).countOf(0), 1);
      expect(container.read(adhkarWirdProvider(sleep.id)).counts, everyElement(0));
      expect(container.read(adhkarWirdProvider(sleep.id)).index, 0);
      expect(container.read(adhkarWirdProvider(sleep.id)).counts, hasLength(13));
      expect(container.read(adhkarWirdProvider(_morning.id)).counts, hasLength(13));
    });

    test('a controller asked before its file is loaded reports unavailable instead of counting', () {
      final ProviderContainer container = makeContainer();
      final AdhkarWirdController wird = container.read(adhkarWirdProvider(_morning.id).notifier);
      expect(wird.tap(), DhikrTapResult.unavailable);
      expect(container.read(adhkarWirdProvider(_morning.id)).counts, isEmpty);
    });

    test('an unknown category id fails loudly instead of showing nothing', () async {
      final ProviderContainer container = makeContainer();
      await expectLater(container.read(adhkarCatalogProvider('no_such_category').future), throwsA(anything));
    });
  });

  group('the focus-mode player', () {
    testWidgets('the header is the category, the current title and a thin position bar, with no chips',
        (WidgetTester tester) async {
      await openCategory(tester, _morning);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(FilterChip), findsNothing);
      expect(find.byType(ActionChip), findsNothing);
      expect(find.byType(TabBar), findsNothing);

      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('adhkar-category-title'))).data, _morning.title);
      expect(_title(tester), morning.first.title);
      expect(_progress(tester), '١ / ١٣');
      final LinearProgressIndicator bar =
          tester.widget<LinearProgressIndicator>(find.byKey(const ValueKey<String>('adhkar-progress-bar')));
      expect(bar.value, closeTo(1 / 13, 0.0001));
      expect(bar.minHeight, lessThanOrEqualTo(4), reason: 'a very thin bar');
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('adhkar-back')), findsOneWidget);
      // لا تخريج ولا مصدر ولا فضل على الشاشة: كلها في ورقة المعلومات.
      expect(find.textContaining(morning.first.evidence.first.quote!), findsNothing);
      expect(find.textContaining(morning.first.virtue!), findsNothing);
      expect(find.text('التخريج'), findsNothing);
      expect(find.text('المصدر'), findsNothing);
      expect(find.textContaining('بانتظار المراجعة'), findsNothing);
      expect(find.textContaining('pending'), findsNothing);
    });

    testWidgets('the dhikr text is large, vocalized and centered', (WidgetTester tester) async {
      await openCategory(tester, _morning);
      final Finder text = find.byKey(ValueKey<String>('dhikr-text-${morning.first.id}'));
      expect(tester.widget<Text>(text).data, morning.first.text);
      expect(tester.widget<Text>(text).style!.fontSize, greaterThanOrEqualTo(30));
      expect(tester.widget<Text>(text).textAlign, TextAlign.center);
      expect(find.byKey(ValueKey<String>('dhikr-text-scroll-${morning.first.id}')), findsOneWidget);
      final Rect page = tester.getRect(find.byKey(const ValueKey<String>('adhkar-pages')));
      expect(tester.getCenter(text).dx, closeTo(page.center.dx, 1));
    });

    for (final AdhkarCategory category in AdhkarCategories.all) {
      testWidgets('${category.id}: opens from its hub card on its own first dhikr and its own title',
          (WidgetTester tester) async {
        final List<DhikrItem> items = loadCategory(category).itemsInOrder;
        await openCategory(tester, category);
        expect(find.byKey(ValueKey<String>('adhkar-player-${category.id}')), findsOneWidget);
        expect(tester.widget<Text>(find.byKey(const ValueKey<String>('adhkar-category-title'))).data, category.title);
        expect(_title(tester), items.first.title);
        expect(_progress(tester).startsWith('١ / '), isTrue);
        expect(tester.widget<Text>(find.byKey(ValueKey<String>('dhikr-text-${items.first.id}'))).data, items.first.text);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('swiping the whole page moves between adhkar and updates the header', (WidgetTester tester) async {
      final ProviderContainer container = await openCategory(tester, _morning);
      await _swipe(tester, toNext: true);
      expect(container.read(adhkarWirdProvider(_morning.id)).index, 1);
      expect(_title(tester), morning[1].title);
      expect(_progress(tester), '٢ / ١٣');
      expect(
        tester.widget<LinearProgressIndicator>(find.byKey(const ValueKey<String>('adhkar-progress-bar'))).value,
        closeTo(2 / 13, 0.0001),
      );

      await _swipe(tester, toNext: false);
      expect(container.read(adhkarWirdProvider(_morning.id)).index, 0);
      expect(_title(tester), morning.first.title);
      expect(_progress(tester), '١ / ١٣');
    });

    testWidgets('the lower half is one tap zone: a tap anywhere in it counts with a light haptic',
        (WidgetTester tester) async {
      final List<String> haptics = recordHaptics(tester);
      final ProviderContainer container = await openCategory(tester, _morning);
      await _swipe(tester, toNext: true);
      expect(container.read(adhkarWirdProvider(_morning.id)).index, _hundredIndex);
      final String id = morning[_hundredIndex].id;

      final Rect pages = tester.getRect(find.byKey(const ValueKey<String>('adhkar-pages')));
      final Rect zone = tester.getRect(_zone(id));
      expect(zone.top, greaterThanOrEqualTo(pages.center.dy - 0.5), reason: 'it starts at the middle of the page');
      expect(zone.bottom, lessThanOrEqualTo(pages.bottom + 0.5));
      expect(zone.width, greaterThan(pages.width - 40), reason: 'it spans the page width');
      expect(zone.height, greaterThan(pages.height / 2 - 30), reason: 'it fills the lower half');

      expect(tester.widget<Text>(find.byKey(ValueKey<String>('dhikr-remaining-$id'))).data, 'باقٍ ١٠٠');

      for (final Offset point in <Offset>[
        zone.topLeft + const Offset(24, 24),
        zone.center,
        zone.bottomRight - const Offset(24, 24),
      ]) {
        await tester.tapAt(point);
        await tester.pump(const Duration(milliseconds: 60));
      }
      await settle(tester);

      expect(container.read(adhkarWirdProvider(_morning.id)).countOf(_hundredIndex), 3);
      expect(tester.widget<Text>(find.byKey(ValueKey<String>('dhikr-remaining-$id'))).data, 'باقٍ ٩٧');
      expect(haptics.where((String h) => h == 'HapticFeedbackType.selectionClick'), hasLength(3));
      expect(haptics.where((String h) => h == 'HapticFeedbackType.mediumImpact'), isEmpty);

      // لمسة على نص الذكر في النصف العلوي لا تُحتسب.
      haptics.clear();
      await tester.tapAt(tester.getCenter(find.byKey(ValueKey<String>('dhikr-text-$id'))));
      await tester.pump(const Duration(milliseconds: 60));
      expect(container.read(adhkarWirdProvider(_morning.id)).countOf(_hundredIndex), 3);
      expect(haptics, isEmpty);
    });

    testWidgets('reaching the number gives a double medium haptic, a green halo and a permanent lock',
        (WidgetTester tester) async {
      final List<String> haptics = recordHaptics(tester);
      final ProviderContainer container = await openCategory(tester, _morning);
      await _goTo(tester, container, _morning, _threeIndex);
      final DhikrItem item = morning[_threeIndex];
      expect(item.count, 3);

      final Finder zone = _zone(item.id);
      AnimatedContainer surface() =>
          tester.widget<AnimatedContainer>(find.byKey(ValueKey<String>('dhikr-zone-surface-${item.id}')));
      List<BoxShadow> shadows() => (surface().decoration! as ShapeDecoration).shadows!.cast<BoxShadow>();
      final FeedbackColors feedback =
          FeedbackColors.of(tester.element(find.byKey(ValueKey<String>('dhikr-zone-surface-${item.id}'))));
      Text remaining() => tester.widget<Text>(find.byKey(ValueKey<String>('dhikr-remaining-${item.id}')));

      // قبل الإتمام: ظل هادئ لا هالة خضراء.
      expect(shadows().any((BoxShadow s) => s.color == feedback.rightBorder.withValues(alpha: 0.5)), isFalse);
      expect(remaining().data, 'باقٍ ٣');

      for (int i = 0; i < 2; i++) {
        await tester.tap(zone);
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(haptics.where((String h) => h == 'HapticFeedbackType.mediumImpact'), isEmpty, reason: 'not yet');
      expect(container.read(adhkarWirdProvider(_morning.id)).countOf(_threeIndex), 2);
      expect(remaining().data, 'باقٍ ١');

      haptics.clear();
      await tester.tap(zone);
      await tester.pump();
      // الاهتزاز الأول فوراً والثاني بعد فاصل قصير: مزدوج، ولا نقرة خفيفة معه.
      expect(haptics, <String>['HapticFeedbackType.mediumImpact']);
      await tester.pump(const Duration(milliseconds: 200));
      expect(haptics, <String>['HapticFeedbackType.mediumImpact', 'HapticFeedbackType.mediumImpact']);
      await tester.pump(const Duration(milliseconds: 600));

      // الهالة الخضراء والحد الأخضر وعبارة الإتمام بدل «باقٍ».
      expect(container.read(adhkarWirdProvider(_morning.id)).countOf(_threeIndex), 3);
      expect(shadows().any((BoxShadow s) => s.color == feedback.rightBorder.withValues(alpha: 0.5)), isTrue);
      final SmoothRectangleBorder border = (surface().decoration! as ShapeDecoration).shape as SmoothRectangleBorder;
      expect(border.side.color, feedback.rightBorder);
      expect(find.byKey(ValueKey<String>('dhikr-complete-${item.id}')), findsOneWidget);
      expect(find.byKey(ValueKey<String>('dhikr-remaining-${item.id}')), findsNothing);

      // القفل نهائي: لا عدّ ولا اهتزاز ولو كثرت اللمسات، والمنطقة نفسها بلا استجابة.
      haptics.clear();
      expect(tester.widget<GestureDetector>(zone).onTap, isNull);
      for (int i = 0; i < 5; i++) {
        await tester.tap(zone, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 30));
      }
      expect(container.read(adhkarWirdProvider(_morning.id)).countOf(_threeIndex), 3);
      expect(haptics, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('completing a dhikr locks it and slides to the next page on its own', (WidgetTester tester) async {
      final List<String> haptics = recordHaptics(tester);
      final ProviderContainer container = await openCategory(tester, _morning);
      expect(_pages(tester).page, 0);
      final DhikrItem first = morning[_istighfarIndex];

      // الذكر الأول عدده واحد: لمسة واحدة تكمله بالاهتزاز المزدوج لا الخفيف.
      await tester.tap(_zone(first.id));
      await tester.pump(const Duration(milliseconds: 300));
      expect(haptics, <String>['HapticFeedbackType.mediumImpact', 'HapticFeedbackType.mediumImpact']);
      expect(container.read(adhkarWirdProvider(_morning.id)).countOf(0), 1);
      expect(find.byKey(ValueKey<String>('dhikr-complete-${first.id}')), findsOneWidget);

      // يبقى على الذكر المكتمل لحظة تُرى فيها الهالة، ثم تنزلق الصفحة وحدها.
      expect(_pages(tester).page, 0);
      expect(_title(tester), first.title);
      await tester.pump(const Duration(milliseconds: 1400));
      await settle(tester);
      expect(container.read(adhkarWirdProvider(_morning.id)).index, 1);
      expect(_pages(tester).page, closeTo(1, 0.001));
      expect(_title(tester), morning[1].title);
      expect(_progress(tester), '٢ / ١٣');

      // الذكر الأول بقي مقفلاً خلفنا، والثاني مفتوح للعدّ.
      expect(container.read(adhkarWirdProvider(_morning.id)).isDone(morning, 0), isTrue);
      expect(container.read(adhkarWirdProvider(_morning.id)).countOf(1), 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the info button opens the sheet with takhrij, the prophetic virtue and the source',
        (WidgetTester tester) async {
      await openCategory(tester, _morning);
      final DhikrItem first = morning.first;
      await tester.tap(find.byKey(const ValueKey<String>('adhkar-info')));
      await settle(tester);

      final Finder sheet = find.byKey(const ValueKey<String>('dhikr-info-sheet'));
      expect(sheet, findsOneWidget);
      for (final String heading in <String>['التخريج', 'الفضل النبوي', 'المصدر']) {
        expect(find.descendant(of: sheet, matching: find.text(heading)), findsOneWidget, reason: heading);
      }
      // الإحالة في التخريج، ونص الشاهد في المصدر.
      expect(find.descendant(of: sheet, matching: find.textContaining('رقم ٦٣٠٦')), findsWidgets);
      for (final SourceRef reference in first.evidence) {
        expect(find.descendant(of: sheet, matching: find.textContaining(reference.quote!)), findsWidgets);
      }
      final Finder virtue = find.descendant(
        of: find.byKey(const ValueKey<String>('dhikr-info-virtue')),
        matching: find.textContaining(first.virtue!),
      );
      expect(virtue, findsOneWidget);

      // لا عبارة مراجعة علمية ولا علامة استفهام مسودة في الورقة ولا خلفها.
      expect(find.textContaining('بانتظار المراجعة'), findsNothing);
      expect(find.textContaining('[?]'), findsNothing);

      // لمس ما حول الورقة يغلقها فتعود الشاشة هادئة.
      await tester.tapAt(const Offset(200, 40));
      await settle(tester);
      expect(sheet, findsNothing);
    });

    testWidgets('the sheet follows the current dhikr: two sources, no virtue block when none is stated',
        (WidgetTester tester) async {
      final ProviderContainer container = await openCategory(tester, _morning);
      await _goTo(tester, container, _morning, _asbahnaIndex);
      final DhikrItem item = morning[_asbahnaIndex];
      expect(item.virtue, isNull);
      expect(item.evidence, hasLength(2));
      await tester.tap(find.byKey(const ValueKey<String>('adhkar-info')));
      await settle(tester);

      final Finder sheet = find.byKey(const ValueKey<String>('dhikr-info-sheet'));
      expect(find.descendant(of: sheet, matching: find.text(item.title)), findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.text('المصادر')), findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.text('الفضل النبوي')), findsNothing);
      expect(find.byKey(const ValueKey<String>('dhikr-info-virtue')), findsNothing);
      expect(find.descendant(of: sheet, matching: find.textContaining('رقم ٥٠٦٨')), findsWidgets);
      expect(find.descendant(of: sheet, matching: find.textContaining('رقم ٣٣٩١')), findsWidgets);
    });

    testWidgets('finishing a whole category shows the wird-complete banner, and a new wird returns to the first page',
        (WidgetTester tester) async {
      recordHaptics(tester);
      const AdhkarCategory category = AdhkarCategories.homeMasjid;
      final List<DhikrItem> items = loadCategory(category).itemsInOrder;
      final ProviderContainer container = await openCategory(tester, category);
      expect(find.byKey(const ValueKey<String>('adhkar-wird-complete')), findsNothing);

      for (int i = 0; i < items.length; i++) {
        expect(items[i].count, 1, reason: items[i].id);
        await tester.tap(_zone(items[i].id));
        await tester.pump(const Duration(milliseconds: 1500));
        await settle(tester);
      }

      expect(container.read(adhkarWirdProvider(category.id)).isComplete(items), isTrue);
      expect(find.byKey(const ValueKey<String>('adhkar-wird-complete')), findsOneWidget);
      expect(_progress(tester), '٦ / ٦');
      expect(container.read(adhkarWirdProvider(category.id)).index, items.length - 1,
          reason: 'nowhere left to advance to');

      await tester.tap(find.byKey(const ValueKey<String>('adhkar-restart')));
      await settle(tester);
      expect(find.byKey(const ValueKey<String>('adhkar-wird-complete')), findsNothing);
      expect(container.read(adhkarWirdProvider(category.id)).counts, everyElement(0));
      expect(_pages(tester).page, closeTo(0, 0.001));
      expect(_title(tester), items.first.title);
      expect(tester.takeException(), isNull);
    });

    testWidgets('going back to the hub and returning keeps the wird where it was', (WidgetTester tester) async {
      recordHaptics(tester);
      final ProviderContainer container = await openCategory(tester, _morning);
      await tester.tap(_zone(morning.first.id));
      await tester.pump(const Duration(milliseconds: 1500));
      await settle(tester);
      expect(container.read(adhkarWirdProvider(_morning.id)).index, 1);

      await tester.tap(find.byKey(const ValueKey<String>('adhkar-back')));
      await settle(tester);
      expect(find.byKey(const ValueKey<String>('adhkar-hub')), findsOneWidget);
      expect(find.byKey(ValueKey<String>('adhkar-player-${_morning.id}')), findsNothing);

      await tester.tap(find.byKey(cardKey(_morning)));
      await settle(tester);
      expect(_progress(tester), '٢ / ١٣');
      expect(_title(tester), morning[1].title);
      expect(container.read(adhkarWirdProvider(_morning.id)).isDone(morning, 0), isTrue);
    });

    testWidgets('a quick back-and-forth of the current dhikr leaves the page on the chosen one',
        (WidgetTester tester) async {
      final ProviderContainer container = await openCategory(tester, _morning);
      final AdhkarWirdController wird = container.read(adhkarWirdProvider(_morning.id).notifier);
      wird.select(1);
      await tester.pump(const Duration(milliseconds: 40));
      wird.select(0);
      await settle(tester);
      expect(container.read(adhkarWirdProvider(_morning.id)).index, 0);
      expect(_pages(tester).page, closeTo(0, 0.001));
      expect(_title(tester), morning.first.title);
    });

    testWidgets('the screen survives a narrow phone with the largest fonts, and a long text scrolls inside',
        (WidgetTester tester) async {
      await openCategory(tester, _morning, size: const Size(360, 740), systemTextScale: 1.3);
      expect(tester.takeException(), isNull);

      // نص سيد الاستغفار طويل: يتمرر داخل منطقته ولا يدفع العدّاد خارج الشاشة.
      final Finder scroll = find.descendant(
        of: find.byKey(ValueKey<String>('dhikr-text-scroll-${morning.first.id}')),
        matching: find.byType(Scrollable),
      );
      final ScrollableState scrollable = tester.state<ScrollableState>(scroll);
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      await tester.drag(scroll, const Offset(0, -200));
      await tester.pump(const Duration(milliseconds: 100));
      expect(scrollable.position.pixels, greaterThan(0));

      await _swipe(tester, toNext: true);
      expect(tester.takeException(), isNull);
      final Rect ring = tester.getRect(find.byKey(ValueKey<String>('dhikr-remaining-${morning[_hundredIndex].id}')));
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
