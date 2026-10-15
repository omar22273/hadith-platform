// اختبارات شريط البوصلة في أعلى المحطة: العهد والموقع من بيانات المحطة، والسنة وعمر
// النبي ﷺ لا يظهران إلا إن نصّ عليهما شاهد، وزر ⓘ يفتح ورقة بذلك الشاهد حرفياً أو
// يبيّن أن الشواهد لم تنص.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/core/content/models/content_models.dart';
import 'package:hadith_platform/features/seerah/data/models/seerah_station.dart';
import 'package:hadith_platform/features/seerah/presentation/widgets/seerah_labels.dart';

import '../../support/app_harness.dart';
import '../../support/seerah_support.dart';

Finder _key(String name) => find.byKey(ValueKey<String>(name));

void main() {
  final SeerahDataset dataset = loadSeerahDataset();
  final SeerahStationModel birth = dataset.chronological.first;
  final SeerahStationModel hira = dataset.stationById('hira_first_revelation')!;
  final SeerahStationModel death = dataset.stationById('prophet_death')!;

  Finder cellText(String cell, String text) {
    return find.descendant(of: _key(cell), matching: find.text(text));
  }

  testWidgets('shows the covenant, the stated year, and the place, and leaves out an age no source states', (WidgetTester tester) async {
    await openStationScreen(tester, dataset: dataset, stationId: birth.id);

    expect(cellText('compass-covenant', covenantLabel(SeerahCovenant.preMission)), findsOneWidget);
    expect(cellText('compass-year', birth.yearLabel!), findsOneWidget);
    expect(cellText('compass-place', birth.place.name), findsOneWidget);
    expect(_key('compass-age'), findsNothing, reason: 'the sources state no age for the birth');
    expect(find.text('العهد'), findsOneWidget);
    expect(find.text('السنة'), findsOneWidget);
    expect(find.text('الموقع'), findsOneWidget);
  });

  testWidgets('shows the age the sources state beside the year', (WidgetTester tester) async {
    await openStationScreen(tester, dataset: dataset, stationId: hira.id);
    expect(cellText('compass-covenant', 'العهد المكي'), findsOneWidget);
    expect(cellText('compass-year', hira.yearLabel!), findsOneWidget);
    expect(cellText('compass-age', hira.ageLabel!), findsOneWidget);
    expect(find.text('عمر النبي ﷺ'), findsOneWidget);
  });

  testWidgets('shows the age alone where no year is stated, in the Medinan covenant', (WidgetTester tester) async {
    await openStationScreen(tester, dataset: dataset, stationId: death.id);
    expect(cellText('compass-covenant', 'العهد المدني'), findsOneWidget);
    expect(_key('compass-year'), findsNothing);
    expect(cellText('compass-age', death.ageLabel!), findsOneWidget);
  });

  testWidgets('the info button opens the sheet with the verbatim quotes the year and age rest on', (WidgetTester tester) async {
    await openStationScreen(tester, dataset: dataset, stationId: hira.id);
    await tester.tap(_key('station-compass-info'));
    await settle(tester);

    final Finder sheet = _key('compass-basis-sheet');
    expect(sheet, findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('مستند شريط البوصلة')), findsOneWidget);
    for (final SourceRef basis in hira.compassBasis!) {
      expect(find.descendant(of: sheet, matching: find.textContaining(basis.quote!)), findsWidgets);
    }
    expect(_key('compass-basis-empty'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a station whose sources state no year or age shows only covenant and place, and says so', (WidgetTester tester) async {
    final SeerahStationModel bare = editedStation(hira, (Map<String, dynamic> json) {
      json
        ..remove('year_label')
        ..remove('age_label')
        ..remove('compass_basis');
    });
    await openStationScreen(tester, dataset: replacingStation(dataset, bare), stationId: bare.id);

    expect(_key('compass-covenant'), findsOneWidget);
    expect(_key('compass-place'), findsOneWidget);
    expect(_key('compass-year'), findsNothing);
    expect(_key('compass-age'), findsNothing);

    await tester.tap(_key('station-compass-info'));
    await settle(tester);
    expect(_key('compass-basis-empty'), findsOneWidget);
    expect(find.textContaining('لم تنصّ الشواهد'), findsOneWidget);
  });
}
