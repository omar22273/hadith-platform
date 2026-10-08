// تقدم المستخدم: الأوراد المكتملة وأوقات إتمامها. لا يُصفَّر التقدم ولا يُنقص.

import 'package:flutter/foundation.dart';

import '../../../core/json/json_reader.dart';

/// وِرد مكتمل.
@immutable
class CompletedWird {
  const CompletedWird({required this.hadithId, required this.completedAt});

  /// يقرأ من JSON المخزن.
  factory CompletedWird.fromJson(JsonMap json) {
    final String stamp = readString(json, 'completedAt');
    final DateTime? parsed = DateTime.tryParse(stamp);
    if (parsed == null) {
      throw JsonParseException('Invalid completedAt: "$stamp".');
    }
    return CompletedWird(
      hadithId: readString(json, 'hadithId'),
      completedAt: parsed.toLocal(),
    );
  }

  /// الحديث.
  final String hadithId;

  /// وقت الإتمام بالتوقيت المحلي.
  final DateTime completedAt;

  /// للتخزين.
  JsonMap toJson() {
    return <String, dynamic>{
      'hadithId': hadithId,
      'completedAt': completedAt.toUtc().toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is CompletedWird &&
        other.hadithId == hadithId &&
        other.completedAt == completedAt;
  }

  @override
  int get hashCode => Object.hash(hadithId, completedAt);
}

/// سجل التقدم.
@immutable
class JourneyProgress {
  const JourneyProgress({required this.completed});

  /// يقرأ من JSON المخزن.
  factory JourneyProgress.fromJson(JsonMap json) {
    return JourneyProgress(
      completed: readModelList(json, 'completed', CompletedWird.fromJson),
    );
  }

  /// لا تقدم بعد.
  static const JourneyProgress empty = JourneyProgress(completed: <CompletedWird>[]);

  /// الأوراد المكتملة بترتيب إتمامها.
  final List<CompletedWird> completed;

  /// هل اكتمل الحديث.
  bool isCompleted(String hadithId) {
    return completed.any((CompletedWird wird) => wird.hadithId == hadithId);
  }

  /// أوقات الإتمام.
  Iterable<DateTime> get completionTimes {
    return completed.map((CompletedWird wird) => wird.completedAt);
  }

  /// يضيف إتماماً جديداً؛ إتمام الحديث نفسه مرة ثانية لا يغيّر السجل.
  JourneyProgress withCompletion(String hadithId, DateTime at) {
    if (isCompleted(hadithId)) {
      return this;
    }
    return JourneyProgress(
      completed: List<CompletedWird>.unmodifiable(<CompletedWird>[
        ...completed,
        CompletedWird(hadithId: hadithId, completedAt: at),
      ]),
    );
  }

  /// للتخزين.
  JsonMap toJson() {
    return <String, dynamic>{
      'completed': completed.map((CompletedWird wird) => wird.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is JourneyProgress && listEquals(other.completed, completed);
  }

  @override
  int get hashCode => Object.hashAll(completed);
}
