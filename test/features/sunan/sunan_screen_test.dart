// اختبارات شاشة السنن المهجورة: شاشة مرجعية مستقلة عن مشغّل الأذكار، بشريط تصفية علوي من ستة أزرار
// («الكل» والأبواب الخمسة)، وبطاقة مستقلة لكل سنة بعنوانها ووقتها وكيفيتها وأدلتها المشكولة بمصدرها ودرجتها،
// ولا عدّاد ولا صفحات تركيز فيها، وتتسع للهاتف الضيق مع الخط الكبير.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/core/content/citation.dart';
import 'package:hadith_platform/core/content/models/content_models.dart';
import 'package:hadith_platform/core/content/widgets/source_quote_tile.dart';
import 'package:hadith_platform/core/text/arabic_digits.dart';
import 'package:hadith_platform/core/ui/smooth_surface.dart';
import 'package:hadith_platform/features/sunan/application/sunan_providers.dart';
import 'package:hadith_platform/features/sunan/data/models/sunan.dart';
import 'package:hadith_platform/features/sunan/domain/sunan_info.dart';
import 'package:hadith_platform/features/sunan/presentation/sunan_screen.dart';

import '../../support/adhkar_support.dart';
import '../../support/app_harness.dart';

/// يفتح التطبيق على مركز الأذكار ثم شاشة السنن، وينتظر تحميل ملفها.
Future<ProviderContainer> _openSunan(
  WidgetTester tester, {
  Size size = const Size(412, 915),
  double systemTextScale = 1,
}) async {
  final ProviderContainer container = await openHub(tester, size: size, systemTextScale: systemTextScale);
  await revealCard(tester, find.byKey(sunanCardKey));
  await tester.tap(find.byKey(sunanCardKey));
  await settle(tester);
  await container.read(sunanCatalogProvider.future);
  await settle(tester);
  return container;
}

ValueKey<String> _filterKey(SunnahBab? bab) => ValueKey<String>('sunan-filter-${bab?.wire ?? 'all'}');

/// يضغط زر تصفية (الشريط يتمرر أفقياً فقد يكون الزر خارج الشاشة).
Future<void> _tapFilter(WidgetTester tester, SunnahBab? bab) async {
  await tester.ensureVisible(find.byKey(_filterKey(bab)));
  await tester.pump();
  await tester.tap(find.byKey(_filterKey(bab)));
  await settle(tester);
}

/// قائمة البطاقات الحالية للباب المختار.
Finder _list(SunnahBab? bab) => find.byKey(ValueKey<String>('sunan-list-${bab?.wire ?? 'all'}'));

/// يمرر القائمة حتى تظهر بطاقة السنة (القائمة كسولة).
Future<void> _reveal(WidgetTester tester, SunnahBab? bab, String id) async {
  await tester.scrollUntilVisible(
    find.byKey(ValueKey<String>('sunnah-card-$id')),
    900,
    scrollable: find.descendant(of: _list(bab), matching: find.byType(Scrollable)),
    maxScrolls: 400,
  );
  await tester.pump();
}

String _count(WidgetTester tester) => tester.widget<Text>(find.byKey(const ValueKey<String>('sunan-count'))).data!;

bool _isSelected(WidgetTester tester, SunnahBab? bab) {
  return tester.widget<SmoothSurface>(find.byKey(_filterKey(bab))).onTap == null;
}

