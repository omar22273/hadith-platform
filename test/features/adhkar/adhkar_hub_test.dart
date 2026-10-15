// اختبارات مركز الأذكار: سبع بطاقات كبيرة (خمس فئات أذكار والسنن المهجورة والسبحة الذكية) بحواف Squircle،
// تفتح كل منها شاشتها، ويعود منها زر الرجوع إلى المركز، ولا يظهر في المركز أي نص نبوي
// ولا عبارة داخلية.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/core/text/arabic_digits.dart';
import 'package:hadith_platform/core/ui/smooth_surface.dart';
import 'package:hadith_platform/features/adhkar/application/sebha_controller.dart';
import 'package:hadith_platform/features/adhkar/data/models/adhkar.dart';
import 'package:hadith_platform/features/adhkar/domain/adhkar_category.dart';
import 'package:hadith_platform/features/adhkar/presentation/adhkar_player_screen.dart';
import 'package:hadith_platform/features/adhkar/presentation/adhkar_screen.dart';
import 'package:hadith_platform/features/adhkar/presentation/sebha_screen.dart';
import 'package:hadith_platform/features/sunan/data/models/sunan.dart';
import 'package:hadith_platform/features/sunan/domain/sunan_info.dart';
import 'package:hadith_platform/features/sunan/presentation/sunan_screen.dart';
import 'package:smooth_corner/smooth_corner.dart';

import '../../support/adhkar_support.dart';
import '../../support/app_harness.dart';

/// عناوين البطاقات السبع كما حددها مالك المنتج، بترتيب العرض.
const List<String> _cardTitles = <String>[
  'أذكار الصباح والمساء',
  'أذكار النوم والاستيقاظ',
  'أذكار أدبار الصلوات المكتوبة',
  'أذكار دخول وخروج المنزل والمسجد',
  'السنن النبوية المهجورة',
  'جامع الأدعية المأثورة',
  'السبحة الذكية',
];

