// اختبارات زر «تجاوز للاختبار ⚡»: لا يظهر ولا يعمل إلا إذا كان «تخطي قفل
// الفجر دائماً» مفعّلاً في الإعدادات؛ وإذا ضُغط رُتّبت كل العبارات ترتيباً صحيحاً
// وانفتح «التالي» فوراً، في الوِرد اليومي وفي ميدان المراجعة معاً.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/app/app_shell_screen.dart';
import 'package:hadith_platform/core/storage/key_value_store.dart';
import 'package:hadith_platform/features/daily_session/application/session_controller.dart';
import 'package:hadith_platform/features/daily_session/application/session_state.dart';
import 'package:hadith_platform/features/hadith/domain/practice_engine.dart';
import 'package:hadith_platform/features/journey/domain/pacing.dart';
import 'package:hadith_platform/features/journey/presentation/widgets/wird_node.dart';
import 'package:hadith_platform/features/review/application/review_controllers.dart';
import 'package:hadith_platform/features/review/domain/review_deck.dart';

import '../support/app_harness.dart';

const String _id = 'nawawi40_001';

const ValueKey<String> _skipKey = ValueKey<String>('testing-skip');

String _pacingJson({required bool bypass}) {
  return jsonEncode(PacingSettings.initial.copyWith(alwaysBypassLock: bypass).toJson());
}

Finder _navLabel(String label) {
  return find.descendant(of: find.byType(AppBottomBar), matching: find.text(label));
}

Future<ProviderContainer> _openPractice(WidgetTester tester, {required bool bypass}) async {
  final ProviderContainer container = await pumpApp(
    tester,
    size: const Size(412, 1800),
    stored: <String, String>{StorageKeys.pacing: _pacingJson(bypass: bypass)},
  );
  await tester.tap(find.descendant(of: find.byType(WirdNodeView), matching: find.text('الأعمال بالنيات')).first);
  await settle(tester);
  await tester.tap(find.text('بدء وِرد التثبيت اللمسي'));
  await settle(tester);
  container.read(sessionControllerProvider(_id).notifier).goTo(SessionStage.practice);
  await settle(tester);
  return container;
}

Future<ProviderContainer> _openWordOrder(WidgetTester tester, {required bool bypass}) async {
  final ProviderContainer container = await pumpApp(
    tester,
    size: const Size(412, 1600),
    stored: <String, String>{
      StorageKeys.journeyProgress: completedProgressJson(),
      StorageKeys.pacing: _pacingJson(bypass: bypass),
    },
  );
  await tester.tap(_navLabel('ميدان المراجعة'));
  await settle(tester);
  await tester.tap(find.text('ترتيب المتن'));
  await settle(tester);
  return container;
}

FilledButton _button(WidgetTester tester, String key) {
  return tester.widget<FilledButton>(find.byKey(ValueKey<String>(key)));
}

void main() {
  group('daily session practice stage', () {
    testWidgets('the skip button is hidden and inert while the bypass setting is off', (WidgetTester tester) async {
      final ProviderContainer container = await _openPractice(tester, bypass: false);
      final SessionController controller = container.read(sessionControllerProvider(_id).notifier);

      expect(find.byKey(_skipKey), findsNothing);
      expect(controller.skipPracticeForTesting(), isFalse);
      expect(container.read(sessionControllerProvider(_id)).completedDrills, isEmpty);
      expect(_button(tester, 'practice-next').onPressed, isNull);
    });

    testWidgets('the skip button places every phrase in order and unlocks next at once', (WidgetTester tester) async {
      final ProviderContainer container = await _openPractice(tester, bypass: true);
      final SessionController controller = container.read(sessionControllerProvider(_id).notifier);
      final PracticeEngine engine = container.read(practiceEngineProvider(_id))!;

      expect(find.byKey(_skipKey), findsOneWidget);
      expect(find.text('تجاوز للاختبار ⚡'), findsOneWidget);
      expect(controller.practiceCleared, isFalse);
      expect(_button(tester, 'practice-next').onPressed, isNull);

      await tester.tap(find.byKey(_skipKey));
      await settle(tester);

      final SessionState state = container.read(sessionControllerProvider(_id));
      expect(state.completedDrills.length, engine.drills.length);
      expect(state.drillIndex, engine.drills.length - 1);
      expect(state.placedTiles.length, engine.drills.last.tokens.length);
      expect(controller.currentDrillMatches, isTrue);
      expect(controller.practiceCleared, isTrue);
      expect(_button(tester, 'practice-next').onPressed, isNotNull);
      expect(_button(tester, 'session-next').onPressed, isNotNull);

      await tester.tap(find.byKey(const ValueKey<String>('practice-next')));
      await settle(tester);
      expect(container.read(sessionControllerProvider(_id)).stage, SessionStage.reflection);
      expect(tester.takeException(), isNull);
    });
  });

  group('review arena word order', () {
    testWidgets('the skip button is hidden and inert while the bypass setting is off', (WidgetTester tester) async {
      final ProviderContainer container = await _openWordOrder(tester, bypass: false);
      final OrderChallengeController controller = container.read(orderChallengeProvider.notifier);

      expect(find.byKey(_skipKey), findsNothing);
      expect(controller.skipAllForTesting(), isFalse);
      expect(container.read(orderChallengeProvider).completed, isEmpty);
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey<String>('order-next-segment'))).onPressed, isNull);
    });

    testWidgets('the skip button solves every challenge and enables the next button', (WidgetTester tester) async {
      final ProviderContainer container = await _openWordOrder(tester, bypass: true);
      final ReviewDeck deck = await container.read(reviewDeckProvider.future);
      final Finder nextButton = find.byKey(const ValueKey<String>('order-next-segment'));

      expect(find.byKey(_skipKey), findsOneWidget);
      expect(tester.widget<FilledButton>(nextButton).onPressed, isNull);

      await tester.tap(find.byKey(_skipKey));
      await settle(tester);

      final OrderChallengeState state = container.read(orderChallengeProvider);
      expect(state.completed.length, deck.orderChallenges.length);
      expect(state.board!.completed, isTrue);
      expect(state.board!.placedTiles.length, deck.orderChallenges.first.drill.tokens.length);
      expect(tester.widget<FilledButton>(nextButton).onPressed, isNotNull);

      await tester.tap(nextButton);
      await settle(tester);
      final OrderChallengeState moved = container.read(orderChallengeProvider);
      expect(moved.index, 1);
      expect(moved.board!.completed, isTrue, reason: 'the next challenge is shown already solved');
      expect(tester.takeException(), isNull);
    });
  });
}
