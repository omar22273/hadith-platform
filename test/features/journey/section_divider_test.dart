// اختبارات فاصل الأقسام على مسار المتون: بيانات الأقسام في المنهج متصلة وكاملة،
// وهندسة المسار تحجز للفاصل موضعه بين الحديثين ٤٢ و٤٣، وبطاقة الفاصل تعرض نصّي
// القسمين حرفياً، والشريحة الخامسة تحمل عنواناً فرعياً يُظهر التمايز.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/features/hadith/data/models/models.dart';
import 'package:hadith_platform/features/journey/domain/journey_progress.dart';
import 'package:hadith_platform/features/journey/domain/journey_snapshot.dart';
import 'package:hadith_platform/features/journey/domain/pacing.dart';
import 'package:hadith_platform/features/journey/domain/unlock_schedule.dart';
import 'package:hadith_platform/features/journey/presentation/widgets/section_divider_banner.dart';
import 'package:hadith_platform/features/journey/presentation/widgets/trail_geometry.dart';
import 'package:hadith_platform/features/journey/presentation/widgets/wird_node.dart';

import '../../support/app_harness.dart';

const String _endingLine = 'الأربعون النووية — للإمام يحيى بن شرف النووي (الأحاديث ١–٤٢)';
const String _startingLine = 'تتمة الخمسين الرجبية — للحافظ ابن رجب الحنبلي '
    '(الأحاديث ٤٣–٥٠: ثمانية أحاديث جوامع ألحقها لإتمام قواعد الدين إلى خمسين حديثاً)';
const String _fifthSubtitle = 'خاتمة الأربعين النووية وتتمة الخمسين الرجبية';

JsonMap _load(String path) => asJsonMap(jsonDecode(File(path).readAsStringSync()), path);

