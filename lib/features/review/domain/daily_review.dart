// سقف المراجعة اليومي: لا يُعرض للمستخدم في اليوم أكثر من اثنتي عشرة بطاقة
// مراجعة مهما تراكم ما لم يُراجَع، ولا يُعرض عليه رقم تراكمي لما فاته.
//
// الفائض لا يضيع ولا يُنبّه عليه: يبقى في السجل «لم يظهر بعد» أو «ظهر منذ
// زمن»، فيتقدم تلقائياً في حصة الأيام التالية. والترتيب:
//   ١) ما لم يظهر قط، بترتيب المنهج (أقدم الأوراد أولاً).
//   ٢) ثم الأقدم ظهوراً، فيدور الجميع دورة هادئة.
// وحصة اليوم تُجمَّد في السجل عند أول فتح، فلا تتغير بإعادة فتح الميدان.
//
// الحساب صرف (بلا واجهة ولا تخزين) ليسهل اختباره.

import 'package:flutter/foundation.dart';

import '../../../core/json/json_reader.dart';

/// الحد الأقصى لبطاقات المراجعة في اليوم الواحد.
const int dailyReviewCap = 12;

/// رقم اليوم التقويمي المحلي للحظة (أيام منذ 1970، بلا أثر لتغير التوقيت الصيفي).
int epochDayOf(DateTime moment) {
  return DateTime.utc(moment.year, moment.month, moment.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
}

/// سجل المراجعة المحفوظ على الجهاز.
@immutable
class ReviewLedger {
  const ReviewLedger({required this.day, required this.queue, required this.shown});

  /// سجل فارغ: لم تُخطَّط حصة بعد.
  static const ReviewLedger empty = ReviewLedger(
    day: -1,
    queue: <String>[],
    shown: <String, int>{},
  );

  /// يقرأ السجل من JSON.
  factory ReviewLedger.fromJson(JsonMap json) {
    final JsonMap shownJson = asJsonMap(json['shown'], 'reviewLedger.shown');
    final Map<String, int> shown = <String, int>{};
    for (final MapEntry<String, dynamic> entry in shownJson.entries) {
      final Object? value = entry.value;
      if (value is! int) {
        throw JsonParseException('Key "shown.${entry.key}" must be an integer but was ${value.runtimeType}.');
      }
      shown[entry.key] = value;
    }
    return ReviewLedger(
      day: readInt(json, 'day'),
      queue: List<String>.unmodifiable(readStringList(json, 'queue')),
      shown: Map<String, int>.unmodifiable(shown),
    );
  }

  /// اليوم الذي خُطِّطت له الحصة الحالية.
  final int day;

  /// معرّفات حصة ذلك اليوم بترتيبها.
  final List<String> queue;

  /// آخر يوم ظهرت فيه كل بطاقة.
  final Map<String, int> shown;

  /// صيغة الحفظ.
  JsonMap toJson() {
    return <String, dynamic>{
      'day': day,
      'queue': queue,
      'shown': shown,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is ReviewLedger &&
        other.day == day &&
        listEquals(other.queue, queue) &&
        mapEquals(other.shown, shown);
  }

  @override
  int get hashCode => Object.hash(day, Object.hashAll(queue), shown.length);
}

/// يخطط حصة [today] من بطاقات المراجعة [orderedIds] (بترتيب المنهج).
///
/// - إن كان السجل لليوم نفسه بقيت حصته كما هي (بعد حذف ما لم يعد موجوداً)،
///   وتُكمَّل إلى [cap] إن نقصت لأن بطاقات جديدة صارت متاحة.
/// - وإن كان ليوم آخر اختيرت [cap] بطاقة جديدة بالترتيب المذكور في أعلى الملف.
/// - ما تجاوز الحد لا يُحذف: يبقى بآخر ظهور أقدم فيتقدم لاحقاً.
ReviewLedger planReviewDay({
  required ReviewLedger ledger,
  required List<String> orderedIds,
  required int today,
  int cap = dailyReviewCap,
}) {
  assert(cap > 0, 'The daily review cap must be positive.');
  final Set<String> valid = orderedIds.toSet();
  final List<String> queue = ledger.day == today
      ? ledger.queue.where(valid.contains).take(cap).toList()
      : <String>[];
  if (queue.length < cap) {
    final Set<String> taken = queue.toSet();
    final List<int> candidates = <int>[
      for (int i = 0; i < orderedIds.length; i++)
        if (!taken.contains(orderedIds[i])) i,
    ];
    int lastShown(int index) => ledger.shown[orderedIds[index]] ?? -1;
    candidates.sort((int a, int b) {
      final int byShown = lastShown(a).compareTo(lastShown(b));
      return byShown != 0 ? byShown : a.compareTo(b);
    });
    for (final int index in candidates.take(cap - queue.length)) {
      queue.add(orderedIds[index]);
    }
    // ترتيب العرض: ترتيب المنهج لا ترتيب الأولوية.
    final Map<String, int> position = <String, int>{
      for (int i = 0; i < orderedIds.length; i++) orderedIds[i]: i,
    };
    queue.sort((String a, String b) => position[a]!.compareTo(position[b]!));
  }
  final Map<String, int> shown = <String, int>{
    for (final MapEntry<String, int> entry in ledger.shown.entries)
      if (valid.contains(entry.key)) entry.key: entry.value,
  };
  for (final String id in queue) {
    shown[id] = today;
  }
  return ReviewLedger(
    day: today,
    queue: List<String>.unmodifiable(queue),
    shown: Map<String, int>.unmodifiable(shown),
  );
}
