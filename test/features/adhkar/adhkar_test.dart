// اختبارات وِرد الأذكار: سلامة بيانات البذرة وأن نصها جزء حرفي من شواهدها،
// ومتحكم العدّ والقفل النهائي والانتقال التلقائي، وبطاقة السبحة: ضغطة بأي
// موضع باهتزاز خفيف، واهتزاز مزدوج وهالة خضراء وقفل عند بلوغ العدد المسنون،
// ثم شارة إتمام الوِرد.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/app/app_shell_screen.dart';
import 'package:hadith_platform/core/content/models/content_models.dart';
import 'package:hadith_platform/core/json/json_reader.dart';
import 'package:hadith_platform/core/theme/feedback_colors.dart';
import 'package:hadith_platform/features/adhkar/application/adhkar_providers.dart';
import 'package:hadith_platform/features/adhkar/application/adhkar_wird_controller.dart';
import 'package:hadith_platform/features/adhkar/data/models/adhkar.dart';
import 'package:hadith_platform/features/adhkar/domain/adhkar_integrity.dart';
import 'package:hadith_platform/features/adhkar/presentation/adhkar_screen.dart';
import 'package:smooth_corner/smooth_corner.dart';

import '../../support/app_harness.dart';

JsonMap _load(String path) => asJsonMap(jsonDecode(File(path).readAsStringSync()), path);

/// يسجل كل اهتزاز بنوعه.
List<String> _recordHaptics(WidgetTester tester) {
  final List<String> haptics = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
    if (call.method == 'HapticFeedback.vibrate') {
      haptics.add(call.arguments as String);
    }
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return haptics;
}

Finder _navLabel(String label) {
  return find.descendant(of: find.byType(AppBottomBar), matching: find.text(label));
}

/// سطر التقدم تحت العنوان.
String _progress(WidgetTester tester) {
  return tester.widget<Text>(find.byKey(const ValueKey<String>('adhkar-progress'))).data!;
}

/// يفتح تبويب الأذكار ويعيد الحاوية.
Future<ProviderContainer> _openAdhkar(WidgetTester tester, {Size size = const Size(412, 2200)}) async {
  final ProviderContainer container = await pumpApp(tester, size: size);
  await tester.tap(_navLabel('وِرد الأذكار'));
  await settle(tester);
  await container.read(adhkarCatalogProvider.future);
  await settle(tester);
  return container;
}

