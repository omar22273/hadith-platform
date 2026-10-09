// متحكم تذكير الورد اليومي: يقرأ الإعدادات من المخزن، ويطلب إذن الإشعارات عند
// التفعيل ويتعامل مع رفضه دون كسر الواجهة، ويجدول التنبيه اليومي أو يلغيه.
//
// الإعدادات تُحفظ بعد نجاح الجدولة، فلا يبقى مفتاح «مفعّل» بلا تنبيه حقيقي.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/key_value_store.dart';
import '../domain/reminder_content.dart';
import '../domain/reminder_settings.dart';
import 'notification_service.dart';

/// نتيجة تبديل التذكير.
enum ReminderToggleResult {
  /// فُعّل وجُدول.
  enabled,

  /// عُطّل وأُلغي.
  disabled,

  /// رُفض إذن الإشعارات فلم يُفعَّل.
  permissionDenied,

  /// تعذرت الجدولة أو الإلغاء.
  failed,

  /// عملية أخرى جارية أو لا تنبيهات على الجهاز.
  ignored,
}

/// حالة التذكير للواجهة.
@immutable
class ReminderState {
  const ReminderState({
    required this.settings,
    this.permissionDenied = false,
    this.failed = false,
    this.busy = false,
  });

  /// الإعدادات المحفوظة.
  final ReminderSettings settings;

  /// إذن الإشعارات مرفوض أو مسحوب؛ تعرض الواجهة طريق الإصلاح.
  final bool permissionDenied;

  /// فشلت آخر جدولة لسبب غير الإذن.
  final bool failed;

  /// عملية جارية.
  final bool busy;

  /// نسخة معدلة.
  ReminderState copyWith({
    ReminderSettings? settings,
    bool? permissionDenied,
    bool? failed,
    bool? busy,
  }) {
    return ReminderState(
      settings: settings ?? this.settings,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      failed: failed ?? this.failed,
      busy: busy ?? this.busy,
    );
  }
}

/// متحكم التذكير.
class ReminderController extends Notifier<ReminderState> {
  @override
  ReminderState build() {
    final String? raw = ref.watch(keyValueStoreProvider).readString(StorageKeys.reminder);
    return ReminderState(settings: ReminderSettings.decode(raw));
  }

  NotificationService get _service => ref.read(notificationServiceProvider);

  Future<void> _persist(ReminderSettings settings) {
    return ref.read(keyValueStoreProvider).writeString(StorageKeys.reminder, settings.encode());
  }

  /// يفعّل التذكير أو يعطّله. التفعيل يطلب الإذن أولاً، والرفض يترك المفتاح
  /// مطفأً مع [ReminderState.permissionDenied] لتعرض الواجهة الإرشاد.
  Future<ReminderToggleResult> setEnabled(bool enabled) async {
    if (state.busy) {
      return ReminderToggleResult.ignored;
    }
    if (enabled && !_service.isAvailable) {
      return ReminderToggleResult.ignored;
    }
    state = state.copyWith(busy: true, permissionDenied: false, failed: false);
    try {
      if (!enabled) {
        await _service.cancelDaily();
        final ReminderSettings next = state.settings.copyWith(enabled: false);
        await _persist(next);
        if (ref.mounted) {
          state = ReminderState(settings: next);
        }
        return ReminderToggleResult.disabled;
      }
      final bool granted = await _service.requestPermission();
      if (!ref.mounted) {
        return ReminderToggleResult.ignored;
      }
      if (!granted) {
        final ReminderSettings off = state.settings.copyWith(enabled: false);
        await _persist(off);
        if (ref.mounted) {
          state = ReminderState(settings: off, permissionDenied: true);
        }
        return ReminderToggleResult.permissionDenied;
      }
      final ReminderSettings next = state.settings.copyWith(enabled: true);
      await _schedule(next);
      await _persist(next);
      if (ref.mounted) {
        state = ReminderState(settings: next);
      }
      return ReminderToggleResult.enabled;
    } on Object {
      if (ref.mounted) {
        state = state.copyWith(busy: false, failed: true);
      }
      return ReminderToggleResult.failed;
    }
  }

  /// يغيّر وقت التنبيه، ويعيد الجدولة فوراً إن كان مفعّلاً.
  Future<ReminderToggleResult> setTime(int hour, int minute) async {
    if (state.busy || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return ReminderToggleResult.ignored;
    }
    final ReminderSettings next = state.settings.copyWith(hour: hour, minute: minute);
    if (!state.settings.enabled) {
      await _persist(next);
      if (ref.mounted) {
        state = state.copyWith(settings: next);
      }
      return ReminderToggleResult.disabled;
    }
    state = state.copyWith(busy: true, failed: false);
    try {
      await _schedule(next);
      await _persist(next);
      if (ref.mounted) {
        state = ReminderState(settings: next);
      }
      return ReminderToggleResult.enabled;
    } on Object {
      if (ref.mounted) {
        state = state.copyWith(busy: false, failed: true);
      }
      return ReminderToggleResult.failed;
    }
  }

  /// يوفّق الجدولة الفعلية مع الإعدادات المحفوظة: عند بدء التطبيق، وبعد
  /// استعادة نسخة احتياطية. إن كان مفعّلاً وسُحب الإذن يُعلَم المستخدم بدل
  /// الفشل الصامت. لا يطلب إذناً ولا يظهر له حوار.
  Future<void> syncSchedule({bool cancelWhenDisabled = false}) async {
    final ReminderSettings settings = state.settings;
    if (!_service.isAvailable) {
      return;
    }
    try {
      if (!settings.enabled) {
        if (cancelWhenDisabled) {
          await _service.cancelDaily();
        }
        return;
      }
      if (!await _service.hasPermission()) {
        if (ref.mounted) {
          state = state.copyWith(permissionDenied: true);
        }
        return;
      }
      await _schedule(settings);
      if (ref.mounted) {
        state = state.copyWith(permissionDenied: false, failed: false);
      }
    } on Object {
      if (ref.mounted) {
        state = state.copyWith(failed: true);
      }
    }
  }

  /// يفتح إعدادات إشعارات التطبيق في النظام.
  Future<bool> openSystemSettings() async {
    try {
      return await _service.openSystemSettings();
    } on Object {
      return false;
    }
  }

  Future<void> _schedule(ReminderSettings settings) {
    return _service.scheduleDaily(
      hour: settings.hour,
      minute: settings.minute,
      title: ReminderContent.title,
      body: ReminderContent.body,
    );
  }
}

/// تذكير الورد اليومي.
final NotifierProvider<ReminderController, ReminderState> reminderControllerProvider =
    NotifierProvider<ReminderController, ReminderState>(ReminderController.new);
