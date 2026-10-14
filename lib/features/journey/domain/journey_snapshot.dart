// لقطة مسار الأربعين: حساب صرف (بلا واجهة ولا تخزين) لحالة كل وِرد على
// المسار، وموضع القافلة، ووِرد اليوم، ونسبة التقدم، ووقت الفتح القادم.
//
// المسار مخصص لأوراد الأحاديث النبوية وحدها: كل عقدة حديث من الكتاب برقمه،
// ولا صلة له بمحطات السيرة ولا بحواضر الرواية؛ فتلك لها رحلتها المستقلة.
//
// القواعد:
// - العقدة مكتملة إذا أُتمّ وِردها، ونشطة إذا كانت وِرد اليوم المتاح.
// - إذا بلغ المستخدم حصة اليوم بقيت القافلة عند آخر وِرد أتمّه، ويُقفل
//   الوِرد التالي حتى الفجر (ما لم يُتخطَّ القفل يدوياً لأغراض التجربة).
// - الأحاديث التي لم يكتمل إعدادها ومراجعتها تظهر مقفلة «قيد الإعداد» بلا
//   عنوان، فلا يُنسب إليها نص لم يُوثَّق بعد.

import 'package:flutter/foundation.dart';

import '../../../core/text/arabic_digits.dart';
import '../../hadith/data/models/models.dart';
import 'journey_progress.dart';
import 'pacing.dart';

/// حالة عقدة الوِرد.
enum WirdNodeStatus {
  /// أُتمّ وِردها.
  completed,

  /// وِرد اليوم المتاح.
  today,

  /// الوِرد التالي، مقفل حتى الفجر لبلوغ حصة اليوم.
  afterDawn,

  /// مُعدّ، وينتظر ما قبله.
  upcoming,

  /// لم يكتمل إعداده ومراجعته بعد.
  inPreparation,
}

/// حالة وِرد اليوم.
enum TodayKind {
  /// وِرد اليوم متاح.
  available,

  /// بلغ المستخدم حصة اليوم؛ يُفتح الجديد عند الفجر.
  capReached,

  /// أتمّ كل الأوراد المُعدّة في هذا الإصدار.
  curriculumFinished,
}

/// عقدة على المسار: حديث واحد برقمه في الكتاب.
@immutable
class WirdNode {
  const WirdNode({
    required this.index,
    required this.number,
    required this.item,
    required this.status,
    required this.segmentIndex,
  });

  /// موضع العقدة في المسار (من صفر).
  final int index;

  /// رقم الحديث في الكتاب.
  final int number;

  /// عنصر المنهج، أو null إن لم يُعدّ الحديث بعد.
  final CurriculumItem? item;

  /// الحالة.
  final WirdNodeStatus status;

  /// المجموعة التي تنتمي إليها العقدة.
  final int segmentIndex;

  /// هل الحديث مُعدّ.
  bool get prepared => item != null;
}

/// مجموعة من عشرة أحاديث على المسار.
@immutable
class PathSegment {
  const PathSegment({
    required this.index,
    required this.title,
    required this.firstNumber,
    required this.lastNumber,
    required this.firstNodeIndex,
    required this.completed,
    required this.total,
    this.subtitle,
  });

  /// رقم المجموعة (من صفر).
  final int index;

  /// العنوان، مثل «العشرة الأولى».
  final String title;

  /// رقم أول حديث.
  final int firstNumber;

  /// رقم آخر حديث.
  final int lastNumber;

  /// موضع أول عقدة في المسار.
  final int firstNodeIndex;

  /// الأوراد المكتملة فيها.
  final int completed;

  /// عدد أحاديثها.
  final int total;

  /// عنوان فرعي يُظهر تمايز الأقسام إن جمعت المجموعة أحاديث من قسمين، مثل
  /// «خاتمة الأربعين النووية وتتمة الخمسين الرجبية»؛ وإلا null.
  final String? subtitle;

  /// العنوان الكامل: «العشرة الخامسة — خاتمة الأربعين النووية وتتمة الخمسين الرجبية».
  String get fullTitle => subtitle == null ? title : '$title — $subtitle';

  /// نطاق الأرقام بالأرقام العربية.
  String get rangeLabel => 'الأحاديث ${arabicDigits(firstNumber)}–${arabicDigits(lastNumber)}';

  /// نسبة الإتمام.
  double get fraction => total == 0 ? 0 : completed / total;
}

/// فاصل بارز بين قسمين متتاليين من الكتاب على المسار، يقع بصرياً قبل أول عقدة
/// من القسم التالي (بين الحديث ٤٢ والحديث ٤٣ في المنهج الحالي).
@immutable
class SectionDivider {
  const SectionDivider({
    required this.index,
    required this.ending,
    required this.starting,
    required this.beforeNodeIndex,
  });

