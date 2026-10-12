// اختبارات إحكام رتّب ألفاظ الحديث في الوِرد اليومي: زر «التالي» معطّل برمجياً
// ورمادي حتى تطابق مصفوفة الكلمات المتنَ المشكول تماماً، ثم يومض الحوض بالأخضر
// ويهتز الجهاز اهتزازة خفيفة ويتفعّل الزر بارزاً؛ والمقاطع اللاحقة مقفلة،
// ولا يُفتح ما بعد التثبيت قبل إتمام كل المقاطع، لا بالزر ولا بشريط المراحل.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/core/theme/feedback_colors.dart';
import 'package:hadith_platform/core/ui/completion_flash.dart';
import 'package:hadith_platform/features/daily_session/application/session_controller.dart';
import 'package:hadith_platform/features/daily_session/application/session_state.dart';
import 'package:hadith_platform/features/daily_session/presentation/widgets/session_header.dart';
import 'package:hadith_platform/features/hadith/domain/practice_engine.dart';
import 'package:hadith_platform/features/journey/presentation/widgets/wird_node.dart';
import 'package:smooth_corner/smooth_corner.dart';

import '../../support/app_harness.dart';

const String _id = 'nawawi40_001';

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

/// يفتح وِرد اليوم من المسار ويعيد حاوية التطبيق.
Future<ProviderContainer> _openSession(WidgetTester tester) async {
  final ProviderContainer container = await pumpApp(tester, size: const Size(412, 1800));
  await tester.tap(find.descendant(of: find.byType(WirdNodeView), matching: find.text('الأعمال بالنيات')).first);
  await settle(tester);
  await tester.tap(find.text('بدء وِرد التثبيت اللمسي'));
  await settle(tester);
  return container;
}

/// بلاطة غير موضوعة تطابق الموضع، أو لا تطابقه إن كان [matching] false.
int _tile(ProviderContainer container, ChunkDrill drill, int position, {required bool matching}) {
  final List<int> placed = container.read(sessionControllerProvider(_id)).placedTiles;
  return drill.tiles
      .firstWhere((PracticeTile t) => !placed.contains(t.id) && drill.fits(t.id, position) == matching)
      .id;
}

Finder _tileFinder(int drillIndex, int tileId) => find.byKey(ValueKey<String>('tile-$drillIndex-$tileId'));

FilledButton _button(WidgetTester tester, String key) {
  return tester.widget<FilledButton>(find.byKey(ValueKey<String>(key)));
}

/// يرتّب المقطع الحالي كله بالمتحكم، دون الواجهة.
void _solveCurrent(ProviderContainer container, ChunkDrill drill) {
  final SessionController controller = container.read(sessionControllerProvider(_id).notifier);
  for (int position = 0; position < drill.tokens.length; position++) {
    controller.placeTile(_tile(container, drill, position, matching: true));
  }
}

