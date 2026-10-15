// اختبارات لوحة الأطوار في شاشة رحلة السيرة: عشرة أطوار متسلسلة بعناوينها وعدد
// محطات كل منها، يُفتح فيها طور المحطة المختارة، وتُختار منها المحطات، ويُعلَن فيها أن
// الطور الذي لم تُضَف محطاته بعد خالٍ لا مخترَع، والبحث الشامل في أسماء المحطات
// وأطوارها ونصوص رواياتها.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/app/app_shell_screen.dart';
import 'package:hadith_platform/features/seerah/application/seerah_providers.dart';
import 'package:hadith_platform/features/seerah/data/models/seerah_station.dart';
import 'package:hadith_platform/features/seerah/presentation/widgets/seerah_labels.dart';

import '../../support/app_harness.dart';
import '../../support/seerah_support.dart';

Finder _key(String name) => find.byKey(ValueKey<String>(name));

Finder _navLabel(String label) {
  return find.descendant(of: find.byType(AppBottomBar), matching: find.text(label));
}

void main() {
  final SeerahDataset dataset = loadSeerahDataset();

  Future<ProviderContainer> openJourney(
    WidgetTester tester, {
    Size size = const Size(412, 3600),
    double textScale = 1,
  }) async {
    final ProviderContainer container = await pumpApp(tester, size: size, systemTextScale: textScale);
    await tester.tap(_navLabel('رحلة السيرة'));
    await settle(tester);
    return container;
  }

  test('the Arabic count labels agree in number and gender', () {
    expect(stationCountLabel(0), 'بلا محطات بعد');
    expect(stationCountLabel(1), 'محطة واحدة');
    expect(stationCountLabel(2), 'محطتان');
    expect(stationCountLabel(5), '٥ محطات');
    expect(stationCountLabel(12), '١٢ محطة');
    expect(chaptersLabel(1), 'فصل واحد');
    expect(chaptersLabel(2), 'فصلان');
    expect(chaptersLabel(6), '٦ فصول');
    expect(chaptersLabel(11), '١١ فصلاً');
    expect(passagesLabel(1), 'مقطع واحد');
    expect(passagesLabel(2), 'مقطعان');
    expect(passagesLabel(14), '١٤ مقطعاً');
    expect(passagesLabel(7), '٧ مقاطع');
  });

  testWidgets('lists the ten epochs in order, each with its station count', (WidgetTester tester) async {
    await openJourney(tester);

    expect(tester.widget<Text>(_key('epochs-panel-title')).data, 'منهج السيرة في ١٠ أطوار');
    double previousTop = -1;
    for (final SeerahEpochInfo epoch in dataset.epochsInOrder) {
      final Finder tile = _key('epoch-tile-${epoch.id}');
      expect(tile, findsOneWidget, reason: epoch.id);
      expect(find.descendant(of: tile, matching: find.text(epoch.title)), findsOneWidget);
      expect(
        find.descendant(of: tile, matching: find.textContaining(stationCountLabel(dataset.stationsOfEpoch(epoch.id).length))),
        findsOneWidget,
        reason: epoch.id,
      );
      final double top = tester.getTopLeft(tile).dy;
      expect(top, greaterThan(previousTop), reason: 'the epochs run in order down the page');
      previousTop = top;
    }
    expect(find.descendant(of: _key('epoch-tile-epoch_04_public_call'), matching: find.text('بلا محطات بعد')), findsOneWidget);
  });

  testWidgets('opens the epoch of the selected station, and one epoch at a time', (WidgetTester tester) async {
    await openJourney(tester);
    final SeerahStationModel first = dataset.chronological.first;

    expect(_key('epoch-station-${first.id}'), findsOneWidget);
    expect(_key('epoch-station-hilf_al_fudul'), findsNothing);

    await tester.tap(_key('epoch-tile-epoch_02_youth'));
    await settle(tester);
    expect(_key('epoch-station-hilf_al_fudul'), findsOneWidget);
    expect(_key('epoch-station-kaaba_black_stone'), findsOneWidget);
    expect(_key('epoch-station-${first.id}'), findsNothing, reason: 'opening one closes the other');

    await tester.tap(_key('epoch-tile-epoch_02_youth'));
    await settle(tester);
    expect(_key('epoch-station-hilf_al_fudul'), findsNothing, reason: 'tapping again folds it');
  });

  testWidgets('choosing a station in the panel selects it and fills the card above', (WidgetTester tester) async {
    final ProviderContainer container = await openJourney(tester);
    await tester.tap(_key('epoch-tile-epoch_02_youth'));
    await settle(tester);
    await tester.tap(_key('epoch-station-hilf_al_fudul'));
    await settle(tester);

    expect(container.read(selectedSeerahStationProvider), 'hilf_al_fudul');
    expect(
      find.descendant(of: _key('selected-station-card'), matching: find.text('حلف الفضول')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _key('selected-station-card'),
        matching: find.textContaining(epochCaption(dataset.epochById('epoch_02_youth'))),
      ),
      findsOneWidget,
    );
    expect(find.text('ابدأ المحطة'), findsOneWidget);
  });

  testWidgets('a station selected elsewhere, such as on the map, opens its epoch in the panel', (WidgetTester tester) async {
    final ProviderContainer container = await openJourney(tester);
    container.read(selectedSeerahStationProvider.notifier).select('badr_hubab_counsel');
    await settle(tester);

    expect(_key('epoch-station-badr_hubab_counsel'), findsOneWidget);
    expect(_key('epoch-station-uhud_archers'), findsOneWidget);
    expect(_key('epoch-station-birth_year_of_elephant'), findsNothing);
  });

  testWidgets('an epoch with no stations yet says so and invents nothing', (WidgetTester tester) async {
    await openJourney(tester);
    await tester.tap(_key('epoch-tile-epoch_04_public_call'));
    await settle(tester);

    expect(_key('epoch-empty-epoch_04_public_call'), findsOneWidget);
    expect(find.textContaining('تصل مع حزمة المحتوى القادمة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the visited stations are counted on their epoch', (WidgetTester tester) async {
    final ProviderContainer container = await openJourney(tester);
    container.read(seerahVisitedProvider.notifier).markVisited('hira_first_revelation');
    await settle(tester);

    expect(
      find.descendant(of: _key('epoch-tile-epoch_03_secret_call'), matching: find.textContaining('أتممتَ ١')),
      findsOneWidget,
    );
  });

  group('search', () {
    testWidgets('finds stations by their epoch title and shows the epoch on each result', (WidgetTester tester) async {
      await openJourney(tester);
      await tester.tap(find.byTooltip('بحث في المحطات'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'الدعوة السرية');
      await settle(tester);

      expect(find.text('خلوة غار حراء وبدء الوحي'), findsOneWidget);
      expect(find.text('دار الأرقم: دار الدعوة الأولى'), findsOneWidget);
      expect(find.textContaining('الطور ٣ · البعثة والدعوة السرية'), findsWidgets);
    });

    testWidgets('finds a station by a word that only its verbatim chapters contain', (WidgetTester tester) async {
      final SeerahStationModel hijra = dataset.stationById('hijra_masjid_nabawi')!;
      final String word = hijra.chapters
          .expand((SeerahChapter c) => c.passages)
          .map((passage) => passage.quote!)
          .join(' ')
          .split(RegExp(r'\s+'))
          .firstWhere((String w) => w.length >= 7);
      await openJourney(tester);
      await tester.tap(find.byTooltip('بحث في المحطات'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), word);
      await settle(tester);

      expect(find.text(hijra.title), findsOneWidget);
    });

    testWidgets('says plainly when nothing matches', (WidgetTester tester) async {
      await openJourney(tester);
      await tester.tap(find.byTooltip('بحث في المحطات'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'كلمةلاوجودلهافيالسيرة');
      await settle(tester);
      expect(find.textContaining('لا محطة تطابق'), findsOneWidget);
    });
  });

  testWidgets('survives the narrowest phone with the largest fonts, with an epoch open', (WidgetTester tester) async {
    await openJourney(tester, size: const Size(320, 4200), textScale: 1.3);
    await tester.tap(_key('epoch-tile-epoch_07_state_badr_uhud'));
    await settle(tester);
    expect(_key('epoch-station-badr_hubab_counsel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
