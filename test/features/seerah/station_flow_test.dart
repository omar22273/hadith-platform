// اختبارات شاشة المحطة الموحدة: مشهد موجز في أربعة أسطر، فمأزق الشورى والتحدي
// بخياراته إن نصّ عليها الشاهد (أو زر كشف)، فالقرار النبوي بعد الاختيار، فقسم
// «الرواية التاريخية وتفاصيل الأحداث» القابل للطي. بلا حكم على الاختيار.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/app/app_shell_screen.dart';
import 'package:hadith_platform/core/json/json_reader.dart';
import 'package:hadith_platform/features/seerah/application/seerah_providers.dart';
import 'package:hadith_platform/features/seerah/data/models/seerah_station.dart';
import 'package:hadith_platform/features/seerah/presentation/seerah_station_screen.dart';

import '../../support/app_harness.dart';

JsonMap _load(String path) => asJsonMap(jsonDecode(File(path).readAsStringSync()), path);

Finder _navLabel(String label) {
  return find.descendant(of: find.byType(AppBottomBar), matching: find.text(label));
}

void main() {
  final SeerahDataset dataset = SeerahDataset.fromJson(_load('assets/data/seerah_dataset.json'));
  final List<SeerahStationModel> ordered = dataset.chronological;
  final SeerahStationModel first = ordered.first;
  final SeerahStationModel badr = dataset.stationById('badr_hubab_counsel')!;
  final SeerahStationModel last = ordered.last;

  /// يشغّل التطبيق ويدفع شاشة المحطة فوقه.
  Future<ProviderContainer> openStation(
    WidgetTester tester,
    SeerahStationModel station, {
    Size size = const Size(412, 2400),
    double textScale = 1,
  }) async {
    final ProviderContainer container = await pumpApp(tester, size: size, systemTextScale: textScale);
    final NavigatorState navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(
      navigator.push<void>(
        MaterialPageRoute<void>(builder: (BuildContext _) => SeerahStationScreen(stationId: station.id)),
      ),
    );
    await settle(tester);
    return container;
  }

  Finder key(String name) => find.byKey(ValueKey<String>(name));

  group('the journey card', () {
    testWidgets('has one wide start button and neither of the old two', (WidgetTester tester) async {
      await pumpApp(tester, size: const Size(412, 1800));
      await tester.tap(_navLabel('رحلة السيرة'));
      await settle(tester);

      expect(find.text('ابدأ المحطة'), findsOneWidget);
      expect(find.text('ادخل المشاهد الثلاثة'), findsNothing);
      expect(find.text('أعد مشاهدة المشاهد الثلاثة'), findsNothing);
      expect(find.text('الرواية الكاملة وتفاصيل الحدث'), findsNothing);
      expect(tester.getSize(key('station-start')).width, greaterThan(412 * 0.8), reason: 'a wide button');

      await tester.tap(key('station-start'));
      await settle(tester);
      expect(find.byType(SeerahStationScreen), findsOneWidget);
      expect(find.descendant(of: find.byType(AppBar), matching: find.text(first.title)), findsOneWidget);
    });
  });

  group('the station screen', () {
    testWidgets('shows the brief scene and the dilemma, and keeps the decision hidden', (WidgetTester tester) async {
      await openStation(tester, first);

      expect(find.text('المشهد الموجز'), findsOneWidget);
      final Text brief = tester.widget<Text>(key('station-brief-text'));
      expect(brief.data, first.sceneDescription);
      expect(brief.maxLines, 4, reason: 'a four-line brief');

      expect(find.text('مأزق الشورى والتحدي'), findsOneWidget);
      expect(tester.widget<Text>(key('station-challenge')).data, first.challenge);

      // لا قرار ولا زر انتقال قبل الكشف، ولا خيارات مخترعة: زر كشف واحد.
      expect(key('station-decision'), findsNothing);
      expect(find.text(first.propheticDecision), findsNothing);
      expect(key('station-continue'), findsNothing);
      expect(key('station-option-0'), findsNothing);
      expect(key('station-reveal'), findsOneWidget);
      expect(find.text('الرواية التاريخية وتفاصيل الأحداث'), findsOneWidget);
      expect(key('narrative-scene-setting'), findsNothing, reason: 'the long reading is folded');
    });

    testWidgets('revealing shows the decision with its source, marks the station and offers the next', (WidgetTester tester) async {
      final ProviderContainer container = await openStation(tester, first);
      expect(container.read(seerahVisitedProvider), isNot(contains(first.id)));

      await tester.tap(key('station-reveal'));
      await settle(tester);

      expect(find.text('القرار النبوي ونتيجته'), findsOneWidget);
      expect(tester.widget<Text>(key('station-decision-text')).data, first.propheticDecision);
      for (final SeerahEvidence item in first.evidenceFor(SeerahScene.decision)) {
        expect(find.textContaining(item.source.quote!), findsWidgets);
      }
      expect(key('station-reveal'), findsNothing);
      expect(container.read(seerahVisitedProvider), contains(first.id));

      final Finder next = key('station-continue');
      expect(next, findsOneWidget);
      expect(find.descendant(of: next, matching: find.text('المحطة التالية: ${ordered[1].title}')), findsOneWidget);

      await tester.tap(next);
      await settle(tester);
      expect(find.descendant(of: find.byType(AppBar), matching: find.text(ordered[1].title)), findsOneWidget);
      expect(container.read(selectedSeerahStationProvider), ordered[1].id);
    });

    testWidgets('a station whose source states the options shows them, and a choice reveals the decision', (WidgetTester tester) async {
      final ProviderContainer container = await openStation(tester, badr);
      final List<String> options = badr.dilemmaOptions!;
      expect(options, hasLength(2));

      expect(key('station-reveal'), findsNothing, reason: 'choosing is what reveals');
      expect(key('station-decision'), findsNothing);
      for (int i = 0; i < options.length; i++) {
        expect(find.descendant(of: key('station-option-$i'), matching: find.text(options[i])), findsOneWidget);
      }

      await tester.tap(key('station-option-1'));
      await settle(tester);
      expect(tester.widget<Text>(key('station-decision-text')).data, badr.propheticDecision);
      expect(find.text('اخترتَ:'), findsOneWidget);
      expect(find.descendant(of: key('station-option-1'), matching: find.byIcon(Icons.radio_button_checked_rounded)), findsOneWidget);
      expect(find.descendant(of: key('station-option-0'), matching: find.byIcon(Icons.radio_button_unchecked_rounded)), findsOneWidget);
      expect(container.read(seerahVisitedProvider), contains(badr.id));

      // الاختيار بعد الكشف لا يتبدل ولا يظهر عليه حكم.
      await tester.tap(key('station-option-0'), warnIfMissed: false);
      await settle(tester);
      expect(find.descendant(of: key('station-option-1'), matching: find.byIcon(Icons.radio_button_checked_rounded)), findsOneWidget);
      expect(key('station-decision'), findsOneWidget);
    });

    testWidgets('a brief scene longer than four lines opens fully on request and folds again', (WidgetTester tester) async {
      await openStation(tester, first);
      final Finder toggle = key('station-brief-toggle');
      expect(toggle, findsOneWidget, reason: 'the wide test font makes this scene run past four lines');
      expect(find.text('قراءة المشهد كاملاً'), findsOneWidget);

      await tester.tap(toggle);
      await settle(tester);
      expect(tester.widget<Text>(key('station-brief-text')).maxLines, isNull);
      expect(find.text('طيّ المشهد'), findsOneWidget);

      await tester.tap(toggle);
      await settle(tester);
      expect(tester.widget<Text>(key('station-brief-text')).maxLines, 4);
    });

    testWidgets('the last station ends with a return to the map', (WidgetTester tester) async {
      await openStation(tester, last);
      await tester.tap(key('station-reveal'));
      await settle(tester);
      expect(find.descendant(of: key('station-continue'), matching: find.text('العودة إلى الخريطة')), findsOneWidget);

      await tester.tap(key('station-continue'));
      await settle(tester);
      expect(find.byType(SeerahStationScreen), findsNothing);
    });

    testWidgets('no draft or pending-review wording appears anywhere on the screen', (WidgetTester tester) async {
      await openStation(tester, first);
      await tester.tap(key('station-reveal'));
      await settle(tester);
      await tester.tap(find.text('الرواية التاريخية وتفاصيل الأحداث'));
      await settle(tester);

      expect(find.textContaining('بانتظار المراجعة'), findsNothing);
      expect(find.textContaining('تنتظر المراجعة'), findsNothing);
      expect(find.textContaining('[?]'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('survives a narrow phone with the largest fonts, revealed and unfolded', (WidgetTester tester) async {
      await openStation(tester, badr, size: const Size(360, 740), textScale: 1.3);
      expect(tester.takeException(), isNull);

      // الشاشة ضيقة والخط كبير: الخيار الأول قد يقع تحت حافة الشاشة، فيُمرَّر إليه.
      final Finder scroll = find.descendant(of: key('station-scroll'), matching: find.byType(Scrollable)).first;
      await tester.scrollUntilVisible(key('station-option-0'), 200, scrollable: scroll);
      await tester.tap(key('station-option-0'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(key('station-continue'), findsOneWidget, reason: 'choosing an option reveals the decision');

      await tester.scrollUntilVisible(key('station-narrative'), 300, scrollable: scroll);
      await tester.tap(find.text('الرواية التاريخية وتفاصيل الأحداث'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(key('station-continue'), findsOneWidget);
    });
  });
}
