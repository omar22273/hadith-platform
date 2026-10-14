// اختبارات السبحة النبوية الذكية: متحكم العدّ (جولات ٣٣ و١٠٠ والعدّ الحر والمجاميع
// المحفوظة وقراءة الحالة التالفة) والشاشة (خمسة أذكار وثلاثة أعداد، ونصف سفلي بنقرة
// واحدة، واهتزاز خفيف لكل تسبيحة ومزدوج عند الإتمام، وهالة خضراء، والحفظ المحلي).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/core/storage/key_value_store.dart';
import 'package:hadith_platform/core/theme/feedback_colors.dart';
import 'package:hadith_platform/features/adhkar/application/sebha_controller.dart';

import '../../support/adhkar_support.dart';
import '../../support/app_harness.dart';

Finder _zone() => find.byKey(const ValueKey<String>('sebha-tap-zone'));

String _count(WidgetTester tester) => tester.widget<Text>(find.byKey(const ValueKey<String>('sebha-count'))).data!;

String _dhikrTotal(WidgetTester tester) {
  return tester.widget<Text>(find.byKey(const ValueKey<String>('sebha-dhikr-total'))).data!;
}

Finder _dhikrPill(SebhaDhikr dhikr) => find.byKey(ValueKey<String>('sebha-dhikr-${dhikr.id}'));

Finder _targetPill(String suffix) => find.byKey(ValueKey<String>('sebha-target-$suffix'));