void main() {
  final CurriculumManifest curriculum =
      CurriculumManifest.fromJson(_load('assets/data/curriculum/nawawi40_curriculum.json'));

  JourneySnapshot snapshot() {
    final DateTime now = DateTime(2026, 10, 9, 10);
    final UnlockSchedule schedule = UnlockSchedule.fromPolicy(curriculum.dailyCap);
    return JourneySnapshot.compute(
      curriculum: curriculum,
      progress: JourneyProgress.empty,
      pacing: PacingState.compute(
        settings: PacingSettings.initial,
        completions: JourneyProgress.empty.completionTimes,
        schedule: schedule,
        now: now,
      ),
      now: now,
    );
  }

  group('the curriculum sections', () {
    test('are two contiguous sections that cover every one of the fifty hadiths exactly once', () {
      final List<CurriculumSection> sections = curriculum.sections!;
      expect(sections, hasLength(2));
      expect(sections.first.firstNumber, 1);
      for (int i = 1; i < sections.length; i++) {
        expect(sections[i].firstNumber, sections[i - 1].lastNumber + 1, reason: 'no gap and no overlap at $i');
      }
      expect(sections.last.lastNumber, curriculum.plannedCount);
      for (final CurriculumItem item in curriculum.items) {
        expect(curriculum.sectionOf(item.number), isNotNull, reason: 'hadith ${item.number}');
      }
      expect(curriculum.sectionOf(42)!.id, 'arbaun_nawawiyya');
      expect(curriculum.sectionOf(43)!.id, 'rajab_fifty_completion');
      expect(curriculum.sectionOf(51), isNull);
    });

    test('name the two books and their authors as the product owner worded them', () {
      final CurriculumSection first = curriculum.sections![0];
      final CurriculumSection second = curriculum.sections![1];
      expect(first.title, 'الأربعون النووية');
      expect(first.author, 'للإمام يحيى بن شرف النووي');
      expect((first.firstNumber, first.lastNumber), (1, 42));
      expect(first.description, isNull);
      expect(second.title, 'تتمة الخمسين الرجبية');
      expect(second.author, 'للحافظ ابن رجب الحنبلي');
      expect((second.firstNumber, second.lastNumber), (43, 50));
      expect(second.description, 'ثمانية أحاديث جوامع ألحقها لإتمام قواعد الدين إلى خمسين حديثاً');
    });

    test('round-trip through JSON without losing a field, and stay optional for older files', () {
      expect(CurriculumManifest.fromJson(curriculum.toJson()), curriculum);
      final Map<String, dynamic> legacy = <String, dynamic>{...curriculum.toJson()}..remove('sections');
      final CurriculumManifest old = CurriculumManifest.fromJson(legacy);
      expect(old.sections, isNull);
      expect(old.sectionOf(5), isNull);
    });
  });

  group('the snapshot', () {
    test('has exactly one divider, placed before hadith 43, with the two owner lines verbatim', () {
      final JourneySnapshot snap = snapshot();
      expect(snap.dividers, hasLength(1));
      final SectionDivider divider = snap.dividers.single;
      expect(divider.beforeNodeIndex, 42, reason: 'zero-based index of hadith 43');
      expect(snap.nodes[divider.beforeNodeIndex].number, 43);
      expect(snap.nodes[divider.beforeNodeIndex - 1].number, 42);
      expect(divider.endingLine, _endingLine);
      expect(divider.startingLine, _startingLine);
    });

    test('the fifth slice (41–50) is the only one that carries a distinguishing subtitle', () {
      final JourneySnapshot snap = snapshot();
      expect(snap.segments, hasLength(5));
      for (int i = 0; i < 4; i++) {
        expect(snap.segments[i].subtitle, isNull, reason: snap.segments[i].title);
      }
      final PathSegment fifth = snap.segments[4];
      expect((fifth.firstNumber, fifth.lastNumber), (41, 50));
      expect(fifth.title, 'العشرة الخامسة');
      expect(fifth.subtitle, _fifthSubtitle);
      expect(fifth.fullTitle, 'العشرة الخامسة — $_fifthSubtitle');
    });
  });

  group('the trail geometry', () {
    test('reserves a full-width slot for the divider between the two stations, and pushes the rest down', () {
      final List<int> groups = <int>[for (int k = 0; k < 50; k++) k ~/ 10];
      final TrailLayout plain = TrailLayout.compute(width: 400, textScale: 1, groupOfNode: groups);
      final TrailLayout withDivider = TrailLayout.compute(
        width: 400,
        textScale: 1,
        groupOfNode: groups,
        dividers: const <TrailDividerSpec>[TrailDividerSpec(dividerIndex: 0, beforeNodeIndex: 42, height: 280)],
        tallHeaderGroups: const <int>{4},
      );
      expect(withDivider.dividers, hasLength(1));
      final Rect slot = withDivider.dividers.single.rect;
      expect(slot.left, 16);
      expect(slot.width, 400 - 32);
      expect(slot.height, 280);
      // يقع بعد صف الحديث ٤٢ تماماً وقبل صف الحديث ٤٣.
      expect(slot.top, greaterThanOrEqualTo(withDivider.rowTops[41] + withDivider.rowHeight));
      expect(slot.bottom, lessThanOrEqualTo(withDivider.rowTops[42]));
      // ما قبله لا يتحرك إلا بزيادة رأس الشريحة الخامسة، وما بعده ينزل بارتفاع الفاصل.
      expect(withDivider.rowTops[10], plain.rowTops[10]);
      final double extraHeader = withDivider.headers[4].rect.height - plain.headers[4].rect.height;
      expect(extraHeader, greaterThan(0));
      expect(withDivider.rowTops[49] - plain.rowTops[49], closeTo(280 + 6 + extraHeader, 0.001));
      // لا فاصل في المسار العادي.
      expect(plain.dividers, isEmpty);
    });

    test('the divider height estimate grows with a narrower path and with larger text', () {
      final SectionDivider divider = snapshot().dividers.single;
      final double wide = SectionDividerBanner.estimateHeight(divider: divider, width: 600, textScale: 1);
      final double narrow = SectionDividerBanner.estimateHeight(divider: divider, width: 340, textScale: 1);
      final double narrowLarge = SectionDividerBanner.estimateHeight(divider: divider, width: 340, textScale: 1.3);
      expect(narrow, greaterThan(wide));
      expect(narrowLarge, greaterThan(narrow));
    });
  });

  group('the path screen', () {
    Finder divider() => find.byKey(const ValueKey<String>('section-divider-0'));

    testWidgets('shows the divider banner between station 42 and station 43 with both owner lines',
        (WidgetTester tester) async {
      await pumpApp(tester);
      await tester.ensureVisible(divider());
      await settle(tester);
      expect(divider(), findsOneWidget);
      expect(find.byType(SectionDividerBanner), findsOneWidget);

      expect(find.text(_endingLine), findsOneWidget);
      expect(find.text(_startingLine), findsOneWidget);
      expect(find.text('نهاية القسم الأول'), findsOneWidget);
      expect(find.text('بداية القسم الثاني'), findsOneWidget);

      final Rect banner = tester.getRect(divider());
      final Rect before = tester.getRect(find.byType(WirdNodeView).at(41));
      final Rect after = tester.getRect(find.byType(WirdNodeView).at(42));
      expect(banner.top, greaterThanOrEqualTo(before.bottom - 0.5), reason: 'below station 42');
      expect(banner.bottom, lessThanOrEqualTo(after.top + 0.5), reason: 'above station 43');
      expect(banner.width, greaterThan(300), reason: 'a prominent full-width banner');
    });

    testWidgets('the banner is a smooth squircle surface, not a plain box', (WidgetTester tester) async {
      await pumpApp(tester);
      await tester.ensureVisible(divider());
      final Iterable<DecoratedBox> boxes = tester.widgetList<DecoratedBox>(
        find.descendant(of: divider(), matching: find.byType(DecoratedBox)),
      );
      expect(
        boxes.any((DecoratedBox b) => b.decoration is ShapeDecoration && (b.decoration as ShapeDecoration).gradient != null),
        isTrue,
      );
    });

    testWidgets('the fifth slice header carries the distinguishing subtitle', (WidgetTester tester) async {
      await pumpApp(tester);
      final Finder subtitle = find.byKey(const ValueKey<String>('segment-subtitle-4'));
      await tester.ensureVisible(subtitle);
      expect(tester.widget<Text>(subtitle).data, _fifthSubtitle);
      for (int i = 0; i < 4; i++) {
        expect(find.byKey(ValueKey<String>('segment-subtitle-$i')), findsNothing);
      }
    });

    testWidgets('a narrow phone with the largest fonts shows the banner inside the screen without overflow',
        (WidgetTester tester) async {
      await pumpApp(tester, size: const Size(360, 740), systemTextScale: 1.3);
      await tester.ensureVisible(divider());
      await settle(tester);
      expect(tester.takeException(), isNull);
      final Rect banner = tester.getRect(divider());
      expect(banner.left, greaterThanOrEqualTo(0));
      expect(banner.right, lessThanOrEqualTo(360));
      expect(find.text(_startingLine), findsOneWidget);
    });
  });
}
