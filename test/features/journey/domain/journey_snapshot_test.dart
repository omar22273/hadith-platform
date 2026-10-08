// اختبارات لقطة المسار وجدول الفتح: حالات المحطات، وقفل الفجر، وسير القافلة.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/features/hadith/data/models/models.dart';
import 'package:hadith_platform/features/journey/domain/journey_progress.dart';
import 'package:hadith_platform/features/journey/domain/journey_snapshot.dart';
import 'package:hadith_platform/features/journey/domain/unlock_schedule.dart';

JsonMap _load(String path) => asJsonMap(jsonDecode(File(path).readAsStringSync()), path);

void main() {
  final JourneyCatalog catalog =
      JourneyCatalog.fromJson(_load('assets/data/catalogs/journey_stations.json'));
  final CurriculumManifest curriculum =
      CurriculumManifest.fromJson(_load('assets/data/curriculum/nawawi40_curriculum.json'));
  final UnlockSchedule schedule = UnlockSchedule.fromPolicy(curriculum.dailyCap);

  JourneySnapshot snapshotAt(DateTime now, JourneyProgress progress, {CurriculumManifest? manifest}) {
    final CurriculumManifest used = manifest ?? curriculum;
    return JourneySnapshot.compute(
      catalog: catalog,
      curriculum: used,
      progress: progress,
      schedule: UnlockSchedule.fromPolicy(used.dailyCap),
      now: now,
    );
  }

  group('unlock schedule', () {
    test('opens at the fallback dawn time after an evening completion', () {
      expect(schedule.nextUnlockAfter(DateTime(2026, 10, 9, 21)), DateTime(2026, 10, 10, 5));
    });

    test('a completion before dawn opens the same morning', () {
      expect(schedule.nextUnlockAfter(DateTime(2026, 10, 9, 3)), DateTime(2026, 10, 9, 5));
    });

    test('exactly at dawn the next opening is the following day', () {
      expect(schedule.nextUnlockAfter(DateTime(2026, 10, 9, 5)), DateTime(2026, 10, 10, 5));
    });

    test('the current window starts at the last dawn', () {
      expect(schedule.currentWindowStart(DateTime(2026, 10, 9, 4, 59)), DateTime(2026, 10, 8, 5));
      expect(schedule.currentWindowStart(DateTime(2026, 10, 9, 5)), DateTime(2026, 10, 9, 5));
    });

    test('rejects malformed times', () {
      expect(() => LocalTime.parse('24:00'), throwsFormatException);
      expect(LocalTime.parse('05:00'), const LocalTime(5, 0));
    });
  });

  group('snapshot', () {
    test('a new traveller starts at the first station with today open', () {
      final JourneySnapshot snapshot = snapshotAt(DateTime(2026, 10, 9, 10), JourneyProgress.empty);
      expect(snapshot.todayKind, TodayKind.available);
      expect(snapshot.nextItem?.hadithId, 'nawawi40_001');
      expect(snapshot.nextDayNumber, 1);
      expect(snapshot.caravanIndex, 0);
      expect(snapshot.stations.first.status, StationStatus.active);
      expect(snapshot.stations.length, catalog.stations.length);
      for (final StationView view in snapshot.stations.skip(1)) {
        expect(view.status, StationStatus.locked);
        expect(view.lockReason, StationLockReason.notInCurriculumYet);
      }
      expect(snapshot.progressFraction, 0);
    });

    test('finishing today locks the next wird until dawn', () {
      final JourneyProgress progress =
          JourneyProgress.empty.withCompletion('nawawi40_001', DateTime(2026, 10, 9, 21));
      final JourneySnapshot snapshot = snapshotAt(DateTime(2026, 10, 9, 21, 5), progress);
      expect(snapshot.todayKind, TodayKind.capReached);
      expect(snapshot.nextUnlockAt, DateTime(2026, 10, 10, 5));
      expect(snapshot.unlockUsesFallback, isTrue);
      final StationView first = snapshot.stations.first;
      expect(first.status, StationStatus.active);
      expect(first.wirds.map((StationWird w) => w.status).toList(),
          <WirdStatus>[WirdStatus.completed, WirdStatus.afterDawn]);
      expect(snapshot.progressFraction, closeTo(0.5 / catalog.stations.length, 1e-9));
    });

    test('dawn opens the next wird', () {
      final JourneyProgress progress =
          JourneyProgress.empty.withCompletion('nawawi40_001', DateTime(2026, 10, 9, 21));
      final JourneySnapshot snapshot = snapshotAt(DateTime(2026, 10, 10, 5, 1), progress);
      expect(snapshot.todayKind, TodayKind.available);
      expect(snapshot.nextItem?.hadithId, 'nawawi40_002');
      expect(snapshot.nextDayNumber, 2);
    });

    test('completing every available wird completes the station', () {
      final JourneyProgress progress = JourneyProgress.empty
          .withCompletion('nawawi40_001', DateTime(2026, 10, 9, 21))
          .withCompletion('nawawi40_002', DateTime(2026, 10, 10, 7));
      final JourneySnapshot snapshot = snapshotAt(DateTime(2026, 10, 10, 7, 5), progress);
      expect(snapshot.todayKind, TodayKind.curriculumFinished);
      expect(snapshot.stations.first.status, StationStatus.completed);
      expect(snapshot.caravanIndex, 0);
      expect(snapshot.activeStation, isNull);
      expect(snapshot.progressFraction, closeTo(1 / catalog.stations.length, 1e-9));
    });

    test('the caravan waits for dawn before moving to a new station', () {
      final CurriculumManifest twoStations = CurriculumManifest(
        schemaVersion: '1.1.0',
        id: 'two_stations',
        title: 'اختبار',
        dailyCap: curriculum.dailyCap,
        items: const <CurriculumItem>[
          CurriculumItem(
            hadithId: 'first',
            assetPath: 'unused',
            stationId: 'makkah_dar_al_arqam',
            title: 'الأول',
          ),
          CurriculumItem(
            hadithId: 'second',
            assetPath: 'unused',
            stationId: 'makkah_bat_ha',
            title: 'الثاني',
          ),
        ],
      );
      final JourneyProgress progress =
          JourneyProgress.empty.withCompletion('first', DateTime(2026, 10, 9, 20));

      final JourneySnapshot evening =
          snapshotAt(DateTime(2026, 10, 9, 20, 30), progress, manifest: twoStations);
      expect(evening.caravanIndex, 0);
      expect(evening.stations[0].status, StationStatus.completed);
      expect(evening.stations[1].status, StationStatus.locked);
      expect(evening.stations[1].lockReason, StationLockReason.awaitingDawn);
      expect(evening.activeStation, isNull);

      final JourneySnapshot dawn =
          snapshotAt(DateTime(2026, 10, 10, 5, 0, 30), progress, manifest: twoStations);
      expect(dawn.caravanIndex, 1);
      expect(dawn.stations[1].status, StationStatus.active);
      expect(dawn.todayKind, TodayKind.available);
    });
  });

  group('progress', () {
    test('round-trips through JSON and never records a wird twice', () {
      final JourneyProgress progress = JourneyProgress.empty
          .withCompletion('nawawi40_001', DateTime(2026, 10, 9, 21))
          .withCompletion('nawawi40_001', DateTime(2026, 10, 10, 21));
      expect(progress.completed.length, 1);
      expect(JourneyProgress.fromJson(progress.toJson()), progress);
    });
  });
}