/// ينقر على منطقة اللمس عدداً من المرات.
Future<void> _tapZone(WidgetTester tester, int times) async {
  for (int i = 0; i < times; i++) {
    await tester.tap(_zone());
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('the sebha controller', () {
    test('starts with subhan Allah, a target of 33 and nothing counted', () {
      final ProviderContainer container = makeContainer();
      final SebhaState state = container.read(sebhaProvider);
      expect(state.dhikr, SebhaDhikr.subhanAllah);
      expect(state.target, SebhaTarget.thirtyThree);
      expect(state.count, 0);
      expect(state.totals, isEmpty);
      expect(state.roundComplete, isFalse);
      expect(state.remaining, 33);
      expect(state.grandTotal, 0);
    });

    test('offers exactly the five dhikr options and the three targets requested', () {
      expect(SebhaDhikr.values.map((SebhaDhikr d) => d.label).toList(), <String>[
        'سبحان الله',
        'الحمد لله',
        'الله أكبر',
        'الصلاة على النبي ﷺ',
        'الاستغفار',
      ]);
      expect(SebhaTarget.values.map((SebhaTarget t) => t.limit).toList(), <int>[33, 100, 0]);
      expect(SebhaDhikr.values.map((SebhaDhikr d) => d.id).toSet(), hasLength(5));
    });

    test('a round of 33 completes on the 33rd tap, and the next tap starts a new round', () {
      final ProviderContainer container = makeContainer();
      final SebhaController sebha = container.read(sebhaProvider.notifier);
      for (int i = 1; i < 33; i++) {
        expect(sebha.tap(), SebhaTapResult.counted, reason: 'tap $i');
      }
      expect(container.read(sebhaProvider).count, 32);
      expect(container.read(sebhaProvider).remaining, 1);
      expect(sebha.tap(), SebhaTapResult.roundCompleted);
      expect(container.read(sebhaProvider).count, 33);
      expect(container.read(sebhaProvider).roundComplete, isTrue);
      expect(container.read(sebhaProvider).remaining, 0);
      expect(container.read(sebhaProvider).dhikrTotal, 33);

      expect(sebha.tap(), SebhaTapResult.counted);
      expect(container.read(sebhaProvider).count, 1);
      expect(container.read(sebhaProvider).roundComplete, isFalse);
      expect(container.read(sebhaProvider).dhikrTotal, 34, reason: 'the saved total never loses a tap');
    });

    test('a round of 100 completes on the 100th tap', () {
      final ProviderContainer container = makeContainer();
      final SebhaController sebha = container.read(sebhaProvider.notifier);
      sebha.selectTarget(SebhaTarget.hundred);
      for (int i = 1; i < 100; i++) {
        expect(sebha.tap(), SebhaTapResult.counted, reason: 'tap $i');
      }
      expect(sebha.tap(), SebhaTapResult.roundCompleted);
      expect(container.read(sebhaProvider).count, 100);
    });

    test('the free count never completes and has no remaining number', () {
      final ProviderContainer container = makeContainer();
      final SebhaController sebha = container.read(sebhaProvider.notifier);
      sebha.selectTarget(SebhaTarget.free);
      for (int i = 0; i < 250; i++) {
        expect(sebha.tap(), SebhaTapResult.counted);
      }
      final SebhaState state = container.read(sebhaProvider);
      expect(state.count, 250);
      expect(state.roundComplete, isFalse);
      expect(state.remaining, isNull);
      expect(state.dhikrTotal, 250);
    });

    test('choosing another dhikr or target starts a new round but keeps every saved total', () {
      final ProviderContainer container = makeContainer();
      final SebhaController sebha = container.read(sebhaProvider.notifier);
      for (int i = 0; i < 5; i++) {
        sebha.tap();
      }
      sebha.selectDhikr(SebhaDhikr.istighfar);
      expect(container.read(sebhaProvider).count, 0);
      expect(container.read(sebhaProvider).dhikrTotal, 0);
      for (int i = 0; i < 3; i++) {
        sebha.tap();
      }
      expect(container.read(sebhaProvider).dhikrTotal, 3);
      expect(container.read(sebhaProvider).grandTotal, 8);
      expect(container.read(sebhaProvider).totals, <String, int>{'subhan_allah': 5, 'istighfar': 3});

      sebha.selectTarget(SebhaTarget.hundred);
      expect(container.read(sebhaProvider).count, 0);
      expect(container.read(sebhaProvider).grandTotal, 8);

      // اختيار الخيار المختار نفسه لا يصفّر شيئاً.
      sebha.tap();
      sebha.selectDhikr(SebhaDhikr.istighfar);
      sebha.selectTarget(SebhaTarget.hundred);
      expect(container.read(sebhaProvider).count, 1);
      expect(container.read(sebhaProvider).grandTotal, 9);
    });

    test('resetting the round zeroes the round counter only', () {
      final ProviderContainer container = makeContainer();
      final SebhaController sebha = container.read(sebhaProvider.notifier);
      for (int i = 0; i < 4; i++) {
        sebha.tap();
      }
      sebha.resetRound();
      expect(container.read(sebhaProvider).count, 0);
      expect(container.read(sebhaProvider).dhikrTotal, 4);
      sebha.resetRound();
      expect(container.read(sebhaProvider).count, 0);
    });

    test('every change is saved locally and a fresh start restores the choice, the round and the totals', () {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore();
      final ProviderContainer first = makeContainer(store: store);
      final SebhaController sebha = first.read(sebhaProvider.notifier);
      sebha.selectDhikr(SebhaDhikr.salawat);
      sebha.selectTarget(SebhaTarget.hundred);
      for (int i = 0; i < 12; i++) {
        sebha.tap();
      }
      sebha.selectDhikr(SebhaDhikr.allahuAkbar);
      sebha.tap();
      sebha.selectDhikr(SebhaDhikr.salawat);
      for (int i = 0; i < 2; i++) {
        sebha.tap();
      }

      final String? saved = store.readString(StorageKeys.adhkarSebha);
      expect(saved, isNotNull);
      expect(jsonDecode(saved!), isA<Map<String, dynamic>>());

      final ProviderContainer second = makeContainer(store: store);
      final SebhaState restored = second.read(sebhaProvider);
      expect(restored.dhikr, SebhaDhikr.salawat);
      expect(restored.target, SebhaTarget.hundred);
      expect(restored.count, 2);
      expect(restored.totals, <String, int>{'salawat': 14, 'allahu_akbar': 1});
      expect(restored.grandTotal, 15);
    });

    test('the storage key is registered, so the production store keeps it', () {
      expect(StorageKeys.all, contains(StorageKeys.adhkarSebha));
    });

    test('a damaged or foreign saved value falls back to the start instead of throwing', () {
      expect(SebhaState.decode(null), same(SebhaState.initial));
      expect(SebhaState.decode(''), same(SebhaState.initial));
      expect(SebhaState.decode('not json at all'), same(SebhaState.initial));
      expect(SebhaState.decode('[1, 2, 3]'), same(SebhaState.initial));

      final SebhaState partial = SebhaState.decode(
        '{"dhikr":"zzz","target":7,"count":-5,"totals":{"zzz":5,"salawat":-2,"istighfar":7,"alhamdulillah":2.5}}',
      );
      expect(partial.dhikr, SebhaDhikr.subhanAllah);
      expect(partial.target, SebhaTarget.thirtyThree);
      expect(partial.count, 0);
      expect(partial.totals, <String, int>{'istighfar': 7});

      final SebhaState tooHigh = SebhaState.decode('{"dhikr":"allahu_akbar","target":33,"count":99,"totals":{}}');
      expect(tooHigh.dhikr, SebhaDhikr.allahuAkbar);
      expect(tooHigh.count, 33, reason: 'a count above the target is clamped to the target');

      final ProviderContainer container = makeContainer(stored: <String, String>{StorageKeys.adhkarSebha: '}{'});
      expect(container.read(sebhaProvider).count, 0);
    });

    test('encode and decode round-trip the whole state', () {
      const SebhaState state = SebhaState(
        dhikr: SebhaDhikr.istighfar,
        target: SebhaTarget.free,
        count: 41,
        totals: <String, int>{'istighfar': 41, 'salawat': 9},
      );
      final SebhaState back = SebhaState.decode(state.encode());
      expect(back.dhikr, state.dhikr);
      expect(back.target, state.target);
      expect(back.count, 41);
      expect(back.totals, state.totals);
    });
  });

  group('the sebha screen', () {
    testWidgets('shows the five dhikr options, the three counts, and a calm ring starting at zero',
        (WidgetTester tester) async {
      await openSebha(tester);
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('sebha-title'))).data, 'السبحة النبوية الذكية');
      for (final SebhaDhikr dhikr in SebhaDhikr.values) {
        expect(find.descendant(of: _dhikrPill(dhikr), matching: find.text(dhikr.label)), findsOneWidget,
            reason: dhikr.label);
      }
      for (final String label in <String>['٣٣', '١٠٠', 'حر']) {
        expect(find.descendant(of: find.byKey(const ValueKey<String>('adhkar-sebha')), matching: find.text(label)),
            findsOneWidget,
            reason: label);
      }
      expect(_targetPill('33'), findsOneWidget);
      expect(_targetPill('100'), findsOneWidget);
      expect(_targetPill('free'), findsOneWidget);
      expect(find.byType(PageView), findsNothing, reason: 'the sebha is one calm screen, not a pager');

      expect(_count(tester), '٠');
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('sebha-dhikr-label'))).data, 'سبحان الله');
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('sebha-of-target'))).data, 'من ٣٣');
      expect(find.byKey(const ValueKey<String>('sebha-ring')), findsOneWidget);
      expect(_dhikrTotal(tester), 'مجموع سبحان الله: ٠');
      expect(find.byKey(const ValueKey<String>('sebha-round-complete')), findsNothing);
      expect(tester.widget<IconButton>(find.byKey(const ValueKey<String>('sebha-reset'))).onPressed, isNull);
    });

    testWidgets('the lower half is one tap zone: a tap anywhere counts with a light haptic, the options do not',
        (WidgetTester tester) async {
      final List<String> haptics = recordHaptics(tester);
      final ProviderContainer container = await openSebha(tester);

      final Rect screen = tester.getRect(find.byKey(const ValueKey<String>('adhkar-sebha')));
      final Rect zone = tester.getRect(_zone());
      expect(zone.top, greaterThanOrEqualTo(screen.center.dy - screen.height * 0.25), reason: 'the lower part');
      expect(zone.bottom, lessThanOrEqualTo(screen.bottom + 0.5));
      expect(zone.width, greaterThan(screen.width - 40), reason: 'it spans the width');
      expect(zone.height, greaterThan(screen.height * 0.4), reason: 'it fills most of the lower half');

      for (final Offset point in <Offset>[
        zone.topLeft + const Offset(24, 24),
        zone.center,
        zone.bottomRight - const Offset(24, 24),
      ]) {
        await tester.tapAt(point);
        await tester.pump(const Duration(milliseconds: 60));
      }
      await settle(tester);
      expect(container.read(sebhaProvider).count, 3);
      expect(_count(tester), '٣');
      expect(_dhikrTotal(tester), 'مجموع سبحان الله: ٣');
      expect(haptics.where((String h) => h == 'HapticFeedbackType.selectionClick'), hasLength(3));
      expect(haptics.where((String h) => h == 'HapticFeedbackType.mediumImpact'), isEmpty);
      expect(tester.widget<IconButton>(find.byKey(const ValueKey<String>('sebha-reset'))).onPressed, isNotNull);
    });

    testWidgets('reaching 33 gives a double medium haptic and a green halo, and the next tap starts a new round',
        (WidgetTester tester) async {
      final List<String> haptics = recordHaptics(tester);
      final ProviderContainer container = await openSebha(tester);
      AnimatedContainer surface() =>
          tester.widget<AnimatedContainer>(find.byKey(const ValueKey<String>('sebha-zone-surface')));
      List<BoxShadow> shadows() => (surface().decoration! as ShapeDecoration).shadows!.cast<BoxShadow>();
      final FeedbackColors feedback =
          FeedbackColors.of(tester.element(find.byKey(const ValueKey<String>('sebha-zone-surface'))));
      bool halo() => shadows().any((BoxShadow s) => s.color == feedback.rightBorder.withValues(alpha: 0.5));

      await _tapZone(tester, 32);
      expect(_count(tester), '٣٢');
      expect(halo(), isFalse);
      expect(haptics.where((String h) => h == 'HapticFeedbackType.mediumImpact'), isEmpty, reason: 'not yet');

      haptics.clear();
      await tester.tap(_zone());
      await tester.pump();
      expect(haptics, <String>['HapticFeedbackType.mediumImpact']);
      await tester.pump(const Duration(milliseconds: 200));
      expect(haptics, <String>['HapticFeedbackType.mediumImpact', 'HapticFeedbackType.mediumImpact']);
      await tester.pump(const Duration(milliseconds: 600));

      expect(container.read(sebhaProvider).roundComplete, isTrue);
      expect(_count(tester), '٣٣');
      expect(halo(), isTrue);
      expect(find.byKey(const ValueKey<String>('sebha-round-complete')), findsOneWidget);
      expect(find.text('اكتملت الجولة'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('sebha-of-target')), findsNothing);

      haptics.clear();
      await tester.tap(_zone());
      await tester.pump(const Duration(milliseconds: 400));
      expect(_count(tester), '١');
      expect(halo(), isFalse);
      expect(find.byKey(const ValueKey<String>('sebha-round-complete')), findsNothing);
      expect(_dhikrTotal(tester), 'مجموع سبحان الله: ٣٤');
      expect(haptics, <String>['HapticFeedbackType.selectionClick']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('choosing another dhikr resets the round, shows its own total and keeps the grand total',
        (WidgetTester tester) async {
      recordHaptics(tester);
      final ProviderContainer container = await openSebha(tester);
      await _tapZone(tester, 4);

      await tester.tap(_dhikrPill(SebhaDhikr.istighfar));
      await settle(tester);
      expect(container.read(sebhaProvider).dhikr, SebhaDhikr.istighfar);
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('sebha-dhikr-label'))).data, 'الاستغفار');
      expect(_count(tester), '٠');
      expect(_dhikrTotal(tester), 'مجموع الاستغفار: ٠');
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('sebha-grand-total'))).data, 'المجموع الكلي: ٤');

      await _tapZone(tester, 2);
      expect(_dhikrTotal(tester), 'مجموع الاستغفار: ٢');
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('sebha-grand-total'))).data, 'المجموع الكلي: ٦');

      await tester.tap(_dhikrPill(SebhaDhikr.subhanAllah));
      await settle(tester);
      expect(_dhikrTotal(tester), 'مجموع سبحان الله: ٤');

      // الأذكار الخمسة كلها قابلة للاختيار والعدّ.
      for (final SebhaDhikr dhikr in SebhaDhikr.values) {
        await tester.tap(_dhikrPill(dhikr));
        await settle(tester);
        expect(tester.widget<Text>(find.byKey(const ValueKey<String>('sebha-dhikr-label'))).data, dhikr.label);
      }
    });

    testWidgets('the 100 target counts to a hundred and shows it in the ring', (WidgetTester tester) async {
      recordHaptics(tester);
      final ProviderContainer container = await openSebha(tester);
      await tester.tap(_targetPill('100'));
      await settle(tester);
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('sebha-of-target'))).data, 'من ١٠٠');

      await _tapZone(tester, 33);
      expect(_count(tester), '٣٣');
      expect(container.read(sebhaProvider).roundComplete, isFalse, reason: 'a hundred is not reached at 33');
      expect(find.byKey(const ValueKey<String>('sebha-round-complete')), findsNothing);
    });

    testWidgets('the free count keeps going without a target, a completion or a double haptic',
        (WidgetTester tester) async {
      final List<String> haptics = recordHaptics(tester);
      final ProviderContainer container = await openSebha(tester);
      await tester.tap(_targetPill('free'));
      await settle(tester);
      expect(find.byKey(const ValueKey<String>('sebha-of-target')), findsNothing);

      haptics.clear();
      await _tapZone(tester, 110);
      expect(container.read(sebhaProvider).count, 110);
      expect(_count(tester), '١١٠');
      expect(find.byKey(const ValueKey<String>('sebha-round-complete')), findsNothing);
      expect(haptics, everyElement('HapticFeedbackType.selectionClick'));
      expect(haptics, hasLength(110));
    });

    testWidgets('the reset button zeroes the round but keeps the saved totals', (WidgetTester tester) async {
      recordHaptics(tester);
      final ProviderContainer container = await openSebha(tester);
      await _tapZone(tester, 6);
      await tester.tap(find.byKey(const ValueKey<String>('sebha-reset')));
      await settle(tester);
      expect(_count(tester), '٠');
      expect(_dhikrTotal(tester), 'مجموع سبحان الله: ٦');
      expect(container.read(sebhaProvider).dhikrTotal, 6);
      expect(tester.widget<IconButton>(find.byKey(const ValueKey<String>('sebha-reset'))).onPressed, isNull);
    });

    testWidgets('the count survives leaving the screen and a full restart of the app', (WidgetTester tester) async {
      recordHaptics(tester);
      final ProviderContainer container = await openSebha(tester);
      await tester.tap(_dhikrPill(SebhaDhikr.salawat));
      await settle(tester);
      await _tapZone(tester, 5);

      await tester.tap(find.byKey(const ValueKey<String>('sebha-back')));
      await settle(tester);
      expect(find.byKey(const ValueKey<String>('adhkar-hub')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('adhkar-card-sebha-subtitle'))).data,
          'مجموع ما سبّحتَه: ٥');

      await revealCard(tester, find.byKey(sebhaCardKey));
      await tester.tap(find.byKey(sebhaCardKey));
      await settle(tester);
      expect(_count(tester), '٥');
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('sebha-dhikr-label'))).data,
          'الصلاة على النبي ﷺ');

      // إعادة تشغيل كاملة بالقيمة المحفوظة في المخزن المحلي.
      final String saved = container.read(keyValueStoreProvider).readString(StorageKeys.adhkarSebha)!;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await openSebha(tester, stored: <String, String>{StorageKeys.adhkarSebha: saved});
      expect(_count(tester), '٥');
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('sebha-dhikr-label'))).data,
          'الصلاة على النبي ﷺ');
      expect(_dhikrTotal(tester), 'مجموع الصلاة على النبي ﷺ: ٥');
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('sebha-of-target'))).data, 'من ٣٣');
    });

    testWidgets('a narrow phone with the largest fonts keeps every control and the ring inside the screen',
        (WidgetTester tester) async {
      recordHaptics(tester);
      await openSebha(tester, size: const Size(360, 640), systemTextScale: 1.3);
      expect(tester.takeException(), isNull);
      for (final Finder control in <Finder>[
        _dhikrPill(SebhaDhikr.subhanAllah),
        _dhikrPill(SebhaDhikr.salawat),
        _dhikrPill(SebhaDhikr.istighfar),
        _targetPill('33'),
        _targetPill('free'),
        find.byKey(const ValueKey<String>('sebha-ring')),
        find.byKey(const ValueKey<String>('sebha-count')),
      ]) {
        final Rect rect = tester.getRect(control);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(360));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(640));
      }
      await _tapZone(tester, 3);
      expect(_count(tester), '٣');
      expect(tester.takeException(), isNull);
    });
  });
}
