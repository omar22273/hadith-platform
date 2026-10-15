// اختبارات مشغّل التركيز لفئات الأذكار: متحكم العدّ والقفل النهائي والانتقال التلقائي
// لكل نطاق على حدة (فئة، أو مسار من فئة ذات تبديل)، والشاشة الهادئة: رأس بلا شرائح
// وشريط تقدم رفيع، وسحب أفقي بين الأذكار، ونصف سفلي يحتسب أي نقرة باهتزاز خفيف،
// واهتزاز مزدوج وهالة خضراء وقفل وانتقال تلقائي عند بلوغ العدد المسنون، وورقة
// التخريج والدرجة والفضل والمصدر، وشارة الإتمام، وشريط التبديل بين مسارَي الفئة.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/core/content/models/content_models.dart';
import 'package:hadith_platform/core/text/arabic_digits.dart';
import 'package:hadith_platform/core/theme/feedback_colors.dart';
import 'package:hadith_platform/features/adhkar/application/adhkar_providers.dart';
import 'package:hadith_platform/features/adhkar/application/adhkar_wird_controller.dart';
import 'package:hadith_platform/features/adhkar/data/models/adhkar.dart';
import 'package:hadith_platform/features/adhkar/domain/adhkar_category.dart';
import 'package:hadith_platform/features/adhkar/presentation/widgets/track_toggle.dart';
import 'package:smooth_corner/smooth_corner.dart';

import '../../support/adhkar_support.dart';
import '../../support/app_harness.dart';

/// فئة الاختبار الأساسية: أذكار الصباح والمساء، ومسارها الأول الصباح.
const AdhkarCategory _morning = AdhkarCategories.morningEvening;

Finder _zone(String id) => find.byKey(ValueKey<String>('dhikr-tap-zone-$id'));

/// موضع الذكر في الرأس، مثل «١ / ٢٥».
String _progress(WidgetTester tester) {
  return tester.widget<Text>(find.byKey(const ValueKey<String>('adhkar-progress'))).data!;
}

/// موضع الذكر المتوقع في الرأس.
String _position(int position, int total) => '${arabicDigits(position)} / ${arabicDigits(total)}';

/// عنوان الذكر الحالي في الرأس.
String _title(WidgetTester tester) {
  return tester.widget<Text>(find.byKey(const ValueKey<String>('adhkar-title'))).data!;
}

/// متحكم صفحات الأذكار.
PageController _pages(WidgetTester tester) {
  return tester.widget<PageView>(find.byKey(const ValueKey<String>('adhkar-pages'))).controller!;
}

/// رقم الذكر بمعرّفه في القائمة، ويفشل الاختبار إن غاب.
int _at(List<DhikrItem> items, String id) {
  final int index = items.indexWhere((DhikrItem item) => item.id == id);
  expect(index, greaterThanOrEqualTo(0), reason: 'missing $id');
  return index;
}

/// يسحب الصفحة أفقياً. الواجهة من اليمين إلى اليسار: صفحة الذكر التالي عن
/// يسار الحالية، فيكون السحب إليها بإصبع يتحرك نحو اليمين.
Future<void> _swipe(WidgetTester tester, {required bool toNext}) async {
  await tester.drag(find.byKey(const ValueKey<String>('adhkar-pages')), Offset(toNext ? 320 : -320, 0));
  await settle(tester);
}

/// ينقل الوِرد إلى ذكر بعينه فتتبعه الصفحة.
Future<void> _goTo(WidgetTester tester, ProviderContainer container, String scope, int index) async {
  container.read(adhkarWirdProvider(scope).notifier).select(index);
  await settle(tester);
}

