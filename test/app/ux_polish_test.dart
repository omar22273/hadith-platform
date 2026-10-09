// اختبارات تجربة v2.1 على التطبيق كاملاً: منهاج المتون والمساقات المقفلة،
// أول ثلاث محطات بلا تمرير، البحث، ورقة تفاصيل السيرة، تتابع ترتيب المتن،
// التغذية الراجعة اللحظية، المشاركة، ثم تشغيل كل الشاشات بأكبر خط دون تجاوز.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/app/app_shell_screen.dart';
import 'package:hadith_platform/core/storage/key_value_store.dart';
import 'package:hadith_platform/features/hadith/application/hadith_providers.dart';
import 'package:hadith_platform/features/hadith/data/models/models.dart';
import 'package:hadith_platform/features/journey/domain/course_catalog.dart';
import 'package:hadith_platform/features/journey/presentation/widgets/wird_node.dart';
import 'package:hadith_platform/features/review/application/review_controllers.dart';
import 'package:hadith_platform/features/review/domain/review_deck.dart';
import 'package:hadith_platform/core/theme/app_theme.dart';
import 'package:hadith_platform/features/seerah/data/models/seerah_station.dart';
import 'package:hadith_platform/features/seerah/domain/seerah_checkpoint.dart';
import 'package:hadith_platform/features/seerah/presentation/seerah_checkpoint_screen.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';

Finder _navLabel(String label) {
  return find.descendant(of: find.byType(AppBottomBar), matching: find.text(label));
}

/// يسجل استدعاءات المنصة (اهتزاز، حافظة).
List<MethodCall> _recordPlatformCalls(WidgetTester tester) {
  final List<MethodCall> calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
    calls.add(call);
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return calls;
}

