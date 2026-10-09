// اختبارات إحكام ترتيب المتن: لا انتقال إلى المقطع التالي قبل مطابقة تامة،
// والمقاطع العلوية مقفلة، ونجاح المقطع يطلق اهتزازاً خفيفاً وزراً عريضاً، وعدم
// المطابقة ينبّه بلطف دون تفعيل الزر.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/app/app_shell_screen.dart';
import 'package:hadith_platform/core/storage/key_value_store.dart';
import 'package:hadith_platform/features/hadith/domain/practice_engine.dart';
import 'package:hadith_platform/features/review/application/review_controllers.dart';
import 'package:hadith_platform/features/review/domain/review_deck.dart';
import 'package:hadith_platform/features/review/domain/review_sessions.dart';

import '../../support/app_harness.dart';

Finder _navLabel(String label) {
  return find.descendant(of: find.byType(AppBottomBar), matching: find.text(label));
}

/// يسجل استدعاءات المنصة: كل اهتزاز بنوعه.
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

/// بلاطة غير مستعملة تطابق الموضع، أو لا تطابقه إن كان [matching] false.
int _tile(ProviderContainer container, ChunkDrill drill, int position, {required bool matching}) {
  final OrderBoard board = container.read(orderChallengeProvider).board!;
  return drill.tiles
      .firstWhere((PracticeTile t) => !board.isUsed(t.id) && drill.fits(t.id, position) == matching)
      .id;
}

Future<ProviderContainer> _openWordOrder(WidgetTester tester) async {
  final ProviderContainer container = await pumpApp(
    tester,
    size: const Size(412, 1600),
    stored: <String, String>{StorageKeys.journeyProgress: completedProgressJson()},
  );
  await tester.tap(_navLabel('ميدان المراجعة'));
  await settle(tester);
  await tester.tap(find.text('ترتيب المتن'));
  await settle(tester);
  return container;
}

Finder _draggable(int tileId) {
  return find.byWidgetPredicate((Widget w) => w is Draggable<int> && w.data == tileId);
}