void main() {
  final String morningScope = scopeKeyOf(_morning, 'morning');
  final String eveningScope = scopeKeyOf(_morning, 'evening');
  final List<DhikrItem> morning = loadScopeItems(_morning, 'morning');
  final List<DhikrItem> evening = loadScopeItems(_morning, 'evening');

  group('the wird controller', () {
    testWidgets('counts to the prophetic number, then locks permanently and advances on its own',
        (WidgetTester tester) async {
      final ProviderContainer container = makeContainer();
      await container.read(adhkarCatalogProvider(_morning.id).future);
      final AdhkarWirdController wird = container.read(adhkarWirdProvider(morningScope).notifier);
      AdhkarWirdState state() => container.read(adhkarWirdProvider(morningScope));
      List<DhikrItem> items() => container.read(adhkarItemsProvider(morningScope));
      expect(items(), hasLength(morning.length));
      expect(state().index, 0);
      expect(state().counts, everyElement(0));

      // الذكر الأول عدده واحد: أول لمسة تكمله وتقفله.
      expect(morning.first.count, 1);
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

      // ذكر المئة مرة: ٩٩ احتساب ثم إكمال في المئة.
      final int hundred = _at(morning, 'tasbih_mia_sabahan_wa_masaan');
      expect(morning[hundred].count, 100);
      wird.select(hundred);
      for (int i = 0; i < 99; i++) {
        expect(wird.tap(), DhikrTapResult.counted, reason: 'tap ${i + 1}');
      }
      expect(state().isComplete(items()), isFalse);
      expect(wird.tap(), DhikrTapResult.completed);
      expect(wird.tap(), DhikrTapResult.locked);
      expect(state().countOf(hundred), 100);

      // بقية الأذكار: كل ذكر يُكمل بعدده المنصوص، والوِرد يكتمل بآخرها.
      for (int i = 1; i < morning.length; i++) {
        if (i == hundred) {
          continue;
        }
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
      // يترك الاختبار بلا مؤقت معلّق: الانتقال التلقائي بعد الإتمام الأخير.
      await tester.pump(const Duration(seconds: 2));
      expect(state().index, 1);
    });

    testWidgets('choosing another dhikr cancels the pending automatic advance', (WidgetTester tester) async {
      final ProviderContainer container = makeContainer();
      await container.read(adhkarCatalogProvider(_morning.id).future);
      final AdhkarWirdController wird = container.read(adhkarWirdProvider(morningScope).notifier);
      AdhkarWirdState state() => container.read(adhkarWirdProvider(morningScope));
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
        final String scope = scopeKeyOf(category);
        await container.read(adhkarCatalogProvider(category.id).future);
        final AdhkarWirdController wird = container.read(adhkarWirdProvider(scope).notifier);
        final DhikrItem first = container.read(adhkarItemsProvider(scope)).first;
        for (int t = 1; t < first.count; t++) {
          expect(wird.tap(), DhikrTapResult.counted, reason: '${category.id} tap $t');
        }
        expect(wird.tap(), DhikrTapResult.completed, reason: category.id);
        expect(wird.tap(), DhikrTapResult.locked, reason: category.id);
        expect(container.read(adhkarWirdProvider(scope)).countOf(0), first.count, reason: category.id);
      }
    });

    test('each category keeps its own wird: counting in one never touches another', () async {
      final ProviderContainer container = makeContainer();
      const AdhkarCategory sleep = AdhkarCategories.sleep;
      final String sleepScope = scopeKeyOf(sleep);
      await container.read(adhkarCatalogProvider(_morning.id).future);
      await container.read(adhkarCatalogProvider(sleep.id).future);
      expect(container.read(adhkarWirdProvider(morningScope).notifier).tap(), DhikrTapResult.completed);
      expect(container.read(adhkarWirdProvider(morningScope)).countOf(0), 1);
      expect(container.read(adhkarWirdProvider(sleepScope)).counts, everyElement(0));
      expect(container.read(adhkarWirdProvider(sleepScope)).index, 0);
      expect(container.read(adhkarWirdProvider(sleepScope)).counts, hasLength(loadScopeItems(sleep).length));
      expect(container.read(adhkarWirdProvider(morningScope)).counts, hasLength(morning.length));
    });

    test('the two tracks of one category keep separate lists and separate counters', () async {
      final ProviderContainer container = makeContainer();
      await container.read(adhkarCatalogProvider(_morning.id).future);
      final List<DhikrItem> morningItems = container.read(adhkarItemsProvider(morningScope));
      final List<DhikrItem> eveningItems = container.read(adhkarItemsProvider(eveningScope));
      expect(morningItems.map((DhikrItem i) => i.id), morning.map((DhikrItem i) => i.id));
      expect(eveningItems.map((DhikrItem i) => i.id), evening.map((DhikrItem i) => i.id));
      expect(morningItems.every((DhikrItem i) => i.inTrack('morning')), isTrue);
      expect(eveningItems.every((DhikrItem i) => i.inTrack('evening')), isTrue);
      expect(morningItems.any((DhikrItem i) => i.id == 'amsayna_wa_amsal_mulk'), isFalse);
      expect(eveningItems.any((DhikrItem i) => i.id == 'amsayna_wa_amsal_mulk'), isTrue);
      expect(morningItems.any((DhikrItem i) => i.id == 'asbahna_wa_asbaha_al_mulk'), isTrue);
      expect(eveningItems.any((DhikrItem i) => i.id == 'asbahna_wa_asbaha_al_mulk'), isFalse);

      expect(container.read(adhkarWirdProvider(morningScope).notifier).tap(), DhikrTapResult.completed);
      expect(container.read(adhkarWirdProvider(morningScope)).countOf(0), 1);
      expect(container.read(adhkarWirdProvider(eveningScope)).counts, everyElement(0));
    });

    test('a controller asked before its file is loaded reports unavailable instead of counting', () {
      final ProviderContainer container = makeContainer();
      final AdhkarWirdController wird = container.read(adhkarWirdProvider(morningScope).notifier);
      expect(wird.tap(), DhikrTapResult.unavailable);
      expect(container.read(adhkarWirdProvider(morningScope)).counts, isEmpty);
    });

    test('an unknown category id fails loudly instead of showing nothing', () async {
      final ProviderContainer container = makeContainer();
      await expectLater(container.read(adhkarCatalogProvider('no_such_category').future), throwsA(anything));
    });

    test('a scope key round-trips between a category and a track', () {
      expect(AdhkarScope.parse('adhkar_sleep').trackId, isNull);
      final AdhkarScope track = AdhkarScope.parse('adhkar_sleep#wake');
      expect(track.categoryId, 'adhkar_sleep');
      expect(track.trackId, 'wake');
      expect(track.key, 'adhkar_sleep#wake');
      expect(const AdhkarScope.track('adhkar_sleep', 'wake'), track);
      expect(AdhkarCategories.afterPrayer.scopeFor('morning').key, 'adhkar_after_prayer',
          reason: 'a category without a toggle has no tracks');
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
      expect(_progress(tester), _position(1, morning.length));
      final LinearProgressIndicator bar =
          tester.widget<LinearProgressIndicator>(find.byKey(const ValueKey<String>('adhkar-progress-bar')));
      expect(bar.value, closeTo(1 / morning.length, 0.0001));
      expect(bar.minHeight, lessThanOrEqualTo(4), reason: 'a very thin bar');
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('adhkar-back')), findsOneWidget);
      // لا تخريج ولا مصدر ولا درجة ولا فضل على الشاشة: كلها في ورقة المعلومات.
      expect(find.textContaining(morning.first.evidence.last.quote!), findsNothing);
      expect(find.text('التخريج'), findsNothing);
      expect(find.text('المصدر'), findsNothing);
      expect(find.text('الدرجة'), findsNothing);
      expect(find.text('الفضل النبوي'), findsNothing);
      expect(find.textContaining('بانتظار المراجعة'), findsNothing);
      expect(find.textContaining('pending'), findsNothing);
    });

    testWidgets('the dhikr text is large, vocalized and centered', (WidgetTester tester) async {
      await openCategory(tester, _morning);
      final Finder text = find.byKey(ValueKey<String>('dhikr-text-${morning.first.id}'));
      expect(tester.widget<Text>(text).data, morning.first.displayText);
      expect(tester.widget<Text>(text).style!.fontSize, greaterThanOrEqualTo(30));
      expect(tester.widget<Text>(text).textAlign, TextAlign.center);
      expect(find.byKey(ValueKey<String>('dhikr-text-scroll-${morning.first.id}')), findsOneWidget);
      final Rect page = tester.getRect(find.byKey(const ValueKey<String>('adhkar-pages')));
      expect(tester.getCenter(text).dx, closeTo(page.center.dx, 1));
    });

    testWidgets('a Quran passage is shown between ornate brackets and its verse markers are drawn as ۝',
        (WidgetTester tester) async {
      final ProviderContainer container = await openCategory(tester, _morning);
      final DhikrItem kursi = morning.first;
      expect(kursi.id, 'ayat_al_kursi_sabahan_wa_masaan');
      expect(kursi.isQuran, isTrue);
      String shown(DhikrItem item) =>
          tester.widget<Text>(find.byKey(ValueKey<String>('dhikr-text-${item.id}'))).data!;
      expect(shown(kursi), startsWith('﴿'));
      expect(shown(kursi), endsWith('﴾'));
      expect(shown(kursi), contains(kursi.text), reason: 'the verse is shown as the owner typed it');

      final DhikrItem ikhlas = morning[_at(morning, 'surat_al_ikhlas_thalathan')];
      await _goTo(tester, container, morningScope, _at(morning, 'surat_al_ikhlas_thalathan'));
      expect(ikhlas.text, contains(' * '));
      expect(shown(ikhlas), isNot(contains('*')));
      expect(shown(ikhlas), contains(' ۝ '));
      expect(shown(ikhlas), startsWith('﴿'));

      // وما ليس آية لا يُغيَّر فيه حرف.
      final DhikrItem plain = morning[_at(morning, 'sayyid_al_istighfar')];
      expect(plain.isQuran, isFalse);
      expect(plain.displayText, plain.text);
    });

    for (final AdhkarCategory category in AdhkarCategories.all) {
      testWidgets('${category.id}: opens from its hub card on its own first dhikr and its own title',
          (WidgetTester tester) async {
        final List<DhikrItem> items = loadScopeItems(category);
        await openCategory(tester, category);
        expect(find.byKey(ValueKey<String>('adhkar-player-${category.id}')), findsOneWidget);
        expect(tester.widget<Text>(find.byKey(const ValueKey<String>('adhkar-category-title'))).data, category.title);
        expect(_title(tester), items.first.title);
        expect(_progress(tester), _position(1, items.length));
        expect(
          tester.widget<Text>(find.byKey(ValueKey<String>('dhikr-text-${items.first.id}'))).data,
          items.first.displayText,
        );
        expect(
          find.byKey(const ValueKey<String>('adhkar-track-toggle')),
          category.hasTracks ? findsOneWidget : findsNothing,
          reason: 'only the three toggle categories carry the switch bar',
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('swiping the whole page moves between adhkar and updates the header', (WidgetTester tester) async {
      final ProviderContainer container = await openCategory(tester, _morning);
      await _swipe(tester, toNext: true);
      expect(container.read(adhkarWirdProvider(morningScope)).index, 1);
      expect(_title(tester), morning[1].title);
      expect(_progress(tester), _position(2, morning.length));
      expect(
        tester.widget<LinearProgressIndicator>(find.byKey(const ValueKey<String>('adhkar-progress-bar'))).value,
        closeTo(2 / morning.length, 0.0001),
      );

      await _swipe(tester, toNext: false);
      expect(container.read(adhkarWirdProvider(morningScope)).index, 0);
      expect(_title(tester), morning.first.title);
      expect(_progress(tester), _position(1, morning.length));
    });

    testWidgets('the lower half is one tap zone: a tap anywhere in it counts with a light haptic',
        (WidgetTester tester) async {
      final List<String> haptics = recordHaptics(tester);
      final ProviderContainer container = await openCategory(tester, _morning);
      final int hundred = _at(morning, 'tasbih_mia_sabahan_wa_masaan');
      await _goTo(tester, container, morningScope, hundred);
      expect(container.read(adhkarWirdProvider(morningScope)).index, hundred);
      final String id = morning[hundred].id;

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

      expect(container.read(adhkarWirdProvider(morningScope)).countOf(hundred), 3);
      expect(tester.widget<Text>(find.byKey(ValueKey<String>('dhikr-remaining-$id'))).data, 'باقٍ ٩٧');
      expect(haptics.where((String h) => h == 'HapticFeedbackType.selectionClick'), hasLength(3));
      expect(haptics.where((String h) => h == 'HapticFeedbackType.mediumImpact'), isEmpty);

      // لمسة على نص الذكر في النصف العلوي لا تُحتسب.
      haptics.clear();
      await tester.tapAt(tester.getCenter(find.byKey(ValueKey<String>('dhikr-text-$id'))));
      await tester.pump(const Duration(milliseconds: 60));
      expect(container.read(adhkarWirdProvider(morningScope)).countOf(hundred), 3);
      expect(haptics, isEmpty);
    });

    testWidgets('reaching the number gives a double medium haptic, a green halo and a permanent lock',
        (WidgetTester tester) async {
      final List<String> haptics = recordHaptics(tester);
      final ProviderContainer container = await openCategory(tester, _morning);
      final int three = _at(morning, 'surat_al_ikhlas_thalathan');
      await _goTo(tester, container, morningScope, three);
      final DhikrItem item = morning[three];
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
      expect(container.read(adhkarWirdProvider(morningScope)).countOf(three), 2);
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
      expect(container.read(adhkarWirdProvider(morningScope)).countOf(three), 3);
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
      expect(container.read(adhkarWirdProvider(morningScope)).countOf(three), 3);
      expect(haptics, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('completing a dhikr locks it and slides to the next page on its own', (WidgetTester tester) async {
      final List<String> haptics = recordHaptics(tester);
      final ProviderContainer container = await openCategory(tester, _morning);
      expect(_pages(tester).page, 0);
      final DhikrItem first = morning.first;

      // الذكر الأول عدده واحد: لمسة واحدة تكمله بالاهتزاز المزدوج لا الخفيف.
      await tester.tap(_zone(first.id));
      await tester.pump(const Duration(milliseconds: 300));
      expect(haptics, <String>['HapticFeedbackType.mediumImpact', 'HapticFeedbackType.mediumImpact']);
      expect(container.read(adhkarWirdProvider(morningScope)).countOf(0), 1);
      expect(find.byKey(ValueKey<String>('dhikr-complete-${first.id}')), findsOneWidget);

      // يبقى على الذكر المكتمل لحظة تُرى فيها الهالة، ثم تنزلق الصفحة وحدها.
      expect(_pages(tester).page, 0);
      expect(_title(tester), first.title);
      await tester.pump(const Duration(milliseconds: 1400));
      await settle(tester);
      expect(container.read(adhkarWirdProvider(morningScope)).index, 1);
      expect(_pages(tester).page, closeTo(1, 0.001));
      expect(_title(tester), morning[1].title);
      expect(_progress(tester), _position(2, morning.length));

      // الذكر الأول بقي مقفلاً خلفنا، والثاني مفتوح للعدّ.
      expect(container.read(adhkarWirdProvider(morningScope)).isDone(morning, 0), isTrue);
      expect(container.read(adhkarWirdProvider(morningScope)).countOf(1), 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the info button opens the sheet with takhrij, the grade, the prophetic virtue and the source',
        (WidgetTester tester) async {
      final ProviderContainer container = await openCategory(tester, _morning);
      final int index = _at(morning, 'sayyid_al_istighfar');
      await _goTo(tester, container, morningScope, index);
      final DhikrItem item = morning[index];
      expect(item.virtue, isNotNull);
      expect(item.grading, isNotNull);
      await tester.tap(find.byKey(const ValueKey<String>('adhkar-info')));
      await settle(tester);

      final Finder sheet = find.byKey(const ValueKey<String>('dhikr-info-sheet'));
      expect(sheet, findsOneWidget);
      final int distinct = item.evidence.map((SourceRef r) => '${r.sourceId}|${r.locator}').toSet().length;
      final String sourceHeading = distinct == 1 ? 'المصدر' : 'المصادر';
      for (final String heading in <String>['التخريج', 'الدرجة', 'الفضل النبوي', sourceHeading]) {
        expect(find.descendant(of: sheet, matching: find.text(heading)), findsOneWidget, reason: heading);
      }
      // الإحالة في التخريج، ونص الشاهد في المصدر.
      for (final SourceRef reference in item.evidence) {
        expect(find.descendant(of: sheet, matching: find.textContaining('رقم ${arabicDigits(reference.locator!)}')),
            findsWidgets);
        expect(find.descendant(of: sheet, matching: find.textContaining(reference.quote!)), findsWidgets);
      }
      // الدرجة سطور مسجّلة في البيانات، بأرقام عربية.
      final Finder grading = find.byKey(const ValueKey<String>('dhikr-info-grading'));
      expect(grading, findsOneWidget);
      for (final String line in item.grading!.split('\n')) {
        expect(find.descendant(of: grading, matching: find.text(arabicDigits(line.trim()))), findsOneWidget,
            reason: line);
      }
      // الحديث صحيح: لا شريط تنبيه ولا ملاحظة اشتقاق.
      expect(find.byKey(const ValueKey<String>('dhikr-info-caution')), findsNothing);
      expect(find.byKey(const ValueKey<String>('dhikr-info-derivation')), findsNothing);
      final Finder virtue = find.descendant(
        of: find.byKey(const ValueKey<String>('dhikr-info-virtue')),
        matching: find.textContaining(item.virtue!),
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
      final int index = _at(morning, 'asbahna_wa_asbaha_al_mulk');
      await _goTo(tester, container, morningScope, index);
      final DhikrItem item = morning[index];
      expect(item.virtue, isNull);
      expect(item.evidence, hasLength(2));
      await tester.tap(find.byKey(const ValueKey<String>('adhkar-info')));
      await settle(tester);

      final Finder sheet = find.byKey(const ValueKey<String>('dhikr-info-sheet'));
      expect(find.descendant(of: sheet, matching: find.text(item.title)), findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.text('المصادر')), findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.text('الدرجة')), findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.text('الفضل النبوي')), findsNothing);
      expect(find.byKey(const ValueKey<String>('dhikr-info-virtue')), findsNothing);
      expect(find.descendant(of: sheet, matching: find.textContaining('رقم ٥٠٧١')), findsWidgets);
      expect(find.descendant(of: sheet, matching: find.textContaining('رقم ٣٣٩٠')), findsWidgets);
    });

    testWidgets('a narration al-Albani weakens carries a caution banner on its card and in its sheet',
        (WidgetTester tester) async {
      final ProviderContainer container = await openCategory(tester, _morning);
      final int weakIndex = _at(morning, 'allahumma_ma_asbaha_bi_min_nima');
      final DhikrItem weak = morning[weakIndex];
      expect(weak.caution, isNotNull);
      await _goTo(tester, container, morningScope, weakIndex);

      final Finder banner = find.byKey(ValueKey<String>('dhikr-caution-${weak.id}'));
      expect(banner, findsOneWidget);
      expect(find.descendant(of: banner, matching: find.text(weak.caution!)), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('adhkar-info')));
      await settle(tester);
      final Finder caution = find.byKey(const ValueKey<String>('dhikr-info-caution'));
      expect(caution, findsOneWidget);
      expect(find.descendant(of: caution, matching: find.text(weak.caution!)), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey<String>('dhikr-info-grading')),
          matching: find.textContaining('ضعيف')), findsWidgets);
      await tester.tapAt(const Offset(200, 40));
      await settle(tester);

      // وحديث صحيح بعده بلا أي شريط.
      await _goTo(tester, container, morningScope, _at(morning, 'sayyid_al_istighfar'));
      expect(find.byKey(ValueKey<String>('dhikr-caution-${morning[_at(morning, 'sayyid_al_istighfar')].id}')),
          findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('the one derived text names its swapped word and the evidence that allows it',
        (WidgetTester tester) async {
      final ProviderContainer container = await openCategory(tester, _morning);
      await selectTrack(tester, 'evening');
      final int index = _at(evening, 'allahumma_ma_amsa_bi_min_nima');
      final DhikrItem derived = evening[index];
      expect(derived.derivation, isNotNull);
      await _goTo(tester, container, eveningScope, index);
      expect(tester.widget<Text>(find.byKey(ValueKey<String>('dhikr-text-${derived.id}'))).data, derived.text);
      expect(derived.text, contains('أَمْسَى'));

      await tester.tap(find.byKey(const ValueKey<String>('adhkar-info')));
      await settle(tester);
      final Finder note = find.byKey(const ValueKey<String>('dhikr-info-derivation'));
      expect(note, findsOneWidget);
      expect(find.descendant(of: note, matching: find.text(derived.derivation!.note)), findsOneWidget);
      expect(find.text('اشتقاق النص'), findsOneWidget);
    });

    testWidgets('finishing a whole track shows the wird-complete banner, and a new wird returns to the first page',
        (WidgetTester tester) async {
      recordHaptics(tester);
      const AdhkarCategory category = AdhkarCategories.homeMasjid;
      final List<DhikrItem> items = loadScopeItems(category, 'home');
      final String scope = scopeKeyOf(category, 'home');
      final ProviderContainer container = await openCategory(tester, category);
      expect(find.byKey(const ValueKey<String>('adhkar-wird-complete')), findsNothing);

      for (int i = 0; i < items.length; i++) {
        expect(items[i].count, 1, reason: items[i].id);
        await tester.tap(_zone(items[i].id));
        await tester.pump(const Duration(milliseconds: 1500));
        await settle(tester);
      }

      expect(container.read(adhkarWirdProvider(scope)).isComplete(items), isTrue);
      expect(find.byKey(const ValueKey<String>('adhkar-wird-complete')), findsOneWidget);
      expect(_progress(tester), _position(items.length, items.length));
      expect(container.read(adhkarWirdProvider(scope)).index, items.length - 1, reason: 'nowhere left to advance to');

      // المسار الآخر وِرد مستقل لم يبدأ: لا شارة إتمام فيه.
      await selectTrack(tester, 'masjid');
      expect(find.byKey(const ValueKey<String>('adhkar-wird-complete')), findsNothing);
      final List<DhikrItem> masjid = loadScopeItems(category, 'masjid');
      expect(_progress(tester), _position(1, masjid.length));
      await selectTrack(tester, 'home');
      expect(find.byKey(const ValueKey<String>('adhkar-wird-complete')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('adhkar-restart')));
      await settle(tester);
      expect(find.byKey(const ValueKey<String>('adhkar-wird-complete')), findsNothing);
      expect(container.read(adhkarWirdProvider(scope)).counts, everyElement(0));
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
      expect(container.read(adhkarWirdProvider(morningScope)).index, 1);

      await tester.tap(find.byKey(const ValueKey<String>('adhkar-back')));
      await settle(tester);
      expect(find.byKey(const ValueKey<String>('adhkar-hub')), findsOneWidget);
      expect(find.byKey(ValueKey<String>('adhkar-player-${_morning.id}')), findsNothing);

      await tester.tap(find.byKey(cardKey(_morning)));
      await settle(tester);
      expect(_progress(tester), _position(2, morning.length));
      expect(_title(tester), morning[1].title);
      expect(container.read(adhkarWirdProvider(morningScope)).isDone(morning, 0), isTrue);
    });

    testWidgets('a quick back-and-forth of the current dhikr leaves the page on the chosen one',
        (WidgetTester tester) async {
      final ProviderContainer container = await openCategory(tester, _morning);
      final AdhkarWirdController wird = container.read(adhkarWirdProvider(morningScope).notifier);
      wird.select(1);
      await tester.pump(const Duration(milliseconds: 40));
      wird.select(0);
      await settle(tester);
      expect(container.read(adhkarWirdProvider(morningScope)).index, 0);
      expect(_pages(tester).page, closeTo(0, 0.001));
      expect(_title(tester), morning.first.title);
    });

    testWidgets('the screen survives a narrow phone with the largest fonts, and a long text scrolls inside',
        (WidgetTester tester) async {
      final ProviderContainer container =
          await openCategory(tester, _morning, size: const Size(360, 740), systemTextScale: 1.3);
      expect(tester.takeException(), isNull);

      // نص آية الكرسي طويل: يتمرر داخل منطقته ولا يدفع العدّاد خارج الشاشة.
      final Finder scroll = find.descendant(
        of: find.byKey(ValueKey<String>('dhikr-text-scroll-${morning.first.id}')),
        matching: find.byType(Scrollable),
      );
      final ScrollableState scrollable = tester.state<ScrollableState>(scroll);
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      await tester.drag(scroll, const Offset(0, -200));
      await tester.pump(const Duration(milliseconds: 100));
      expect(scrollable.position.pixels, greaterThan(0));

      final int hundred = _at(morning, 'tasbih_mia_sabahan_wa_masaan');
      await _goTo(tester, container, morningScope, hundred);
      expect(tester.takeException(), isNull);
      final Rect ring = tester.getRect(find.byKey(ValueKey<String>('dhikr-remaining-${morning[hundred].id}')));
      expect(ring.bottom, lessThanOrEqualTo(740));
      expect(ring.left, greaterThanOrEqualTo(0));
      expect(ring.right, lessThanOrEqualTo(360));

      await tester.tap(find.byKey(const ValueKey<String>('adhkar-info')));
      await settle(tester);
      expect(find.byKey(const ValueKey<String>('dhikr-info-sheet')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the track toggle', () {
    const Map<String, List<String>> labels = <String, List<String>>{
      'adhkar_morning_evening': <String>['☀️ أذكار الصباح', '🌙 أذكار المساء'],
      'adhkar_sleep': <String>['🛌 أذكار النوم', '🌅 أذكار الاستيقاظ'],
      'adhkar_home_masjid': <String>['🏠 أذكار المنزل (دخول وخروج)', '🕌 أذكار المسجد (ذهاب ودخول وخروج)'],
    };

    test('the three toggle categories carry the owner labels verbatim, and the others have none', () {
      for (final AdhkarCategory category in AdhkarCategories.all) {
        expect(category.tracks.map((AdhkarTrack t) => t.label).toList(), labels[category.id] ?? <String>[],
            reason: category.id);
        expect(category.hasTracks, labels.containsKey(category.id), reason: category.id);
      }
      expect(AdhkarCategories.morningEvening.tracks.map((AdhkarTrack t) => t.id), <String>['morning', 'evening']);
      expect(AdhkarCategories.sleep.tracks.map((AdhkarTrack t) => t.id), <String>['sleep', 'wake']);
      expect(AdhkarCategories.homeMasjid.tracks.map((AdhkarTrack t) => t.id), <String>['home', 'masjid']);
    });

    testWidgets('morning and evening: two segments, morning first, and the list follows the choice',
        (WidgetTester tester) async {
      final ProviderContainer container = await openCategory(tester, _morning);
      final Finder bar = find.byKey(const ValueKey<String>('adhkar-track-toggle'));
      expect(bar, findsOneWidget);
      expect(tester.widget<AdhkarTrackToggle>(bar).selectedId, 'morning');
      for (final String label in labels['adhkar_morning_evening']!) {
        expect(find.descendant(of: bar, matching: find.text(label)), findsOneWidget, reason: label);
      }
      // الصباح أولاً ثم المساء، من اليمين إلى اليسار.
      expect(tester.getCenter(find.byKey(const ValueKey<String>('adhkar-track-morning'))).dx,
          greaterThan(tester.getCenter(find.byKey(const ValueKey<String>('adhkar-track-evening'))).dx));
      expect(_progress(tester), _position(1, morning.length));

      await selectTrack(tester, 'evening');
      expect(tester.widget<AdhkarTrackToggle>(bar).selectedId, 'evening');
      expect(_progress(tester), _position(1, evening.length));
      expect(_title(tester), evening.first.title);
      expect(find.byKey(const ValueKey<String>('adhkar-body-adhkar_morning_evening#evening')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('adhkar-body-adhkar_morning_evening#morning')), findsNothing);

      // ذكر المساء وحده يظهر عند الوصول إليه، والصباحي وحده غائب.
      await _goTo(tester, container, eveningScope, _at(evening, 'amsayna_wa_amsal_mulk'));
      expect(find.byKey(const ValueKey<String>('dhikr-text-amsayna_wa_amsal_mulk')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('dhikr-text-asbahna_wa_asbaha_al_mulk')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('each track keeps its own place and counter when you switch away and back',
        (WidgetTester tester) async {
      recordHaptics(tester);
      final ProviderContainer container = await openCategory(tester, _morning);
      await tester.tap(_zone(morning.first.id));
      await tester.pump(const Duration(milliseconds: 1500));
      await settle(tester);
      expect(container.read(adhkarWirdProvider(morningScope)).index, 1);
      expect(_progress(tester), _position(2, morning.length));

      await selectTrack(tester, 'evening');
      expect(container.read(adhkarWirdProvider(eveningScope)).counts, everyElement(0),
          reason: 'the evening wird has not been touched');
      expect(_progress(tester), _position(1, evening.length));

      await selectTrack(tester, 'morning');
      expect(_progress(tester), _position(2, morning.length));
      expect(_title(tester), morning[1].title);
      expect(container.read(adhkarWirdProvider(morningScope)).isDone(morning, 0), isTrue);
    });

    for (final MapEntry<String, List<String>> entry in labels.entries) {
      testWidgets('${entry.key}: both owner labels are shown whole on a narrow phone with the largest fonts',
          (WidgetTester tester) async {
        final AdhkarCategory category = AdhkarCategories.byId(entry.key)!;
        await openCategory(tester, category, size: const Size(320, 640), systemTextScale: 1.3);
        expect(tester.takeException(), isNull);
        final Finder bar = find.byKey(const ValueKey<String>('adhkar-track-toggle'));
        final Rect barRect = tester.getRect(bar);
        expect(barRect.left, greaterThanOrEqualTo(0));
        expect(barRect.right, lessThanOrEqualTo(320));
        for (final String label in entry.value) {
          final Finder text = find.descendant(of: bar, matching: find.text(label));
          expect(text, findsOneWidget, reason: label);
          final Rect rect = tester.getRect(text);
          expect(rect.left, greaterThanOrEqualTo(barRect.left));
          expect(rect.right, lessThanOrEqualTo(barRect.right));
        }
        // الشريط لا يلتهم الشاشة: ما بعده من الصفحات يبقى ظاهراً مع عدّاده.
        expect(tester.getRect(find.byKey(const ValueKey<String>('adhkar-pages'))).height, greaterThan(200));

        // والتبديل يعمل هناك كذلك.
        await selectTrack(tester, category.tracks.last.id);
        expect(tester.takeException(), isNull);
        expect(tester.widget<AdhkarTrackToggle>(bar).selectedId, category.tracks.last.id);
      });
    }
  });
}