void main() {
  testWidgets('the path leads with the first three stations and lists the locked courses', (WidgetTester tester) async {
    await pumpApp(tester);

    // لا تمرير: أول ثلاث محطات داخل الشاشة فوق الشريط السفلي.
    final double visibleBottom = 915 - tester.getSize(find.byType(AppBottomBar)).height;
    for (int i = 0; i < 3; i++) {
      final Rect rect = tester.getRect(find.byType(WirdNodeView).at(i));
      expect(rect.top, greaterThanOrEqualTo(0), reason: 'station ${i + 1} top');
      expect(rect.bottom, lessThanOrEqualTo(visibleBottom), reason: 'station ${i + 1} bottom');
    }
    expect(find.textContaining('المُعدّ'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('صحيح البخاري'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('صحيح البخاري'));
    for (final CurriculumCourse course in CourseCatalog.lockedCourses) {
      expect(find.text(course.title), findsOneWidget);
    }
    expect(find.text(CourseCatalog.lockedNote), findsNWidgets(3));
  });

  testWidgets('hadith search finds a hadith by an unvocalized word', (WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('بحث في الأحاديث'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'الاعمال');
    await settle(tester);
    expect(find.text('الأعمال بالنيات'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'كلمة غير موجودة');
    await settle(tester);
    expect(find.text('الأعمال بالنيات'), findsNothing);
  });

  testWidgets('seerah: station search and the full-narrative sheet', (WidgetTester tester) async {
    // شاشة طويلة لتظهر البطاقة كلها بلا تمرير.
    await pumpApp(tester, size: const Size(412, 1800));
    await tester.tap(_navLabel('رحلة السيرة'));
    await settle(tester);

    await tester.tap(find.byTooltip('بحث في المحطات'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'المولد');
    await settle(tester);
    expect(find.text('المولد في عام الفيل'), findsOneWidget);
    await tester.tap(find.byTooltip('إغلاق البحث'));
    await settle(tester);

    await tester.tap(find.text('التفاصيل والرواية الكاملة'));
    await settle(tester);
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.text('المشهد الزماني'), findsWidgets);
    expect(find.text('المأزق والتحدي'), findsWidgets);
    expect(find.text('القرار والنتيجة النبوية'), findsWidgets);
    expect(find.text('النص المصدري'), findsWidgets);

    await tester.fling(find.byType(DraggableScrollableSheet), const Offset(0, 900), 3000);
    await settle(tester);
    expect(find.byType(DraggableScrollableSheet), findsNothing);
  });

  testWidgets('word-order challenges unlock one after another', (WidgetTester tester) async {
    final ProviderContainer container = await pumpApp(
      tester,
      stored: <String, String>{StorageKeys.journeyProgress: completedProgressJson()},
    );
    await tester.tap(_navLabel('ميدان المراجعة'));
    await settle(tester);
    await tester.tap(find.text('ترتيب المتن'));
    await settle(tester);

    final ReviewDeck deck = await container.read(reviewDeckProvider.future);
    expect(deck.orderChallenges.length, greaterThan(1));

    // المقاطع اللاحقة مقفلة ورمادية، وزر «المقطع التالي» معطّل.
    final Finder chips = find.byType(ChoiceChip);
    expect(tester.widget<ChoiceChip>(chips.at(0)).onSelected, isNotNull);
    expect(tester.widget<ChoiceChip>(chips.at(1)).onSelected, isNull);
    Finder nextButton() => find.widgetWithText(FilledButton, 'المقطع التالي');
    expect(tester.widget<FilledButton>(nextButton()).onPressed, isNull);

    // ترتيب المقطع الأول بالكامل بالكلمات المطابقة.
    final OrderChallengeController controller = container.read(orderChallengeProvider.notifier);
    final challenge = deck.orderChallenges.first;
    for (int position = 0; position < challenge.drill.tokens.length; position++) {
      final int tile = challenge.drill.tiles
          .firstWhere((t) => !container.read(orderChallengeProvider).board!.isUsed(t.id) && challenge.drill.fits(t.id, position))
          .id;
      controller.place(tile);
    }
    await settle(tester);

    expect(container.read(orderChallengeProvider).completed, contains(0));
    expect(tester.widget<ChoiceChip>(find.byType(ChoiceChip).at(1)).onSelected, isNotNull);
    expect(tester.widget<FilledButton>(nextButton()).onPressed, isNotNull);

    await tester.tap(nextButton());
    await settle(tester);
    expect(container.read(orderChallengeProvider).index, 1);
    // محاولة القفز إلى مقطع بعيد لا تفعل شيئاً.
    controller.select(deck.orderChallenges.length - 1);
    expect(container.read(orderChallengeProvider).index, 1, reason: 'later challenges stay locked');
  });

  testWidgets('scenario options give instant colored feedback with a haptic', (WidgetTester tester) async {
    final List<MethodCall> calls = _recordPlatformCalls(tester);
    final ProviderContainer container = await pumpApp(
      tester,
      size: const Size(412, 2600),
      stored: <String, String>{StorageKeys.journeyProgress: completedProgressJson()},
    );
    await tester.tap(_navLabel('ميدان المراجعة'));
    await settle(tester);
    await tester.tap(find.text('مواقف التثبيت'));
    await settle(tester);

    final ReviewDeck deck = await container.read(reviewDeckProvider.future);
    final Scenario scenario = deck.scenarios.first.scenario;
    final ScenarioOption wrong = scenario.options.firstWhere(
      (ScenarioOption o) => o.alignment == OptionAlignment.misaligned,
    );
    final ScenarioOption right = scenario.alignedOption!;

    await tester.tap(find.text(wrong.text));
    await settle(tester);
    expect(find.text('لماذا هذا هو الخيار النبوي؟'), findsOneWidget);
    expect(find.text('ليس هذا مقصد الحديث'), findsOneWidget);
    expect(calls.where((MethodCall c) => c.method == 'HapticFeedback.vibrate'), isNotEmpty);

    await tester.tap(find.text(right.text).first);
    await settle(tester);
    expect(find.text('الخيار النبوي'), findsWidgets);
    expect(find.text('لماذا هذا هو الخيار النبوي؟'), findsNothing);
  });

  testWidgets('sharing copies the vocalized matn with its takhrij, or opens the share sheet', (WidgetTester tester) async {
    final FakeShareService share = FakeShareService();
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final ProviderContainer container = await pumpApp(tester, shareService: share);
    final HadithDailyModel hadith = await container.read(hadithProvider('nawawi40_001').future);

    await tester.tap(find.descendant(of: find.byType(WirdNodeView), matching: find.text('الأعمال بالنيات')).first);
    await settle(tester);
    await tester.tap(find.text('بدء وِرد التثبيت اللمسي'));
    await settle(tester);

    await tester.tap(find.byTooltip('مشاركة الحديث'));
    await settle(tester);
    await tester.tap(find.text('نسخ'));
    await settle(tester);
    expect(clipboard, contains(hadith.matn.fullText));
    expect(clipboard, contains(hadith.matn.takhrij.displayLabel));

    await tester.tap(find.byTooltip('مشاركة الحديث'));
    await settle(tester);
    await tester.tap(find.widgetWithText(TextButton, 'مشاركة كنص'));
    await settle(tester);
    expect(share.texts, hasLength(1));
    expect(share.texts.single, contains(hadith.matn.fullText));
  });

  testWidgets('every tab survives the largest fonts on a narrow phone without overflow', (WidgetTester tester) async {
    await pumpApp(
      tester,
      size: const Size(360, 740),
      systemTextScale: 1.3,
      stored: <String, String>{
        StorageKeys.journeyProgress: completedProgressJson(),
        StorageKeys.readingPreferences: jsonEncode(<String, Object>{
          'matnFontSize': 38,
          'textScale': 1.3,
          'matnFont': 'amiri',
        }),
      },
    );
    expect(tester.takeException(), isNull);

    for (final String tab in <String>['رحلة السيرة', 'ميدان المراجعة', 'الإعدادات', 'الأربعين النووية']) {
      await tester.tap(_navLabel(tab));
      await settle(tester);
      expect(tester.takeException(), isNull, reason: tab);
    }

    await tester.tap(_navLabel('ميدان المراجعة'));
    await settle(tester);
    for (final String mode in <String>['ترتيب المتن', 'مواقف التثبيت', 'بطاقات الغريب']) {
      await tester.tap(find.text(mode));
      await settle(tester);
      expect(tester.takeException(), isNull, reason: mode);
    }

    await tester.tap(_navLabel('الأربعين النووية'));
    await settle(tester);
    await tester.tap(find.descendant(of: find.byType(WirdNodeView), matching: find.text('الأعمال بالنيات')).first);
    await settle(tester);
    expect(tester.takeException(), isNull, reason: 'wird sheet');
  });

  group('oasis screen', () {
    late List<SeerahStationModel> stations;

    setUpAll(() {
      stations = SeerahDataset.fromJson(
        asJsonMap(jsonDecode(File('assets/data/seerah_dataset.json').readAsStringSync()), 'seerah'),
      ).chronological;
    });

    Future<void> pumpOasis(WidgetTester tester, SeerahCheckpoint checkpoint, ValueChanged<bool?> onResult) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ar'),
          supportedLocales: const <Locale>[Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async => onResult(
                    await Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(builder: (_) => SeerahCheckpointScreen(checkpoint: checkpoint)),
                    ),
                  ),
                  child: const Text('افتح'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('افتح'));
      await settle(tester);
    }

    testWidgets('a wrong order is flagged, and the oasis can be skipped', (WidgetTester tester) async {
      bool? result = true;
      await pumpOasis(tester, SeerahCheckpoint.after(stations, 4)!, (bool? value) => result = value);
      await tester.tap(find.text('تحقق'));
      await settle(tester);
      expect(find.textContaining('تحتاج إلى مراجعة'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_rounded), findsWidgets);
      await tester.tap(find.text('تخطي الواحة'));
      await settle(tester);
      expect(result, isFalse);
    });

    testWidgets('dragging a handle reorders the list', (WidgetTester tester) async {
      final SeerahCheckpoint checkpoint = SeerahCheckpoint.after(stations, 4)!;
      await pumpOasis(tester, checkpoint, (bool? _) {});
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(5));
      final Finder firstTitle = find.text(checkpoint.shuffled.first.title);
      final double before = tester.getTopLeft(firstTitle).dy;
      await tester.drag(find.byIcon(Icons.drag_indicator_rounded).first, const Offset(0, 220));
      await settle(tester);
      expect(tester.getTopLeft(firstTitle).dy, greaterThan(before), reason: 'the dragged row moved down');
    });

    testWidgets('a correct order lets the user continue', (WidgetTester tester) async {
      bool? result;
      final SeerahCheckpoint solved = SeerahCheckpoint.withOrder(
        stations.take(5).toList(),
        stations.take(5).toList(),
      );
      await pumpOasis(tester, solved, (bool? value) => result = value);
      await tester.tap(find.text('تحقق'));
      await settle(tester);
      expect(find.textContaining('أحسنت'), findsOneWidget);
      await tester.tap(find.text('تابع الرحلة'));
      await settle(tester);
      expect(result, isTrue);
    });
  });
}
