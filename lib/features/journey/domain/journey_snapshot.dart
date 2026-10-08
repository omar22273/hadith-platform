// لقطة مسار القوافل: حساب صرف (بلا واجهة ولا تخزين) لحالة كل محطة،
// وموضع القافلة، ووِرد اليوم، ونسبة التقدم، ووقت الفتح القادم.
//
// القواعد:
// - المحطة مكتملة إذا اكتملت كل أورادها في المنهج.
// - المحطة النشطة هي محطة الوِرد التالي، ما دام وِردها متاحاً أو كانت القافلة فيها.
// - إذا اكتمل وِرد اليوم وكان الوِرد التالي في محطة جديدة، تبقى القافلة في
//   محطتها وتُقفل المحطة الجديدة قفلاً زمنياً حتى الفجر، ثم تسير إليها.
// - المحطات التي لم تُربط بها أوراد في المنهج بعد تبقى مقفلة بسبب ذلك.

import 'package:flutter/foundation.dart';

import '../../hadith/data/models/models.dart';
import 'journey_progress.dart';
import 'unlock_schedule.dart';

/// حالة المحطة.
enum StationStatus {
  /// اكتملت أورادها (زمردية مع علامة الإنجاز).
  completed,

  /// محطة وِرد اليوم (توهج كهرماني مع مجسم القافلة).
  active,

  /// مقفلة حتى يحين وِردها (رمادية مع قفل زمني).
  locked,
}

/// سبب القفل.
enum StationLockReason {
  /// تسبقها محطة لم تكتمل.
  awaitingPrevious,

  /// وِردها التالي يُفتح عند الفجر.
  awaitingDawn,

  /// لم تُربط بها أوراد في نسخة المنهج الحالية.
  notInCurriculumYet,
}

/// حالة الوِرد داخل المحطة.
enum WirdStatus {
  /// مكتمل.
  completed,

  /// وِرد اليوم المتاح الآن.
  today,

  /// الوِرد التالي، يُفتح عند الفجر.
  afterDawn,

  /// وِرد قادم.
  upcoming,
}

/// حالة وِرد اليوم.
enum TodayKind {
  /// الوِرد متاح.
  available,

  /// اكتمل وِرد اليوم، والتالي يُفتح عند الفجر.
  capReached,

  /// اكتملت الأوراد المتاحة في المنهج كله.
  curriculumFinished,
}

/// وِرد في محطة.
@immutable
class StationWird {
  const StationWird({
    required this.item,
    required this.dayNumber,
    required this.status,
  });

  /// عنصر المنهج.
  final CurriculumItem item;

  /// رقم اليوم في الرحلة.
  final int dayNumber;

  /// الحالة.
  final WirdStatus status;
}

/// محطة بحالتها.
@immutable
class StationView {
  const StationView({
    required this.station,
    required this.region,
    required this.index,
    required this.status,
    required this.lockReason,
    required this.wirds,
    required this.isCaravanHere,
  });

  /// المحطة من الفهرس.
  final JourneyStation station;

  /// مرحلتها.
  final JourneyRegion region;

  /// موضعها في المسار (يبدأ من صفر).
  final int index;

  /// حالتها.
  final StationStatus status;

  /// سبب القفل إن كانت مقفلة.
  final StationLockReason? lockReason;

  /// أورادها في المنهج.
  final List<StationWird> wirds;

  /// هل القافلة فيها الآن.
  final bool isCaravanHere;

  /// أول يوم من أيامها.
  int? get firstDay => wirds.isEmpty ? null : wirds.first.dayNumber;

  /// آخر يوم من أيامها.
  int? get lastDay => wirds.isEmpty ? null : wirds.last.dayNumber;

  /// عدد أورادها المكتملة.
  int get completedCount {
    return wirds.where((StationWird wird) => wird.status == WirdStatus.completed).length;
  }
}

/// لقطة المسار.
@immutable
class JourneySnapshot {
  const JourneySnapshot._({
    required this.catalog,
    required this.curriculum,
    required this.progress,
    required this.schedule,
    required this.computedAt,
    required this.stations,
    required this.caravanIndex,
    required this.todayKind,
    required this.nextItem,
    required this.nextDayNumber,
    required this.nextUnlockAt,
    required this.progressFraction,
  });