void main() {
  final List<SunnahItem> items = loadSunan().itemsInOrder;
  final SourceCatalog sources = SourceCatalog.fromJson(loadJson('assets/data/catalogs/sources.json'));
  final String total = arabicDigits(items.length);

  group('the sunan screen', () {
    testWidgets('opens on all the cards, with the title, the count and the six filter buttons in order',
        (WidgetTester tester) async {
      await _openSunan(tester);
      expect(find.byType(SunanScreen), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('sunan-title'))).data, SunanInfo.title);
      expect(_count(tester), '$total سنة بأدلتها');

      final List<MapEntry<SunnahBab?, String>> chips = <MapEntry<SunnahBab?, String>>[
        const MapEntry<SunnahBab?, String>(null, 'الكل'),
        for (final SunnahBab bab in SunnahBab.values) MapEntry<SunnahBab?, String>(bab, bab.label),
      ];
      expect(chips.map((MapEntry<SunnahBab?, String> e) => e.value).toList(), <String>[
        'الكل',
        'الطهارة والصلاة',
        'الطعام والشراب',
        'المنزل والخروج',
        'النوم واللباس',
        'المجالس والآداب',
      ]);
      double previous = double.infinity;
      for (final MapEntry<SunnahBab?, String> chip in chips) {
        expect(find.descendant(of: find.byKey(_filterKey(chip.key)), matching: find.text(chip.value)), findsOneWidget,
            reason: chip.value);
        final double dx = tester.getCenter(find.byKey(_filterKey(chip.key))).dx;
        expect(dx, lessThan(previous), reason: 'right to left: ${chip.value}');
        previous = dx;
      }
      expect(_isSelected(tester, null), isTrue);
      for (final SunnahBab bab in SunnahBab.values) {
        expect(_isSelected(tester, bab), isFalse, reason: bab.wire);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('it is not the focus player: no pages, no counter, no progress bar', (WidgetTester tester) async {
      await _openSunan(tester);
      expect(find.byType(PageView), findsNothing);
      expect(find.byKey(const ValueKey<String>('adhkar-progress-bar')), findsNothing);
      expect(find.byKey(const ValueKey<String>('adhkar-pages')), findsNothing);
      expect(find.textContaining('باقٍ'), findsNothing);
    });

    testWidgets('the first card is the first sunnah: title, how and when, evidence with its source, and grading',
        (WidgetTester tester) async {
      await _openSunan(tester);
      final SunnahItem first = items.first;
      final Finder card = find.byKey(ValueKey<String>('sunnah-card-${first.id}'));
      expect(card, findsOneWidget);
      expect(tester.widget<Text>(find.byKey(ValueKey<String>('sunnah-title-${first.id}'))).data, first.title);
      expect(tester.widget<SelectableText>(find.byKey(ValueKey<String>('sunnah-text-${first.id}'))).data, first.text);
      expect(find.descendant(of: card, matching: find.text(first.bab.label)), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('وقتها وكيفيتها')), findsOneWidget);
      for (int i = 0; i < first.evidence.length; i++) {
        final SourceRef reference = first.evidence[i];
        final Finder tile = find.byKey(ValueKey<String>('sunnah-evidence-${first.id}-$i'));
        expect(tile, findsOneWidget);
        expect(tester.widget<SelectableText>(find.descendant(of: tile, matching: find.byType(SelectableText))).data,
            '«${reference.quote}»');
        expect(
          find.descendant(of: tile, matching: find.text(formatCitation(sources.byId(reference.sourceId), reference))),
          findsOneWidget,
        );
      }
      for (final String line in first.grading!.split('\n')) {
        expect(find.descendant(of: card, matching: find.text(arabicDigits(line.trim()))), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('each filter button shows only the cards of its bab, with the count, and «الكل» brings them all back',
        (WidgetTester tester) async {
      await _openSunan(tester);
      for (final SunnahBab bab in SunnahBab.values) {
        await _tapFilter(tester, bab);
        final List<SunnahItem> inBab = items.where((SunnahItem i) => i.bab == bab).toList();
        expect(_count(tester), '${arabicDigits(inBab.length)} من $total سنة', reason: bab.wire);
        expect(_isSelected(tester, bab), isTrue, reason: bab.wire);
        expect(_isSelected(tester, null), isFalse, reason: bab.wire);
        expect(find.byKey(ValueKey<String>('sunnah-card-${inBab.first.id}')), findsOneWidget,
            reason: 'the list starts at the top of the bab: ${bab.wire}');
        for (final SunnahItem other in items.where((SunnahItem i) => i.bab != bab)) {
          expect(find.byKey(ValueKey<String>('sunnah-card-${other.id}')), findsNothing, reason: other.id);
        }
        // آخر بطاقة في الباب تُبلغ بالتمرير، وفيها وسم الباب نفسه.
        await _reveal(tester, bab, inBab.last.id);
        expect(
          find.descendant(
            of: find.byKey(ValueKey<String>('sunnah-card-${inBab.last.id}')),
            matching: find.text(bab.label),
          ),
          findsOneWidget,
        );
      }
      await _tapFilter(tester, null);
      expect(_count(tester), '$total سنة بأدلتها');
      expect(_isSelected(tester, null), isTrue);
      expect(find.byKey(ValueKey<String>('sunnah-card-${items.first.id}')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every card of the file is independent: its title, text, bab, virtue only if stated, and every proof',
        (WidgetTester tester) async {
      await _openSunan(tester);
      for (final SunnahItem item in items) {
        await _reveal(tester, null, item.id);
        final Finder card = find.byKey(ValueKey<String>('sunnah-card-${item.id}'));
        expect(card, findsOneWidget, reason: item.id);
        expect(tester.widget<Text>(find.byKey(ValueKey<String>('sunnah-title-${item.id}'))).data, item.title,
            reason: item.id);
        expect(tester.widget<SelectableText>(find.byKey(ValueKey<String>('sunnah-text-${item.id}'))).data, item.text,
            reason: item.id);
        expect(find.descendant(of: card, matching: find.text(item.bab.label)), findsOneWidget, reason: item.id);
        expect(find.descendant(of: card, matching: find.byType(SourceQuoteTile)), findsNWidgets(item.evidence.length),
            reason: item.id);
        expect(
          find.byKey(ValueKey<String>('sunnah-virtue-${item.id}')),
          item.virtue == null ? findsNothing : findsOneWidget,
          reason: item.id,
        );
        expect(find.byKey(ValueKey<String>('sunnah-caution-${item.id}')), findsNothing, reason: item.id);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('a narrow phone with the largest fonts lays everything out without overflow and reaches every button',
        (WidgetTester tester) async {
      await _openSunan(tester, size: const Size(320, 640), systemTextScale: 1.3);
      expect(tester.takeException(), isNull);
      final Rect bar = tester.getRect(find.byKey(const ValueKey<String>('sunan-filter-bar')));
      expect(bar.left, greaterThanOrEqualTo(0));
      expect(bar.right, lessThanOrEqualTo(320));
      // الشريط يتمرر فيبلغ كل زر ويعمل.
      for (final SunnahBab bab in SunnahBab.values) {
        await _tapFilter(tester, bab);
        expect(_isSelected(tester, bab), isTrue, reason: bab.wire);
        expect(tester.takeException(), isNull, reason: bab.wire);
        final Rect rect = tester.getRect(find.byKey(ValueKey<String>('sunnah-card-${items.firstWhere((SunnahItem i) => i.bab == bab).id}')));
        expect(rect.left, greaterThanOrEqualTo(0), reason: bab.wire);
        expect(rect.right, lessThanOrEqualTo(320), reason: bab.wire);
      }
      await _tapFilter(tester, null);
      for (final SunnahItem item in items.take(6)) {
        await _reveal(tester, null, item.id);
        final Rect rect = tester.getRect(find.byKey(ValueKey<String>('sunnah-card-${item.id}')));
        expect(rect.left, greaterThanOrEqualTo(0), reason: item.id);
        expect(rect.right, lessThanOrEqualTo(320), reason: item.id);
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('the sunan providers', () {
    test('the items provider is empty until the file loads, then holds all the cards in order', () async {
      final ProviderContainer container = makeContainer();
      expect(container.read(sunanItemsProvider), isEmpty);
      final SunanCatalog loaded = await container.read(sunanCatalogProvider.future);
      expect(loaded.items, hasLength(items.length));
      expect(container.read(sunanItemsProvider).map((SunnahItem i) => i.id).toList(),
          items.map((SunnahItem i) => i.id).toList());
    });
  });
}