void main() {
  testWidgets('the controller never advances before a 100% match, and skipping ahead is ignored', (WidgetTester tester) async {
    final ProviderContainer container = await _openWordOrder(tester);
    final ReviewDeck deck = await container.read(reviewDeckProvider.future);
    final OrderChallengeController controller = container.read(orderChallengeProvider.notifier);
    final ChunkDrill drill = deck.orderChallenges.first.drill;

    expect(controller.advance(), isFalse, reason: 'nothing placed yet');

    // كلمة غير مطابقة تُرفض ولا تُحرّك شيئاً.
    final int wrong = _tile(container, drill, 0, matching: false);
    expect(controller.place(wrong), PlacementOutcome.mismatch);
    expect(container.read(orderChallengeProvider).board!.placedTiles, isEmpty);
    expect(controller.advance(), isFalse);

    // كل الكلمات إلا الأخيرة: لا يزال الانتقال ممنوعاً.
    for (int position = 0; position < drill.tokens.length - 1; position++) {
      controller.place(_tile(container, drill, position, matching: true));
    }
    expect(container.read(orderChallengeProvider).board!.completed, isFalse);
    expect(controller.advance(), isFalse);
    expect(container.read(orderChallengeProvider).index, 0);

    // محاولات القفز اليدوي إلى المقاطع العلوية لا تفعل شيئاً.
    controller.select(1);
    controller.select(deck.orderChallenges.length - 1);
    controller.select(5000);
    controller.select(-3);
    expect(container.read(orderChallengeProvider).index, 0);

    // الكلمة الأخيرة تكمل المقطع، ثم ينتقل.
    expect(
      controller.place(_tile(container, drill, drill.tokens.length - 1, matching: true)),
      PlacementOutcome.completed,
    );
    expect(controller.advance(), isTrue);
    expect(container.read(orderChallengeProvider).index, 1);
    expect(container.read(orderChallengeProvider).board!.placedTiles, isEmpty);

    // الرجوع إلى مقطع مكتمل يبدأ لوحة جديدة، ولا انتقال منها قبل إتمامها ثانية.
    controller.select(0);
    expect(container.read(orderChallengeProvider).index, 0);
    expect(controller.advance(), isFalse);
  });

  testWidgets('a mismatch shows a gentle notice and keeps the next button disabled', (WidgetTester tester) async {
    final ProviderContainer container = await _openWordOrder(tester);
    final ReviewDeck deck = await container.read(reviewDeckProvider.future);
    final ChunkDrill drill = deck.orderChallenges.first.drill;
    final Finder notice = find.byKey(const ValueKey<String>('order-mismatch-notice'));
    final Finder nextButton = find.byKey(const ValueKey<String>('order-next-segment'));
    final List<String> haptics = _recordHaptics(tester);

    expect(notice, findsNothing);
    expect(tester.widget<FilledButton>(nextButton).onPressed, isNull);

    await tester.tap(_draggable(_tile(container, drill, 0, matching: false)));
    await settle(tester);
    expect(notice, findsOneWidget);
    expect(find.textContaining('عادت إلى مكانها'), findsOneWidget);
    expect(container.read(orderChallengeProvider).board!.placedTiles, isEmpty, reason: 'the wrong word returned to place');
    expect(tester.widget<FilledButton>(nextButton).onPressed, isNull);
    expect(haptics, contains('HapticFeedbackType.selectionClick'));
    expect(tester.takeException(), isNull);

    // الكلمة الصحيحة تزيل التنبيه.
    await tester.tap(_draggable(_tile(container, drill, 0, matching: true)));
    await settle(tester);
    expect(notice, findsNothing);
  });

  testWidgets('finishing a segment flashes success, vibrates lightly and shows the wide next button', (WidgetTester tester) async {
    final ProviderContainer container = await _openWordOrder(tester);
    final ReviewDeck deck = await container.read(reviewDeckProvider.future);
    expect(deck.orderChallenges.length, greaterThan(1));
    final ChunkDrill drill = deck.orderChallenges.first.drill;
    final Finder nextButton = find.byKey(const ValueKey<String>('order-next-segment'));
    final List<String> haptics = _recordHaptics(tester);

    // قبل الإتمام: الزر معطّل، والمقاطع العلوية مقفلة لا تُنقر.
    final double lockedHeight = tester.getSize(nextButton).height;
    expect(tester.widget<FilledButton>(nextButton).onPressed, isNull);
    final Finder chips = find.byType(ChoiceChip);
    expect(tester.widget<ChoiceChip>(chips.at(0)).onSelected, isNotNull);
    for (int i = 1; i < deck.orderChallenges.length; i++) {
      expect(tester.widget<ChoiceChip>(chips.at(i)).onSelected, isNull, reason: 'segment ${i + 1} is locked');
    }
    await tester.tap(chips.at(1), warnIfMissed: false);
    await settle(tester);
    expect(container.read(orderChallengeProvider).index, 0);

    for (int position = 0; position < drill.tokens.length; position++) {
      await tester.tap(_draggable(_tile(container, drill, position, matching: true)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await settle(tester);

    expect(container.read(orderChallengeProvider).board!.completed, isTrue);
    expect(haptics, contains('HapticFeedbackType.lightImpact'));
    expect(haptics, isNot(contains('HapticFeedbackType.mediumImpact')));
    expect(tester.widget<FilledButton>(nextButton).onPressed, isNotNull);
    expect(tester.getSize(nextButton).height, greaterThan(lockedHeight), reason: 'the button becomes prominent');
    expect(tester.getSize(nextButton).width, greaterThan(300), reason: 'and spans the width');
    expect(find.descendant(of: nextButton, matching: find.text('المقطع التالي')), findsOneWidget);
    expect(find.descendant(of: nextButton, matching: find.byIcon(Icons.arrow_forward_rounded)), findsOneWidget);
    expect(tester.widget<ChoiceChip>(find.byType(ChoiceChip).at(1)).onSelected, isNotNull, reason: 'segment 2 unlocked');

    await tester.tap(nextButton);
    await settle(tester);
    expect(container.read(orderChallengeProvider).index, 1);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey<String>('order-next-segment'))).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
