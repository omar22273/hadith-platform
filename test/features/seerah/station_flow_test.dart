// اختبارات شاشة المحطة الموحدة بطبقتيها: شريط البوصلة والطور وبطاقة «ما سبق»، ثم
// طبقة المعايشة والموقف (التمهيد فالمشهد الموجز فمأزق الشورى وسؤالها وخياراته إن نصّ
// عليها الشاهد أو زر كشف فالقرار فتمهيد المحطة التالية)، ثم طبقة الرواية التاريخية
// المطولة القابلة للطي. بلا حكم على الاختيار.

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
import 'package:hadith_platform/features/seerah/presentation/widgets/seerah_labels.dart';
import 'package:hadith_platform/features/seerah/presentation/widgets/seerah_reading_section.dart';

import '../../support/app_harness.dart';

JsonMap _load(String path) => asJsonMap(jsonDecode(File(path).readAsStringSync()), path);

Finder _navLabel(String label) {
  return find.descendant(of: find.byType(AppBottomBar), matching: find.text(label));
}

void main() {
  final SeerahDataset dataset = SeerahDataset.fromJson(_load('assets/data/seerah_dataset.json'));
  final List<SeerahStationModel> ordered = dataset.chronological;
  final SeerahStationModel first = ordered.first;
  final SeerahStationModel second = ordered[1];
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

  Finder pageScrollable() {
    return find.descendant(of: key('station-scroll'), matching: find.byType(Scrollable)).first;
  }

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

      // البطاقة تذكر المحطة وطورها وعهدها، ومقدمتها التمهيد المشوق.
      final Finder card = key('selected-station-card');
      expect(find.descendant(of: card, matching: find.textContaining(epochCaption(dataset.epochOf(first)))), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text(covenantLabel(first.covenant))), findsOneWidget);
      expect(tester.widget<Text>(key('selected-station-lead')).data, first.hook);

      await tester.tap(key('station-start'));
      await settle(tester);
      expect(find.byType(SeerahStationScreen), findsOneWidget);
      expect(find.descendant(of: find.byType(AppBar), matching: find.text(first.title)), findsOneWidget);
    });
  });

  group('the station screen', () {
    testWidgets('opens with the compass bar, the epoch and the hook, and keeps the decision hidden', (WidgetTester tester) async {
      await openStation(tester, first);

      expect(key('station-compass'), findsOneWidget);
      expect(tester.widget<Text>(key('station-epoch')).data, epochCaption(dataset.epochOf(first)));
      expect(key('station-previous-link'), findsNothing, reason: 'nothing precedes the first station');

      expect(find.text('المعايشة والموقف'), findsOneWidget);
      expect(find.descendant(of: key('station-hook'), matching: find.text(first.hook!)), findsOneWidget);

      expect(find.text('المشهد الموجز'), findsOneWidget);
      final Text brief = tester.widget<Text>(key('station-brief-text'));
      expect(brief.data, first.sceneDescription);
      expect(brief.maxLines, 4, reason: 'a four-line brief');

      expect(find.text('مأزق الشورى والتحدي'), findsOneWidget);
      expect(tester.widget<Text>(key('station-challenge')).data, first.challenge);
      expect(find.text('سؤال الشورى'), findsOneWidget);
      expect(tester.widget<Text>(key('station-shura-question')).data, first.shuraQuestion);

      // لا قرار ولا تمهيد تالٍ ولا زر انتقال قبل الكشف، ولا خيارات مخترعة: زر كشف واحد.
      expect(key('station-decision'), findsNothing);
      expect(find.text(first.propheticDecision!), findsNothing);
      expect(key('station-next-hook'), findsNothing);
      expect(key('station-continue'), findsNothing);
      expect(key('station-option-0'), findsNothing);
      expect(key('station-reveal'), findsOneWidget);

      // الطبقة الثانية مطوية.
      expect(find.text(seerahReadingTitle), findsOneWidget);
      expect(key('chapter-${first.chapters.first.id}'), findsNothing);
      expect(key('narrative-font-slider'), findsNothing);
    });

    testWidgets('a later station opens with the line that links it to the one before', (WidgetTester tester) async {
      await openStation(tester, second);
      expect(
        find.descendant(of: key('station-previous-link'), matching: find.text(second.previousLink!)),
        findsOneWidget,
      );
      expect(find.descendant(of: key('station-previous-link'), matching: find.text('ما سبق')), findsOneWidget);
    });

    testWidgets('revealing shows the decision with its source, marks the station and teases the next', (WidgetTester tester) async {
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

      expect(find.descendant(of: key('station-next-hook'), matching: find.text(first.nextHook!)), findsOneWidget);
      expect(find.descendant(of: key('station-next-hook'), matching: find.text('في المحطة التالية')), findsOneWidget);

      final Finder next = key('station-continue');
      expect(next, findsOneWidget);
      expect(find.descendant(of: next, matching: find.text('المحطة التالية: ${second.title}')), findsOneWidget);

      await tester.tap(next);
      await settle(tester);
      expect(find.descendant(of: find.byType(AppBar), matching: find.text(second.title)), findsOneWidget);
      expect(container.read(selectedSeerahStationProvider), second.id);
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

    testWidgets('on a phone-sized screen, choosing scrolls the decision into view', (WidgetTester tester) async {
      await openStation(tester, badr, size: const Size(412, 915));
      await tester.scrollUntilVisible(key('station-option-0'), 300, scrollable: pageScrollable());
      await tester.tap(key('station-option-0'));
      await settle(tester);

      final Finder decision = key('station-decision');
      expect(decision, findsOneWidget);
      final Rect rect = tester.getRect(decision);
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.top, lessThan(915 * 0.5), reason: 'the decision card is brought near the top');
      expect(tester.takeException(), isNull);
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

    testWidgets('the last station ends with a return to the map and no teaser for a next one', (WidgetTester tester) async {
      await openStation(tester, last);
      await tester.tap(key('station-reveal'));
      await settle(tester);
      expect(key('station-next-hook'), findsNothing);
      expect(find.descendant(of: key('station-continue'), matching: find.text('العودة إلى الخريطة')), findsOneWidget);

      await tester.tap(key('station-continue'));
      await settle(tester);
      expect(find.byType(SeerahStationScreen), findsNothing);
    });

    testWidgets('no draft or pending-review wording appears anywhere on the screen', (WidgetTester tester) async {
      await openStation(tester, first);
      await tester.tap(key('station-reveal'));
      await settle(tester);
      await tester.tap(find.text(seerahReadingTitle));
      await settle(tester);

      expect(find.textContaining('بانتظار المراجعة'), findsNothing);
      expect(find.textContaining('تنتظر المراجعة'), findsNothing);
      expect(find.textContaining('[?]'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('survives a narrow phone with the largest fonts, revealed and unfolded', (WidgetTester tester) async {
      // العرض ضيق والخط كبير، والارتفاع طويل كي يُبنى الخيار الأول دون تمرير.
      await openStation(tester, badr, size: const Size(360, 6000), textScale: 1.3);
      expect(tester.takeException(), isNull);

      await tester.tap(key('station-option-0'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(key('station-continue'), findsOneWidget, reason: 'choosing an option reveals the decision');

      await tester.tap(find.text(seerahReadingTitle));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(key('station-continue'), findsOneWidget);

      // ثم تقصر الشاشة إلى هاتف صغير والحال كما هي (مكشوف ومفتوح الرواية).
      tester.view.physicalSize = const Size(360, 740) * 3;
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(key('station-continue'), findsOneWidget);
      expect(tester.getRect(key('station-continue')).bottom, lessThanOrEqualTo(740));
    });

    testWidgets('even the narrowest phone shows the compass bar and the first layer without overflow', (WidgetTester tester) async {
      await openStation(tester, dataset.stationById('hira_first_revelation')!, size: const Size(320, 4000), textScale: 1.3);
      expect(tester.takeException(), isNull);
      expect(key('compass-covenant'), findsOneWidget);
      expect(key('compass-year'), findsOneWidget);
      expect(key('compass-age'), findsOneWidget);
      expect(key('compass-place'), findsOneWidget);
    });
  });
}
