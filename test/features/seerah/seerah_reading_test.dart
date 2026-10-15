// اختبارات الطبقة الثانية في شاشة المحطة، «الرواية التاريخية المطولة»: فصول قرائية
// بمقاطع حرفية موثقة تحتها شارة المصدر والصفحة، بخط تراثي يتبع حجم الخط في الإعدادات
// وشريط لتكبيره؛ وهي مطوية تحت طبقة المعايشة، ومفتوحة من البدء في المحطة التي لم
// تُكتب طبقتها الأولى بعد، وتحتها شواهد المشاهد الثلاثة القابلة للطي.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/core/content/citation.dart';
import 'package:hadith_platform/core/content/models/content_models.dart';
import 'package:hadith_platform/core/preferences/reading_preferences.dart';
import 'package:hadith_platform/core/storage/key_value_store.dart';
import 'package:hadith_platform/core/text/arabic_digits.dart';
import 'package:hadith_platform/features/seerah/application/seerah_providers.dart';
import 'package:hadith_platform/features/seerah/data/models/seerah_station.dart';
import 'package:hadith_platform/features/seerah/presentation/widgets/seerah_labels.dart';
import 'package:hadith_platform/features/seerah/presentation/widgets/seerah_reading_section.dart';

import '../../support/app_harness.dart';
import '../../support/seerah_support.dart';

Finder _key(String name) => find.byKey(ValueKey<String>(name));