  /// رقم الفاصل (من صفر).
  final int index;

  /// القسم الذي ينتهي عند الفاصل.
  final CurriculumSection ending;

  /// القسم الذي يبدأ بعد الفاصل.
  final CurriculumSection starting;

  /// موضع أول عقدة من القسم الجديد؛ يقع الفاصل قبلها مباشرة.
  final int beforeNodeIndex;

  /// نص انتهاء القسم: «الأربعون النووية — للإمام يحيى بن شرف النووي (الأحاديث ١–٤٢)».
  String get endingLine => _line(ending, withDescription: false);

  /// نص بدء القسم: «تتمة الخمسين الرجبية — للحافظ ابن رجب الحنبلي (الأحاديث ٤٣–٥٠: …)».
  String get startingLine => _line(starting, withDescription: true);

  static String _line(CurriculumSection section, {required bool withDescription}) {
    final String range = 'الأحاديث ${arabicDigits(section.firstNumber)}–${arabicDigits(section.lastNumber)}';
    final String? description = section.description;
    final String inside = withDescription && description != null ? '$range: $description' : range;
    return '${section.title} — ${section.author} ($inside)';
  }
}

/// لقطة المسار.
@immutable
class JourneySnapshot {
  const JourneySnapshot._({
    required this.curriculum,
    required this.progress,
    required this.pacing,
    required this.computedAt,
    required this.nodes,
    required this.segments,
    required this.caravanIndex,
    required this.todayKind,
    required this.nextItem,
    required this.completedCount,
    required this.dividers,
  });

  /// عدد الأحاديث في المجموعة الواحدة على المسار.
  static const int segmentSize = 10;

  /// يحسب اللقطة.
  factory JourneySnapshot.compute({
    required CurriculumManifest curriculum,
    required JourneyProgress progress,
    required PacingState pacing,
    required DateTime now,
  }) {
    final List<CurriculumItem> items = curriculum.items;
    final Map<int, CurriculumItem> byNumber = <int, CurriculumItem>{
      for (final CurriculumItem item in items) item.number: item,
    };
    int planned = curriculum.plannedCount;
    for (final CurriculumItem item in items) {
      if (item.number > planned) {
        planned = item.number;
      }
    }

    CurriculumItem? nextItem;
    for (final CurriculumItem item in items) {
      if (!progress.isCompleted(item.hadithId)) {
        nextItem = item;
        break;
      }
    }

    CurriculumItem? lastCompleted;
    for (int i = progress.completed.length - 1; i >= 0 && lastCompleted == null; i--) {
      final String id = progress.completed[i].hadithId;
      for (final CurriculumItem item in items) {
        if (item.hadithId == id) {
          lastCompleted = item;
          break;
        }
      }
    }

    final TodayKind todayKind;
    if (nextItem == null) {
      todayKind = TodayKind.curriculumFinished;
    } else if (pacing.locked) {
      todayKind = TodayKind.capReached;
    } else {
      todayKind = TodayKind.available;
    }

    final List<WirdNode> nodes = <WirdNode>[];
    int completedCount = 0;
    for (int number = 1; number <= planned; number++) {
      final CurriculumItem? item = byNumber[number];
      final WirdNodeStatus status;
      if (item == null) {
        status = WirdNodeStatus.inPreparation;
      } else if (progress.isCompleted(item.hadithId)) {
        status = WirdNodeStatus.completed;
        completedCount++;
      } else if (identical(item, nextItem)) {
        status = todayKind == TodayKind.capReached ? WirdNodeStatus.afterDawn : WirdNodeStatus.today;
      } else {
        status = WirdNodeStatus.upcoming;
      }
      nodes.add(
        WirdNode(
          index: number - 1,
          number: number,
          item: item,
          status: status,
          segmentIndex: (number - 1) ~/ segmentSize,
        ),
      );
    }

    final List<PathSegment> segments = <PathSegment>[];
    for (int first = 1; first <= planned; first += segmentSize) {
      final int last = first + segmentSize - 1 > planned ? planned : first + segmentSize - 1;
      final int segmentIndex = (first - 1) ~/ segmentSize;
      int done = 0;
      for (int number = first; number <= last; number++) {
        if (nodes[number - 1].status == WirdNodeStatus.completed) {
          done++;
        }
      }
      // مجموعة تجمع حديثين من قسمين تُعنوَن بتمايز القسمين، لا بترتيبها وحده.
      final List<String> labels = <String>[];
      for (int number = first; number <= last; number++) {
        final String? label = curriculum.sectionOf(number)?.segmentLabel;
        if (label != null && !labels.contains(label)) {
          labels.add(label);
        }
      }
      segments.add(
        PathSegment(
          index: segmentIndex,
          title: segmentTitle(segmentIndex, isTail: last - first + 1 < segmentSize && segmentIndex > 0),
          subtitle: labels.length > 1 ? labels.join(' و') : null,
          firstNumber: first,
          lastNumber: last,
          firstNodeIndex: first - 1,
          completed: done,
          total: last - first + 1,
        ),
      );
    }

    // فاصل بين كل قسمين متتاليين، قبل أول عقدة من اللاحق منهما.
    final List<CurriculumSection> sections = curriculum.sections ?? const <CurriculumSection>[];
    final List<SectionDivider> dividers = <SectionDivider>[];
    for (int i = 0; i + 1 < sections.length; i++) {
      final int before = sections[i + 1].firstNumber - 1;
      if (before > 0 && before < nodes.length) {
        dividers.add(
          SectionDivider(index: i, ending: sections[i], starting: sections[i + 1], beforeNodeIndex: before),
        );
      }
    }

    int indexOf(CurriculumItem? item) => item == null ? 0 : item.number - 1;
    final int caravanIndex;
    switch (todayKind) {
      case TodayKind.available:
        caravanIndex = indexOf(nextItem);
      case TodayKind.capReached:
        caravanIndex = lastCompleted == null ? indexOf(nextItem) : indexOf(lastCompleted);
      case TodayKind.curriculumFinished:
        caravanIndex = indexOf(lastCompleted);
    }

    return JourneySnapshot._(
      curriculum: curriculum,
      progress: progress,
      pacing: pacing,
      computedAt: now,
      nodes: List<WirdNode>.unmodifiable(nodes),
      segments: List<PathSegment>.unmodifiable(segments),
      caravanIndex: _bounded(caravanIndex, nodes.length),
      todayKind: todayKind,
      nextItem: nextItem,
      completedCount: completedCount,
      dividers: List<SectionDivider>.unmodifiable(dividers),
    );
  }