void main() {
  test('the gate helpers: cleared only when every drill is done, and the open limit trails the first gap', () {
    expect(isPracticeCleared(null, const <int>{}), isFalse, reason: 'no engine yet');
    expect(openDrillLimit(5, const <int>{}), 0);
    expect(openDrillLimit(5, const <int>{0, 1}), 2);
    expect(openDrillLimit(5, const <int>{1, 2}), 0, reason: 'a gap keeps later drills locked');
    expect(openDrillLimit(5, const <int>{0, 1, 2, 3, 4}), 4);
    expect(openDrillLimit(0, const <int>{}), 0);
  });

  testWidgets('next stays disabled and grey until the matn matches 100%, then turns prominent', (WidgetTester tester) async {
    final List<String> haptics = _recordHaptics(tester);
    final ProviderContainer container = await _openSession(tester);
    final SessionController controller = container.read(sessionControllerProvider(_id).notifier);
    final PracticeEngine engine = container.read(practiceEngineProvider(_id))!;
    expect(engine.drills.length, greaterThan(1));
    final ChunkDrill drill = engine.drills.first;

    // الوصول إلى التثبيت بالزر الفعلي.
    await tester.tap(find.byKey(const ValueKey<String>('session-next')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey<String>('session-next')));
    await settle(tester);
    expect(container.read(sessionControllerProvider(_id)).stage, SessionStage.practice);

    // الزران معطلان برمجياً (onPressed: null) قبل أي إنجاز.
    expect(_button(tester, 'session-next').onPressed, isNull);
    expect(_button(tester, 'practice-next').onPressed, isNull);
    final double lockedHeight = tester.getSize(find.byKey(const ValueKey<String>('practice-next'))).height;
    expect(find.byKey(const ValueKey<String>('practice-gate-note')), findsOneWidget);
    expect(find.textContaining('اكتمل ترصيع المتن كله'), findsNothing);

    // المقاطع اللاحقة مقفلة ورمادية.
    final Finder chips = find.byType(ChoiceChip);
    expect(chips.evaluate().length, greaterThan(1));
    expect(tester.widget<ChoiceChip>(chips.at(0)).onSelected, isNotNull);
    for (int i = 1; i < chips.evaluate().length; i++) {
      expect(tester.widget<ChoiceChip>(chips.at(i)).onSelected, isNull, reason: 'drill ${i + 1} is locked');
    }

    // لمس شريط المراحل أو طلب القفز برمجياً لا يتجاوز التثبيت.
    await tester.tap(find.descendant(of: find.byType(SessionHeader), matching: find.text('الإسقاط')), warnIfMissed: false);
    await settle(tester);
    controller.goTo(SessionStage.reflection);
    controller.selectDrill(1);
    controller.selectDrill(engine.drills.length - 1);
    expect(container.read(sessionControllerProvider(_id)).stage, SessionStage.practice);
    expect(container.read(sessionControllerProvider(_id)).drillIndex, 0);

    // كلمة غير مطابقة تعود بلطف ولا تفعّل شيئاً.
    await tester.tap(_tileFinder(0, _tile(container, drill, 0, matching: false)));
    await settle(tester);
    expect(container.read(sessionControllerProvider(_id)).placedTiles, isEmpty);
    expect(haptics, contains('HapticFeedbackType.selectionClick'));
    expect(_button(tester, 'practice-next').onPressed, isNull);

    // كل الكلمات إلا الأخيرة: لا يزال الانتقال ممنوعاً في الواجهة والمتحكم.
    for (int position = 0; position < drill.tokens.length - 1; position++) {
      await tester.tap(_tileFinder(0, _tile(container, drill, position, matching: true)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await settle(tester);
    expect(_button(tester, 'practice-next').onPressed, isNull);
    expect(controller.currentDrillMatches, isFalse);
    expect(controller.advanceFromDrill(), isFalse);
    controller.nextDrill();
    expect(container.read(sessionControllerProvider(_id)).drillIndex, 0);

    // الكلمة الأخيرة: اهتزازة خفيفة، ووميض أخضر، وزر عريض بارز.
    haptics.clear();
    await tester.tap(_tileFinder(0, _tile(container, drill, drill.tokens.length - 1, matching: true)));
    await settle(tester);
    expect(haptics, contains('HapticFeedbackType.lightImpact'));
    expect(haptics, isNot(contains('HapticFeedbackType.mediumImpact')));
    expect(controller.currentDrillMatches, isTrue);

    final DecoratedBox surface = tester.widget<DecoratedBox>(
      find.descendant(of: find.byType(CompletionFlash), matching: find.byType(DecoratedBox)).first,
    );
    final SmoothRectangleBorder border = (surface.decoration as ShapeDecoration).shape as SmoothRectangleBorder;
    expect(border.side.color, FeedbackColors.of(tester.element(find.byType(CompletionFlash))).rightBorder);

    final Finder practiceNext = find.byKey(const ValueKey<String>('practice-next'));
    expect(_button(tester, 'practice-next').onPressed, isNotNull);
    expect(tester.getSize(practiceNext).height, greaterThan(lockedHeight));
    expect(tester.getSize(practiceNext).width, greaterThan(300));
    expect(find.descendant(of: practiceNext, matching: find.text('المقطع التالي')), findsOneWidget);
    expect(find.descendant(of: practiceNext, matching: find.byIcon(Icons.arrow_forward_rounded)), findsOneWidget);
    expect(tester.widget<ChoiceChip>(find.byType(ChoiceChip).at(1)).onSelected, isNotNull, reason: 'drill 2 unlocked');
    // مقاطع باقية: زر الخطوة التالية في الشريط السفلي ما زال مقفلاً.
    expect(_button(tester, 'session-next').onPressed, isNull);

    await tester.tap(practiceNext);
    await settle(tester);
    expect(container.read(sessionControllerProvider(_id)).drillIndex, 1);
    expect(_button(tester, 'practice-next').onPressed, isNull, reason: 'the next drill starts locked again');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a solved drill returns solved, and resetting it locks next again', (WidgetTester tester) async {
    final ProviderContainer container = await _openSession(tester);
    final SessionController controller = container.read(sessionControllerProvider(_id).notifier);
    final PracticeEngine engine = container.read(practiceEngineProvider(_id))!;
    controller.goTo(SessionStage.practice);
    await settle(tester);

    _solveCurrent(container, engine.drills.first);
    controller.nextDrill();
    await settle(tester);
    expect(container.read(sessionControllerProvider(_id)).drillIndex, 1);

    controller.selectDrill(0);
    await settle(tester);
    final SessionState back = container.read(sessionControllerProvider(_id));
    expect(back.placedTiles.length, engine.drills.first.tokens.length);
    expect(controller.currentDrillMatches, isTrue);
    expect(_button(tester, 'practice-next').onPressed, isNotNull);

    controller.resetDrill();
    await settle(tester);
    expect(controller.currentDrillMatches, isFalse);
    expect(_button(tester, 'practice-next').onPressed, isNull);

    // لمس رقاقة المقطع الحالي لا يمحو ما رُصّ فيه.
    controller.placeTile(_tile(container, engine.drills.first, 0, matching: true));
    controller.selectDrill(0);
    expect(container.read(sessionControllerProvider(_id)).placedTiles.length, 1);
  });

  testWidgets('finishing every drill opens the next step, by the bottom button or the in-board one', (WidgetTester tester) async {
    final ProviderContainer container = await _openSession(tester);
    final SessionController controller = container.read(sessionControllerProvider(_id).notifier);
    final PracticeEngine engine = container.read(practiceEngineProvider(_id))!;
    controller.goTo(SessionStage.practice);
    await settle(tester);

    for (int d = 0; d < engine.drills.length; d++) {
      expect(controller.practiceCleared, isFalse);
      _solveCurrent(container, engine.drills[d]);
      if (d + 1 < engine.drills.length) {
        expect(controller.advanceFromDrill(), isTrue);
      }
    }
    await settle(tester);

    expect(controller.practiceCleared, isTrue);
    expect(container.read(sessionControllerProvider(_id)).stage, SessionStage.practice);
    expect(_button(tester, 'session-next').onPressed, isNotNull);
    expect(_button(tester, 'practice-next').onPressed, isNotNull);
    expect(find.descendant(of: find.byKey(const ValueKey<String>('practice-next')), matching: find.text('إتمام التثبيت والمتابعة')), findsOneWidget);
    expect(find.textContaining('اكتمل ترصيع المتن كله'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('practice-next')));
    await settle(tester);
    expect(container.read(sessionControllerProvider(_id)).stage, SessionStage.reflection);

    // بعد الفتح يعود التنقل الحر بشريط المراحل.
    controller.goTo(SessionStage.practice);
    controller.goTo(SessionStage.reflection);
    expect(container.read(sessionControllerProvider(_id)).stage, SessionStage.reflection);
    expect(tester.takeException(), isNull);
  });

  testWidgets('three consecutive wrong taps make the next correct word glow amber, and nothing unlocks', (WidgetTester tester) async {
    _recordHaptics(tester);
    final ProviderContainer container = await _openSession(tester);
    final SessionController controller = container.read(sessionControllerProvider(_id).notifier);
    final PracticeEngine engine = container.read(practiceEngineProvider(_id))!;
    final ChunkDrill drill = engine.drills.first;
    controller.goTo(SessionStage.practice);
    await settle(tester);

    final Finder glow = find.byKey(const ValueKey<String>('hint-glow'));
    Future<void> tapWrong() async {
      await tester.tap(_tileFinder(0, _tile(container, drill, container.read(sessionControllerProvider(_id)).placedTiles.length, matching: false)));
      await settle(tester);
    }

    // خطآن لا يكفيان.
    await tapWrong();
    await tapWrong();
    expect(container.read(sessionControllerProvider(_id)).mistakeStreak, 2);
    expect(glow, findsNothing);

    // الثالث يُضيء الكلمة الصحيحة التالية وحدها.
    await tapWrong();
    expect(container.read(sessionControllerProvider(_id)).mistakeStreak, 3);
    final int right = _tile(container, drill, 0, matching: true);
    expect(glow, findsOneWidget);
    expect(find.descendant(of: _tileFinder(0, right), matching: glow), findsOneWidget);

    // التلميح بصري فقط: لم توضع كلمة، والقفل كما هو.
    expect(container.read(sessionControllerProvider(_id)).placedTiles, isEmpty);
    expect(_button(tester, 'practice-next').onPressed, isNull);
    expect(_button(tester, 'session-next').onPressed, isNull);
    expect(controller.advanceFromDrill(), isFalse);

    // خطأ رابع لا يغيّر الكلمة المضيئة.
    await tapWrong();
    expect(find.descendant(of: _tileFinder(0, right), matching: glow), findsOneWidget);

    // لمس الكلمة المضيئة يضعها ويطفئ التلميح ويصفّر العدّاد.
    await tester.tap(_tileFinder(0, right));
    await settle(tester);
    expect(container.read(sessionControllerProvider(_id)).placedTiles, <int>[right]);
    expect(container.read(sessionControllerProvider(_id)).mistakeStreak, 0);
    expect(glow, findsNothing);

    // «متتالية»: خطآن ثم كلمة صحيحة تُصفّر العدّاد، فخطأ بعدها لا يُضيء شيئاً.
    // المقطع قصير (٣ كلمات): يُتراجع عن الصحيحة كي يبقى خطأ ممكناً في الموضع نفسه.
    await tapWrong();
    await tapWrong();
    expect(container.read(sessionControllerProvider(_id)).mistakeStreak, 2);
    await tester.tap(_tileFinder(0, _tile(container, drill, 1, matching: true)));
    await settle(tester);
    expect(container.read(sessionControllerProvider(_id)).mistakeStreak, 0);
    controller.undoTile();
    await settle(tester);
    expect(container.read(sessionControllerProvider(_id)).placedTiles, <int>[right]);
    await tapWrong();
    expect(container.read(sessionControllerProvider(_id)).mistakeStreak, 1);
    expect(glow, findsNothing);

    // البدء من جديد والتراجع يصفّران العدّاد.
    await tapWrong();
    await tapWrong();
    expect(glow, findsOneWidget);
    controller.undoTile();
    await settle(tester);
    expect(container.read(sessionControllerProvider(_id)).mistakeStreak, 0);
    expect(glow, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a hint never changes what completes a drill, and solving after it works as before', (WidgetTester tester) async {
    _recordHaptics(tester);
    final ProviderContainer container = await _openSession(tester);
    final SessionController controller = container.read(sessionControllerProvider(_id).notifier);
    final PracticeEngine engine = container.read(practiceEngineProvider(_id))!;
    final ChunkDrill drill = engine.drills.first;
    controller.goTo(SessionStage.practice);
    await settle(tester);

    for (int i = 0; i < hintAfterMistakes; i++) {
      controller.placeTile(_tile(container, drill, 0, matching: false));
    }
    await settle(tester);
    expect(find.byKey(const ValueKey<String>('hint-glow')), findsOneWidget);

    // الحل الكامل بعد التلميح يعمل كما هو، ويطفئ التلميح.
    _solveCurrent(container, drill);
    await settle(tester);
    expect(controller.currentDrillMatches, isTrue);
    expect(find.byKey(const ValueKey<String>('hint-glow')), findsNothing);
    expect(_button(tester, 'practice-next').onPressed, isNotNull);
  });
}