void main() {
  final SeerahDataset dataset = loadSeerahDataset();
  final SourceCatalog sources = loadSourceCatalog();
  final SeerahStationModel first = dataset.chronological.first;
  final SeerahStationModel hijra = dataset.stationById('hijra_masjid_nabawi')!;

  Future<ProviderContainer> open(
    WidgetTester tester,
    SeerahStationModel station, {
    SeerahDataset? custom,
    Map<String, String>? stored,
    Size size = const Size(412, 1800),
  }) {
    return openStationScreen(
      tester,
      dataset: custom ?? dataset,
      stationId: station.id,
      stored: stored,
      size: size,
    );
  }

  double fontSizeOf(WidgetTester tester, String key) {
    return tester.widget<SelectableText>(_key(key)).style!.fontSize!;
  }

  Map<String, String> storedFontSize(num size) {
    return <String, String>{
      StorageKeys.readingPreferences: jsonEncode(<String, Object>{
        'matnFontSize': size,
        'textScale': 1,
        'matnFont': 'amiri',
      }),
    };
  }

  group('with the experience layer written', () {
    testWidgets('the chapters are folded at first, titled as asked, and open then fold on tap', (WidgetTester tester) async {
      await open(tester, first);
      await scrollStationTo(tester, _key('station-reading'));
      expect(find.text('الرواية التاريخية المطولة'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('station-reading'),
          matching: find.textContaining(chaptersLabel(first.chapters.length)),
        ),
        findsOneWidget,
      );
      expect(_key('chapter-${first.chapters.first.id}'), findsNothing);
      expect(_key('narrative-font-slider'), findsNothing);

      await tester.tap(find.text(seerahReadingTitle));
      await settle(tester);
      expect(_key('chapter-${first.chapters.first.id}'), findsOneWidget);
      expect(_key('narrative-font-slider'), findsOneWidget);
      expect(find.text('الفصل ١ من ${arabicDigits(first.chapters.length)}'), findsOneWidget);
      expect(find.text(first.chapters.first.title), findsOneWidget);

      await tester.tap(find.text(seerahReadingTitle));
      await settle(tester);
      expect(_key('chapter-${first.chapters.first.id}'), findsNothing, reason: 'it folds again');
    });

    testWidgets('each passage is the verbatim quote, with a source and page badge under it', (WidgetTester tester) async {
      await open(tester, first);
      await scrollStationTo(tester, _key('station-reading'));
      await tester.tap(find.text(seerahReadingTitle));
      await settle(tester);

      final SeerahChapter chapter = first.chapters.first;
      for (int p = 0; p < chapter.passages.length; p++) {
        final SourceRef passage = chapter.passages[p];
        await scrollStationTo(tester, _key('passage-${chapter.id}-$p'));
        expect(tester.widget<SelectableText>(_key('passage-${chapter.id}-$p')).data, passage.quote);
        final String citation = formatCitation(sources.byId(passage.sourceId), passage);
        expect(
          find.descendant(of: _key('passage-badge-${chapter.id}-$p'), matching: find.text(citation)),
          findsOneWidget,
        );
      }
      // الصفحة بأرقام عربية: «ج١ ص١٥٧».
      expect(find.textContaining('ج١ ص١٥٧'), findsWidgets);
    });

    testWidgets('a badge opens the sheet of the edition the passage was taken from', (WidgetTester tester) async {
      await open(tester, first);
      await scrollStationTo(tester, _key('station-reading'));
      await tester.tap(find.text(seerahReadingTitle));
      await settle(tester);
      await scrollStationTo(tester, _key('passage-badge-c1-0'));

      await tester.tap(_key('passage-badge-c1-0'));
      await settle(tester);
      final Finder sheet = _key('passage-source-sheet');
      expect(sheet, findsOneWidget);
      final SourceWork work = sources.byId(first.chapters.first.passages.first.sourceId)!;
      expect(find.descendant(of: sheet, matching: find.text(work.title)), findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.textContaining(work.author)), findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.textContaining('الناشر: ${work.edition!.publisher}')), findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.textContaining('منقول بلفظه')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the passages use a heritage font tied to the settings font size', (WidgetTester tester) async {
      final ProviderContainer container = await open(tester, first, stored: storedFontSize(38));
      await scrollStationTo(tester, _key('station-reading'));
      await tester.tap(find.text(seerahReadingTitle));
      await settle(tester);
      await scrollStationTo(tester, _key('passage-c1-0'));

      final SelectableText passage = tester.widget<SelectableText>(_key('passage-c1-0'));
      expect(passage.style!.fontFamily, 'Amiri');
      expect(fontSizeOf(tester, 'passage-c1-0'), closeTo(21 * 38 / 27, 0.01));

      // تغيير الحجم من الإعدادات (المتحكم نفسه) ينعكس فوراً على الرواية.
      container.read(readingPreferencesProvider.notifier).setMatnFontSize(22);
      await settle(tester);
      expect(fontSizeOf(tester, 'passage-c1-0'), closeTo(21 * 22 / 27, 0.01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the slider moves the same preference the settings use, and saves it', (WidgetTester tester) async {
      final ProviderContainer container = await open(tester, first, stored: storedFontSize(30));
      expect(container.read(readingPreferencesProvider).matnFontSize, 30);
      await scrollStationTo(tester, _key('station-reading'));
      await tester.tap(find.text(seerahReadingTitle));
      await settle(tester);
      await scrollStationTo(tester, _key('passage-c1-0'));

      await tester.drag(_key('narrative-font-slider'), const Offset(120, 0));
      await settle(tester);

      final double size = container.read(readingPreferencesProvider).matnFontSize;
      expect(size, isNot(30));
      expect(fontSizeOf(tester, 'passage-c1-0'), closeTo(21 * size / 27, 0.01));
      final String saved = container.read(keyValueStoreProvider).readString(StorageKeys.readingPreferences)!;
      expect((jsonDecode(saved) as Map<String, dynamic>)['matnFontSize'], size);
    });

    testWidgets('the evidence of the three scenes folds under the chapters and opens on tap', (WidgetTester tester) async {
      await open(tester, first);
      await scrollStationTo(tester, _key('station-evidence'));
      expect(_key('evidence-scene-setting'), findsNothing);

      await tester.tap(_key('station-evidence'));
      await settle(tester);
      for (final SeerahScene scene in SeerahScene.values) {
        await scrollStationTo(tester, _key('evidence-scene-${scene.wire}'));
        expect(find.descendant(of: _key('evidence-scene-${scene.wire}'), matching: find.text(sceneTitle(scene))), findsOneWidget);
        for (final SeerahEvidence item in first.evidenceFor(scene)) {
          expect(
            find.descendant(of: _key('evidence-scene-${scene.wire}'), matching: find.textContaining(item.source.quote!)),
            findsWidgets,
          );
        }
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('without the experience layer (a station generated from the book)', () {
    final SeerahStationModel bare = withoutExperience(dataset.stationById('badr_hubab_counsel')!);
    final SeerahDataset bareDataset = replacingStation(dataset, bare);

    testWidgets('the chapters are open from the start and there is no dilemma to reveal', (WidgetTester tester) async {
      await open(tester, bare, custom: bareDataset);

      expect(_key('station-compass'), findsOneWidget);
      expect(_key('station-hook'), findsNothing);
      expect(_key('station-dilemma'), findsNothing);
      expect(_key('station-reveal'), findsNothing);
      expect(_key('station-evidence'), findsNothing);
      expect(find.text('المعايشة والموقف'), findsNothing);

      expect(_key('station-reading'), findsOneWidget);
      expect(_key('chapter-${bare.chapters.first.id}'), findsOneWidget);
      expect(_key('narrative-font-slider'), findsOneWidget);
      expect(_key('station-continue'), findsOneWidget, reason: 'nothing to reveal, so the way on is open');
      expect(tester.takeException(), isNull);
    });

    testWidgets('leaving counts the station as visited, and the way on can be taken', (WidgetTester tester) async {
      final ProviderContainer container = await open(tester, bare, custom: bareDataset);
      expect(container.read(seerahVisitedProvider), isNot(contains(bare.id)));

      final List<SeerahStationModel> ordered = bareDataset.chronological;
      final SeerahStationModel next = ordered[ordered.indexWhere((SeerahStationModel s) => s.id == bare.id) + 1];
      expect(
        find.descendant(of: _key('station-continue'), matching: find.text('المحطة التالية: ${next.title}')),
        findsOneWidget,
      );
      await tester.tap(_key('station-continue'));
      await settle(tester);
      expect(container.read(seerahVisitedProvider), contains(bare.id));
      expect(container.read(selectedSeerahStationProvider), next.id);
      expect(find.descendant(of: find.byType(AppBar), matching: find.text(next.title)), findsOneWidget);
    });

    testWidgets('the teaser for the next station closes the chapters', (WidgetTester tester) async {
      await open(tester, bare, custom: bareDataset);
      await scrollStationTo(tester, _key('station-next-hook'));
      expect(find.descendant(of: _key('station-next-hook'), matching: find.text(bare.nextHook!)), findsOneWidget);
    });

    testWidgets('the chapters can be folded away and brought back', (WidgetTester tester) async {
      await open(tester, bare, custom: bareDataset);
      await tester.tap(find.text(seerahReadingTitle));
      await settle(tester);
      expect(_key('chapter-${bare.chapters.first.id}'), findsNothing);
      await tester.tap(find.text(seerahReadingTitle));
      await settle(tester);
      expect(_key('chapter-${bare.chapters.first.id}'), findsOneWidget);
    });
  });

  testWidgets('a long run of chapters scrolls smoothly down to the last passage on a small phone', (WidgetTester tester) async {
    await open(tester, hijra, size: const Size(360, 640));
    await scrollStationTo(tester, _key('station-reading'));
    await tester.tap(find.text(seerahReadingTitle));
    await settle(tester);

    final SeerahChapter lastChapter = hijra.chapters.last;
    final int lastIndex = lastChapter.passages.length - 1;
    await scrollStationTo(tester, _key('passage-${lastChapter.id}-$lastIndex'));
    expect(_key('passage-${lastChapter.id}-$lastIndex'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