  static int _bounded(int index, int length) {
    if (length == 0 || index < 0) {
      return 0;
    }
    return index >= length ? length - 1 : index;
  }

  /// عنوان المجموعة: «العشرة الأولى» … والأخيرة الناقصة «تتمة الأربعين».
  static String segmentTitle(int index, {required bool isTail}) {
    if (isTail) {
      return 'تتمة الأربعين';
    }
    const List<String> ordinals = <String>[
      'الأولى',
      'الثانية',
      'الثالثة',
      'الرابعة',
      'الخامسة',
      'السادسة',
      'السابعة',
      'الثامنة',
      'التاسعة',
      'العاشرة',
    ];
    if (index < ordinals.length) {
      return 'العشرة ${ordinals[index]}';
    }
    return 'المجموعة ${arabicDigits(index + 1)}';
  }

  /// المنهج.
  final CurriculumManifest curriculum;

  /// التقدم.
  final JourneyProgress progress;

  /// الوتيرة.
  final PacingState pacing;

  /// لحظة الحساب.
  final DateTime computedAt;

  /// العقد بترتيب الأرقام.
  final List<WirdNode> nodes;

  /// المجموعات.
  final List<PathSegment> segments;

  /// موضع القافلة.
  final int caravanIndex;

  /// حالة وِرد اليوم.
  final TodayKind todayKind;

  /// الوِرد التالي في المنهج، أو null إن اكتملت الأوراد المعدّة.
  final CurriculumItem? nextItem;

  /// عدد الأوراد المكتملة.
  final int completedCount;

  /// الفواصل بين أقسام الكتاب (فارغة إن لم تُعرَّف أقسام).
  final List<SectionDivider> dividers;

  /// العقدة التي تقف عندها القافلة.
  WirdNode get caravanNode => nodes[caravanIndex];

  /// عدد أحاديث الكتاب على المسار.
  int get plannedCount => nodes.length;

  /// عدد الأحاديث المعدّة في هذا الإصدار.
  int get preparedCount => curriculum.items.length;

  /// نسبة التقدم في الكتاب كله.
  double get progressFraction => nodes.isEmpty ? 0 : completedCount / nodes.length;

  /// وقت فتح الوِرد التالي عند بلوغ الحصة، وإلا null.
  DateTime? get nextUnlockAt => todayKind == TodayKind.capReached ? pacing.nextUnlockAt : null;

  /// هل وقت الفتح هو الوقت الاحتياطي في المنهج.
  bool get unlockUsesFallback => pacing.usesFallbackTime;

  /// العقدة بموضعها.
  WirdNode nodeAt(int index) => nodes[index];
}