void main() {
  group('the hub', () {
    testWidgets('the third tab opens the hub with a title and exactly seven cards, in the requested order',
        (WidgetTester tester) async {
      await openHub(tester);
      expect(find.byType(AdhkarScreen), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('adhkar-hub-title'))).data, 'مركز الأذكار');
      // لا مشغّل مفتوح ولا ذكر معروض: المركز بوابات فقط.
      expect(find.byType(AdhkarPlayerScreen), findsNothing);
      expect(find.byType(SebhaScreen), findsNothing);

      final List<Finder> cards = <Finder>[
        find.byKey(cardKey(AdhkarCategories.morningEvening)),
        find.byKey(cardKey(AdhkarCategories.sleep)),
        find.byKey(cardKey(AdhkarCategories.afterPrayer)),
        find.byKey(cardKey(AdhkarCategories.homeMasjid)),
        find.byKey(sunanCardKey),
        find.byKey(cardKey(AdhkarCategories.duas)),
        find.byKey(sebhaCardKey),
      ];
      expect(cards, hasLength(7));
      double previousTop = -1;
      for (int i = 0; i < cards.length; i++) {
        expect(cards[i], findsOneWidget, reason: _cardTitles[i]);
        expect(find.descendant(of: cards[i], matching: find.text(_cardTitles[i])), findsOneWidget);
        final double top = tester.getTopLeft(cards[i]).dy;
        expect(top, greaterThan(previousTop), reason: 'cards are stacked in order: ${_cardTitles[i]}');
        previousTop = top;
      }
      // لا بطاقة ثامنة: خمس فئات أذكار والسنن والسبحة فقط.
      expect(find.byType(SmoothSurface), findsNWidgets(7));
    });

    testWidgets('every card is a smooth squircle surface, with its subtitle and the number of its adhkar',
        (WidgetTester tester) async {
      await openHub(tester);
      for (final AdhkarCategory category in AdhkarCategories.all) {
        final Finder card = find.byKey(cardKey(category));
        expect(find.descendant(of: card, matching: find.text(category.subtitle)), findsOneWidget);
        final int total = loadCategory(category).items.length;
        expect(
          tester.widget<Text>(find.byKey(ValueKey<String>('adhkar-card-count-${category.id}'))).data,
          arabicDigits(total),
          reason: category.id,
        );
        final Iterable<DecoratedBox> boxes = tester.widgetList<DecoratedBox>(
          find.descendant(of: card, matching: find.byType(DecoratedBox)),
        );
        expect(
          boxes.any((DecoratedBox b) => b.decoration is ShapeDecoration && (b.decoration as ShapeDecoration).shape is SmoothRectangleBorder),
          isTrue,
          reason: 'squircle: ${category.id}',
        );
      }
      expect(find.byKey(sebhaCardKey), findsOneWidget);
    });

    testWidgets('the sunan card carries its subtitle and the number of its cards, and is a squircle',
        (WidgetTester tester) async {
      await openHub(tester);
      final Finder card = find.byKey(sunanCardKey);
      expect(find.descendant(of: card, matching: find.text(SunanInfo.subtitle)), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(ValueKey<String>('adhkar-card-count-${SunanInfo.id}'))).data,
        arabicDigits(loadSunan().items.length),
      );
      final Iterable<DecoratedBox> boxes = tester.widgetList<DecoratedBox>(
        find.descendant(of: card, matching: find.byType(DecoratedBox)),
      );
      expect(
        boxes.any((DecoratedBox b) => b.decoration is ShapeDecoration && (b.decoration as ShapeDecoration).shape is SmoothRectangleBorder),
        isTrue,
      );
    });

    testWidgets('the subtitles name the requested subjects: abandoned sunan and the supplications',
        (WidgetTester tester) async {
      await openHub(tester);
      expect(find.textContaining('ركعتا الوضوء'), findsOneWidget);
      expect(find.textContaining('لعق الأصابع'), findsOneWidget);
      expect(find.textContaining('الابتداء باليمين'), findsOneWidget);
      expect(find.textContaining('الركوب'), findsOneWidget);
      expect(find.textContaining('السفر'), findsOneWidget);
      expect(find.textContaining('الكرب'), findsOneWidget);
      expect(find.textContaining('نزول الغيث'), findsOneWidget);
    });

    testWidgets('the hub shows no prophetic text, no takhrij and no internal phrase', (WidgetTester tester) async {
      await openHub(tester);
      for (final AdhkarCategory category in AdhkarCategories.all) {
        final List<DhikrItem> items = loadCategory(category).items;
        for (final DhikrItem item in items) {
          expect(find.textContaining(item.text), findsNothing, reason: item.id);
        }
      }
      for (final SunnahItem item in loadSunan().items) {
        expect(find.textContaining(item.text), findsNothing, reason: item.id);
      }
      expect(find.textContaining('بانتظار المراجعة'), findsNothing);
      expect(find.textContaining('pending'), findsNothing);
      expect(find.textContaining('[?]'), findsNothing);
      expect(find.text('التخريج'), findsNothing);
    });

    testWidgets('a category card opens its player, and the back button returns to the hub with the tab bar',
        (WidgetTester tester) async {
      await openHub(tester);
      await tester.tap(find.byKey(cardKey(AdhkarCategories.duas)));
      await settle(tester);
      expect(find.byType(AdhkarPlayerScreen), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('adhkar-hub')), findsNothing);
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('adhkar-category-title'))).data,
          AdhkarCategories.duas.title);

      await tester.tap(find.byKey(const ValueKey<String>('adhkar-back')));
      await settle(tester);
      expect(find.byType(AdhkarPlayerScreen), findsNothing);
      expect(find.byKey(const ValueKey<String>('adhkar-hub')), findsOneWidget);
      expect(navLabel('وِرد الأذكار'), findsOneWidget);
    });

    testWidgets('the sunan card opens the dedicated sunan screen, not the focus player, and back returns',
        (WidgetTester tester) async {
      await openHub(tester);
      await tester.tap(find.byKey(sunanCardKey));
      await settle(tester);
      expect(find.byType(SunanScreen), findsOneWidget);
      expect(find.byType(AdhkarPlayerScreen), findsNothing);
      expect(find.byKey(const ValueKey<String>('adhkar-hub')), findsNothing);
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('sunan-title'))).data, SunanInfo.title);

      await tester.tap(find.byKey(const ValueKey<String>('sunan-back')));
      await settle(tester);
      expect(find.byType(SunanScreen), findsNothing);
      expect(find.byKey(const ValueKey<String>('adhkar-hub')), findsOneWidget);
      expect(navLabel('وِرد الأذكار'), findsOneWidget);
    });

    testWidgets('the sebha card opens the sebha, and back returns to the hub', (WidgetTester tester) async {
      await openHub(tester);
      await tester.tap(find.byKey(sebhaCardKey));
      await settle(tester);
      expect(find.byType(SebhaScreen), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('adhkar-hub')), findsNothing);

      await tester.tap(find.byKey(const ValueKey<String>('sebha-back')));
      await settle(tester);
      expect(find.byType(SebhaScreen), findsNothing);
      expect(find.byKey(const ValueKey<String>('adhkar-hub')), findsOneWidget);
    });

    testWidgets('the sebha card shows the saved grand total once anything has been counted',
        (WidgetTester tester) async {
      final ProviderContainer container = await openHub(tester);
      Text subtitle() => tester.widget<Text>(find.byKey(const ValueKey<String>('adhkar-card-sebha-subtitle')));
      expect(subtitle().data, contains('٣٣'));
      expect(subtitle().data, isNot(contains('مجموع')));

      final SebhaController sebha = container.read(sebhaProvider.notifier);
      for (int i = 0; i < 7; i++) {
        sebha.tap();
      }
      await settle(tester);
      expect(subtitle().data, 'مجموع ما سبّحتَه: ٧');
    });

    testWidgets('a narrow phone with large fonts lays the cards out without overflow and reaches every card',
        (WidgetTester tester) async {
      await openHub(tester, size: const Size(360, 740), systemTextScale: 1.3);
      expect(tester.takeException(), isNull);
      for (final AdhkarCategory category in AdhkarCategories.all) {
        await revealCard(tester, find.byKey(cardKey(category)));
        final Rect rect = tester.getRect(find.byKey(cardKey(category)));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(360));
      }
      await revealCard(tester, find.byKey(sunanCardKey));
      expect(tester.getRect(find.byKey(sunanCardKey)).left, greaterThanOrEqualTo(0));
      expect(tester.getRect(find.byKey(sunanCardKey)).right, lessThanOrEqualTo(360));
      await revealCard(tester, find.byKey(sebhaCardKey));
      expect(tester.getRect(find.byKey(sebhaCardKey)).right, lessThanOrEqualTo(360));
      expect(tester.takeException(), isNull);
    });
  });
}