  /// يحسب اللقطة.
  factory JourneySnapshot.compute({
    required JourneyCatalog catalog,
    required CurriculumManifest curriculum,
    required JourneyProgress progress,
    required UnlockSchedule schedule,
    required DateTime now,
  }) {
    final List<JourneyStation> ordered = List<JourneyStation>.of(catalog.stations)
      ..sort((JourneyStation a, JourneyStation b) => a.order.compareTo(b.order));
    final List<CurriculumItem> items = curriculum.items;
    final int perDay = schedule.newHadithPerDay < 1 ? 1 : schedule.newHadithPerDay;
    int dayOf(int itemIndex) => itemIndex ~/ perDay + 1;

    int? nextIndex;
    for (int i = 0; i < items.length; i++) {
      if (!progress.isCompleted(items[i].hadithId)) {
        nextIndex = i;
        break;
      }
    }

    CurriculumItem? lastCompletedItem;
    for (int i = progress.completed.length - 1; i >= 0 && lastCompletedItem == null; i--) {
      final String id = progress.completed[i].hadithId;
      for (final CurriculumItem item in items) {
        if (item.hadithId == id) {
          lastCompletedItem = item;
          break;
        }
      }
    }

    final bool capReached = schedule.capReached(progress.completionTimes, now);
    final TodayKind todayKind;
    if (nextIndex == null) {
      todayKind = TodayKind.curriculumFinished;
    } else if (capReached) {
      todayKind = TodayKind.capReached;
    } else {
      todayKind = TodayKind.available;
    }
    final CurriculumItem? nextItem = nextIndex == null ? null : items[nextIndex];
    final DateTime? nextUnlockAt =
        todayKind == TodayKind.capReached ? schedule.nextUnlockAfter(now) : null;

    // موضع القافلة والمحطة النشطة.
    String? activeStationId;
    String caravanStationId;
    String? dawnLockedStationId;
    if (nextItem == null) {
      caravanStationId = lastCompletedItem?.stationId ?? ordered.first.id;
    } else if (todayKind == TodayKind.capReached &&
        lastCompletedItem != null &&
        lastCompletedItem.stationId != nextItem.stationId) {
      caravanStationId = lastCompletedItem.stationId;
      dawnLockedStationId = nextItem.stationId;
    } else {
      activeStationId = nextItem.stationId;
      caravanStationId = nextItem.stationId;
    }
    int caravanIndex = 0;
    for (int k = 0; k < ordered.length; k++) {
      if (ordered[k].id == caravanStationId) {
        caravanIndex = k;
        break;
      }
    }
    final int caravanOrder = ordered[caravanIndex].order;

    final List<StationView> views = <StationView>[];
    double progressSum = 0;
    for (int k = 0; k < ordered.length; k++) {
      final JourneyStation station = ordered[k];
      final List<StationWird> wirds = <StationWird>[];
      for (int i = 0; i < items.length; i++) {
        if (items[i].stationId != station.id) {
          continue;
        }
        final WirdStatus status;
        if (progress.isCompleted(items[i].hadithId)) {
          status = WirdStatus.completed;
        } else if (i == nextIndex) {
          status = todayKind == TodayKind.capReached ? WirdStatus.afterDawn : WirdStatus.today;
        } else {
          status = WirdStatus.upcoming;
        }
        wirds.add(StationWird(item: items[i], dayNumber: dayOf(i), status: status));
      }
      final int done = wirds.where((StationWird w) => w.status == WirdStatus.completed).length;
      if (wirds.isNotEmpty) {
        progressSum += done / wirds.length;
      }

      final StationStatus status;
      StationLockReason? lockReason;
      if (wirds.isNotEmpty && done == wirds.length) {
        status = StationStatus.completed;
      } else if (station.id == activeStationId) {
        status = StationStatus.active;
      } else if (station.order < caravanOrder) {
        status = StationStatus.completed;
      } else {
        status = StationStatus.locked;
        if (station.id == dawnLockedStationId) {
          lockReason = StationLockReason.awaitingDawn;
        } else if (wirds.isEmpty) {
          lockReason = StationLockReason.notInCurriculumYet;
        } else {
          lockReason = StationLockReason.awaitingPrevious;
        }
      }
      final JourneyRegion region = catalog.regionById(station.regionId) ??
          JourneyRegion(id: station.regionId, order: 0, name: station.regionId, theme: '');
      views.add(
        StationView(
          station: station,
          region: region,
          index: k,
          status: status,
          lockReason: lockReason,
          wirds: List<StationWird>.unmodifiable(wirds),
          isCaravanHere: k == caravanIndex,
        ),
      );
    }

    return JourneySnapshot._(
      catalog: catalog,
      curriculum: curriculum,
      progress: progress,
      schedule: schedule,
      computedAt: now,
      stations: List<StationView>.unmodifiable(views),
      caravanIndex: caravanIndex,
      todayKind: todayKind,
      nextItem: nextItem,
      nextDayNumber: nextIndex == null ? null : dayOf(nextIndex),
      nextUnlockAt: nextUnlockAt,
      progressFraction: ordered.isEmpty ? 0 : progressSum / ordered.length,
    );
  }

  /// فهرس المسار.
  final JourneyCatalog catalog;

  /// المنهج.
  final CurriculumManifest curriculum;

  /// التقدم.
  final JourneyProgress progress;

  /// جدول الفتح.
  final UnlockSchedule schedule;

  /// وقت الحساب.
  final DateTime computedAt;

  /// المحطات مرتبة.
  final List<StationView> stations;

  /// موضع القافلة.
  final int caravanIndex;

  /// حالة وِرد اليوم.
  final TodayKind todayKind;

  /// الوِرد التالي غير المكتمل (متاح اليوم أو بعد الفجر).
  final CurriculumItem? nextItem;

  /// رقم يوم الوِرد التالي.
  final int? nextDayNumber;

  /// وقت فتح الوِرد التالي إن كان مقفلاً.
  final DateTime? nextUnlockAt;

  /// نسبة التقدم في المسار كله (0 - 1).
  final double progressFraction;

  /// المحطة التي فيها القافلة.
  StationView get caravanStation => stations[caravanIndex];

  /// المحطة النشطة إن وجدت.
  StationView? get activeStation {
    for (final StationView view in stations) {
      if (view.status == StationStatus.active) {
        return view;
      }
    }
    return null;
  }

  /// آخر وِرد مكتمل.
  CompletedWird? get lastCompletion {
    return progress.completed.isEmpty ? null : progress.completed.last;
  }

  /// هل يُعتمد الوقت الاحتياطي للفتح القادم.
  bool get unlockUsesFallback {
    final DateTime? at = nextUnlockAt;
    return at == null || schedule.usesFallbackOn(at);
  }
}