void main() {
  final JsonMap raw = _load('assets/data/adhkar/adhkar_catalog.json');
  final AdhkarCatalog catalog = AdhkarCatalog.fromJson(raw);
  final SourceCatalog sources = SourceCatalog.fromJson(_load('assets/data/catalogs/sources.json'));

  group('the seed data', () {
    test('holds exactly the two requested adhkar with their prophetic counts', () {
      final List<DhikrItem> items = catalog.itemsInOrder;
      expect(items.map((DhikrItem i) => i.id).toList(), <String>['sayyid_al_istighfar', 'tasbih_dubur_al_salah']);
      expect(items.map((DhikrItem i) => i.count).toList(), <int>[1, 33]);
      expect(items.map((DhikrItem i) => i.order).toList(), <int>[1, 2]);
    });

    test('round-trips and passes the integrity checks against the source catalog', () {
      expect(catalog.toJson(), equals(raw));
      expect(checkAdhkarCatalog(catalog, sources: sources), isEmpty);
    });

    test('every dhikr text is a verbatim part of one of its evidence quotes, each with a locator', () {
      for (final DhikrItem item in catalog.items) {
        expect(item.evidence.any((SourceRef r) => (r.quote ?? '').contains(item.text)), isTrue, reason: item.id);
        for (final SourceRef reference in item.evidence) {
          expect(reference.quote?.trim(), isNotEmpty);
          expect(reference.locator?.trim(), isNotEmpty);
          expect(sources.byId(reference.sourceId), isNotNull, reason: reference.sourceId);
        }
        expect(item.review.status, ReviewStatus.pendingScholarlyReview);
        // نص كامل التشكيل: لا كلمة عربية بلا حركة سوى الحروف المفردة.
        expect(RegExp('[ً-ْ]').hasMatch(item.text), isTrue, reason: item.id);
      }
    });

    test('a dhikr whose text is not in its quotes, or a duplicate id, or a bad count, is rejected', () {
      final DhikrItem first = catalog.items.first;
      DhikrItem edited({String? text, int? count, String? id}) {
        return DhikrItem.fromJson(<String, dynamic>{
          ...first.toJson(),
          if (text != null) 'text': text,
          if (count != null) 'count': count,
          if (id != null) 'id': id,
        });
      }

      AdhkarCatalog withItems(List<DhikrItem> items) => AdhkarCatalog(
            schemaVersion: catalog.schemaVersion,
            id: catalog.id,
            title: catalog.title,
            items: items,
          );

      expect(checkAdhkarCatalog(withItems(<DhikrItem>[edited(text: 'نص لا أصل له في الشاهد')]), sources: sources),
          contains(contains('verbatim part')));
      expect(checkAdhkarCatalog(withItems(<DhikrItem>[first, first]), sources: sources), contains(contains('Duplicate')));
      expect(checkAdhkarCatalog(withItems(<DhikrItem>[edited(count: 0)]), sources: sources), contains(contains('count')));
    });

    test('the JSON schema covers the adhkar catalog', () {
      final JsonMap schema = _load('assets/data/schema/hadith_platform.schema.json');
      final JsonMap defs = asJsonMap(schema['\$defs'], 'defs');
      expect(defs.containsKey('AdhkarCatalog'), isTrue);
      expect(defs.containsKey('DhikrItem'), isTrue);
    });
  });

  group('the wird controller', () {
    testWidgets('counts to the prophetic number, then locks permanently and advances on its own', (WidgetTester tester) async {
      final ProviderContainer container = await _openAdhkar(tester);
      final AdhkarWirdController wird = container.read(adhkarWirdProvider.notifier);
      expect(container.read(adhkarWirdProvider).index, 0);

      // الذكر الأول عدده واحد: أول لمسة تكمله وتقفله.
      expect(wird.tap(), DhikrTapResult.completed);
      expect(container.read(adhkarWirdProvider).countOf(0), 1);
      for (int i = 0; i < 5; i++) {
        expect(wird.tap(), DhikrTapResult.locked);
      }
      expect(container.read(adhkarWirdProvider).countOf(0), 1, reason: 'never exceeds the prophetic count');

      // قبل انقضاء المهلة يبقى على الذكر المكتمل، ثم ينتقل إلى الثاني وحده.
      await tester.pump(const Duration(milliseconds: 500));
      expect(container.read(adhkarWirdProvider).index, 0);
      await tester.pump(const Duration(milliseconds: 1200));
      expect(container.read(adhkarWirdProvider).index, 1);

      // الذكر الثاني ثلاث وثلاثون: 32 احتساب ثم إكمال في الثالثة والثلاثين.
      for (int i = 0; i < 32; i++) {
        expect(wird.tap(), DhikrTapResult.counted, reason: 'tap ${i + 1}');
      }
      expect(container.read(adhkarWirdProvider).isComplete(container.read(adhkarItemsProvider)), isFalse);
      expect(wird.tap(), DhikrTapResult.completed);
      expect(wird.tap(), DhikrTapResult.locked);
      expect(container.read(adhkarWirdProvider).countOf(1), 33);
      expect(container.read(adhkarWirdProvider).isComplete(container.read(adhkarItemsProvider)), isTrue);

      // الوِرد كله مكتمل فلا انتقال بعده، ويبقى على الذكر الأخير.
      await tester.pump(const Duration(seconds: 2));
      expect(container.read(adhkarWirdProvider).index, 1);

      // وِرد جديد يعيد كل شيء إلى الصفر ويفك القفل.
      wird.restart();
      expect(container.read(adhkarWirdProvider).index, 0);
      expect(container.read(adhkarWirdProvider).counts, <int>[0, 0]);
      expect(wird.tap(), DhikrTapResult.completed);
    });

    testWidgets('choosing another dhikr cancels the pending automatic advance', (WidgetTester tester) async {
      final ProviderContainer container = await _openAdhkar(tester);
      final AdhkarWirdController wird = container.read(adhkarWirdProvider.notifier);
      expect(wird.tap(), DhikrTapResult.completed);
      wird.select(1);
      wird.select(0);
      await tester.pump(const Duration(seconds: 3));
      expect(container.read(adhkarWirdProvider).index, 0, reason: 'the user chose; nothing moves them');
      wird.select(99);
      wird.select(-1);
      expect(container.read(adhkarWirdProvider).index, 0);
    });
  });

  group('the dhikr card', () {
    testWidgets('a tap anywhere counts one with a light haptic, and the counter rises', (WidgetTester tester) async {
      final List<String> haptics = _recordHaptics(tester);
      final ProviderContainer container = await _openAdhkar(tester);
      // انتقل إلى الذكر ذي الثلاث والثلاثين.
      await tester.tap(find.byKey(const ValueKey<String>('adhkar-pill-1')));
      await settle(tester);
      expect(container.read(adhkarWirdProvider).index, 1);

      final Finder card = find.byKey(const ValueKey<String>('dhikr-card-tap'));
      expect(find.byKey(const ValueKey<String>('dhikr-counter')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('dhikr-counter'))).data, '٠');

      // لمس في الزاوية العلوية ثم في الوسط ثم في الأسفل: كلها داخل البطاقة وكلها تُحتسب.
      final Rect rect = tester.getRect(card);
      for (final Offset point in <Offset>[
        rect.topLeft + const Offset(24, 24),
        rect.center,
        rect.bottomRight - const Offset(24, 24),
      ]) {
        await tester.tapAt(point);
        await tester.pump(const Duration(milliseconds: 60));
      }
      await settle(tester);

      expect(container.read(adhkarWirdProvider).countOf(1), 3);
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('dhikr-counter'))).data, '٣');
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('dhikr-remaining'))).data, endsWith('٣٠'));
      expect(haptics.where((String h) => h == 'HapticFeedbackType.selectionClick'), hasLength(3));
      expect(haptics.where((String h) => h == 'HapticFeedbackType.mediumImpact'), isEmpty);
    });

    testWidgets('reaching the number gives a double medium haptic, a green halo and a permanent lock', (WidgetTester tester) async {
      final List<String> haptics = _recordHaptics(tester);
      final ProviderContainer container = await _openAdhkar(tester);
      await tester.tap(find.byKey(const ValueKey<String>('adhkar-pill-1')));
      await settle(tester);

      final Finder card = find.byKey(const ValueKey<String>('dhikr-card-tap'));
      AnimatedContainer surface() =>
          tester.widget<AnimatedContainer>(find.byKey(const ValueKey<String>('dhikr-card-surface')));
      List<BoxShadow> shadows() => (surface().decoration! as ShapeDecoration).shadows!.cast<BoxShadow>();
      final FeedbackColors feedback = FeedbackColors.of(tester.element(find.byKey(const ValueKey<String>('dhikr-card-surface'))));

      // قبل الإتمام: ظل هادئ لا هالة خضراء.
      expect(shadows().any((BoxShadow s) => s.color == feedback.rightBorder.withValues(alpha: 0.5)), isFalse);

      for (int i = 0; i < 32; i++) {
        await tester.tap(card);
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(haptics.where((String h) => h == 'HapticFeedbackType.mediumImpact'), isEmpty, reason: 'not yet');
      expect(container.read(adhkarWirdProvider).countOf(1), 32);

      haptics.clear();
      await tester.tap(card);
      await tester.pump();
      // الاهتزاز الأول فوراً والثاني بعد فاصل قصير: مزدوج، ولا نقرة خفيفة معه.
      expect(haptics, <String>['HapticFeedbackType.mediumImpact']);
      await tester.pump(const Duration(milliseconds: 200));
      expect(haptics, <String>['HapticFeedbackType.mediumImpact', 'HapticFeedbackType.mediumImpact']);
      await tester.pump(const Duration(milliseconds: 600));

      // الهالة الخضراء والحد الأخضر وعبارة الإتمام.
      expect(container.read(adhkarWirdProvider).countOf(1), 33);
      expect(shadows().any((BoxShadow s) => s.color == feedback.rightBorder.withValues(alpha: 0.5)), isTrue);
      final SmoothRectangleBorder border = (surface().decoration! as ShapeDecoration).shape as SmoothRectangleBorder;
      expect(border.side.color, feedback.rightBorder);
      expect(find.text('اكتمل العدد المسنون'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('dhikr-counter'))).data, '٣٣');

      // القفل نهائي: لا عدّ ولا اهتزاز ولو كثرت اللمسات، والبطاقة نفسها بلا تفاعل.
      haptics.clear();
      expect(tester.widget<InkWell>(card).onTap, isNull);
      for (int i = 0; i < 5; i++) {
        await tester.tap(card, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 30));
      }
      expect(container.read(adhkarWirdProvider).countOf(1), 33);
      expect(haptics, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('finishing both adhkar shows the wird-complete badge, and a new wird clears it', (WidgetTester tester) async {
      _recordHaptics(tester);
      final ProviderContainer container = await _openAdhkar(tester);
      expect(find.byKey(const ValueKey<String>('adhkar-wird-complete')), findsNothing);
      expect(_progress(tester), endsWith('٠ من ٢'));

      // الذكر الأول: لمسة واحدة، ثم انتقال تلقائي إلى الثاني.
      await tester.tap(find.byKey(const ValueKey<String>('dhikr-card-tap')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_progress(tester), endsWith('١ من ٢'));
      await tester.pump(const Duration(milliseconds: 1500));
      await settle(tester);
      expect(container.read(adhkarWirdProvider).index, 1);
      expect(find.byKey(const ValueKey<String>('dhikr-tasbih_dubur_al_salah')), findsOneWidget);

      for (int i = 0; i < 33; i++) {
        await tester.tap(find.byKey(const ValueKey<String>('dhikr-card-tap')), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 20));
      }
      await settle(tester);

      expect(container.read(adhkarWirdProvider).isComplete(container.read(adhkarItemsProvider)), isTrue);
      expect(find.byKey(const ValueKey<String>('adhkar-wird-complete')), findsOneWidget);
      expect(_progress(tester), endsWith('٢ من ٢'));

      await tester.tap(find.byKey(const ValueKey<String>('adhkar-restart')));
      await settle(tester);
      expect(find.byKey(const ValueKey<String>('adhkar-wird-complete')), findsNothing);
      expect(container.read(adhkarWirdProvider).counts, <int>[0, 0]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the sources sit under the card with their verbatim quote and locator', (WidgetTester tester) async {
      await _openAdhkar(tester);
      final DhikrItem first = catalog.itemsInOrder.first;
      expect(find.textContaining(first.evidence.first.quote!), findsOneWidget);
      expect(find.textContaining('صحيح البخاري'), findsWidgets);
      expect(find.text('بانتظار المراجعة العلمية'), findsOneWidget);
    });

    testWidgets('the screen survives a narrow phone with the largest fonts', (WidgetTester tester) async {
      await pumpApp(tester, size: const Size(360, 740), systemTextScale: 1.3);
      await tester.tap(_navLabel('وِرد الأذكار'));
      await settle(tester);
      expect(find.byType(AdhkarScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('adhkar-pill-1')));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('dhikr-remaining')),
        200,
        scrollable: find.descendant(of: find.byKey(const ValueKey<String>('adhkar-scroll')), matching: find.byType(Scrollable)),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
