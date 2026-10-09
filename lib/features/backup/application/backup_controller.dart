// متحكم النسخ الاحتياطي: التصدير عبر قائمة المشاركة، والاستعادة بخطوتين
// (اختيار الملف وفحصه وحساب الخطة، ثم التطبيق بعد تأكيد المستخدم). عند
// التطبيق تُكتب القيم في التخزين ثم تُبطَل مزودات Riverpod المعتمدة عليه،
// فتتحدث الشاشات فوراً دون إعادة تشغيل.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/preferences/reading_preferences.dart';
import '../../../core/preferences/reception_mode.dart';
import '../../../core/preferences/theme_preference.dart';
import '../../../core/share/share_service.dart';
import '../../../core/storage/key_value_store.dart';
import '../../../core/text/arabic_digits.dart';
import '../../../core/time/clock.dart';
import '../../journey/application/journey_progress_controller.dart';
import '../../journey/application/pacing_notifier.dart';
import '../../reminders/application/reminder_controller.dart';
import '../../seerah/application/seerah_providers.dart';
import '../data/backup_file_picker.dart';
import '../domain/backup_codec.dart';
import '../domain/restore_plan.dart';

/// رسالة نتيجة تُعرض تحت أزرار القسم.
@immutable
class BackupNotice {
  const BackupNotice(this.message, {this.isError = false});

  /// النص.
  final String message;

  /// هل هي خطأ.
  final bool isError;
}

/// حالة القسم.
@immutable
class BackupState {
  const BackupState({this.busy = false, this.notice});

  /// عملية جارية.
  final bool busy;

  /// آخر رسالة.
  final BackupNotice? notice;
}

/// متحكم النسخ الاحتياطي.
class BackupController extends Notifier<BackupState> {
  @override
  BackupState build() => const BackupState();

  Map<String, String> _currentEntries() {
    final KeyValueStore store = ref.read(keyValueStoreProvider);
    final Map<String, String> entries = <String, String>{};
    for (final String key in BackupFormat.includedKeys) {
      final String? value = store.readString(key);
      if (value != null) {
        entries[key] = value;
      }
    }
    return entries;
  }

  /// يبني الملف ويفتح قائمة المشاركة ليحفظه المستخدم في Drive أو التنزيلات.
  Future<void> exportBackup() async {
    if (state.busy) {
      return;
    }
    state = const BackupState(busy: true);
    try {
      final Map<String, String> entries = _currentEntries();
      final String json = BackupCodec.encode(
        entries,
        appVersion: ref.read(appConfigProvider).version,
        createdAt: ref.read(clockProvider)(),
      );
      final int wirds = parseProgressOrEmpty(entries[StorageKeys.journeyProgress]).completed.length;
      await ref.read(shareServiceProvider).shareFile(
            bytes: utf8.encode(json),
            fileName: BackupFormat.fileName,
            mimeType: 'application/json',
            subject: 'نسخة احتياطية من منصة الحديث النبوي',
          );
      if (ref.mounted) {
        state = BackupState(
          notice: BackupNotice(
            'جُهّز ${BackupFormat.fileName} ويتضمن ${arabicDigits(wirds)} من الأوراد المنجزة. '
            'اختر Google Drive أو التنزيلات من قائمة المشاركة لحفظه.',
          ),
        );
      }
    } on Object {
      if (ref.mounted) {
        state = const BackupState(
          notice: BackupNotice('تعذّر تجهيز النسخة أو فتح قائمة المشاركة. حاول مرة أخرى.', isError: true),
        );
      }
    }
  }

  /// يفتح منتقي الملفات ويفحص الملف ويعيد خطة الاستعادة، أو null إن ألغى
  /// المستخدم أو كان الملف غير صالح (وتظهر الرسالة في [BackupState.notice]).
  Future<RestorePlan?> pickAndPlan() async {
    if (state.busy) {
      return null;
    }
    state = const BackupState(busy: true);
    try {
      final String? text = await ref.read(backupFilePickerProvider).pickBackupText();
      if (!ref.mounted) {
        return null;
      }
      if (text == null) {
        state = const BackupState();
        return null;
      }
      final RestorePlan plan = planFromText(text);
      state = const BackupState();
      return plan;
    } on BackupFormatException catch (error) {
      if (ref.mounted) {
        state = BackupState(notice: BackupNotice(error.message, isError: true));
      }
      return null;
    } on Object {
      if (ref.mounted) {
        state = const BackupState(
          notice: BackupNotice('تعذّر فتح الملف المختار.', isError: true),
        );
      }
      return null;
    }
  }

  /// يفحص نص نسخة ويحسب خطتها دون كتابة شيء. يرمي [BackupFormatException].
  RestorePlan planFromText(String text) {
    final BackupContents contents = BackupCodec.decode(text);
    return planRestore(contents, _currentEntries());
  }

  /// يطبق الخطة: يكتب القيم ثم يحدّث الشاشات والمزودات فوراً.
  Future<void> apply(RestorePlan plan) async {
    if (state.busy) {
      return;
    }
    state = const BackupState(busy: true);
    try {
      final KeyValueStore store = ref.read(keyValueStoreProvider);
      for (final MapEntry<String, String> entry in plan.writes.entries) {
        await store.writeString(entry.key, entry.value);
      }
      if (!ref.mounted) {
        return;
      }
      _refreshProviders();
      state = BackupState(
        notice: BackupNotice(
          plan.wirdsAdded == 0
              ? 'استُعيدت التفضيلات. أوراد النسخة مسجلة عندك أصلاً، ومجموع المنجز ${arabicDigits(plan.wirdsTotal)}.'
              : 'اكتملت الاستعادة: أُضيف ${arabicDigits(plan.wirdsAdded)} من الأوراد، '
                  'ومجموع المنجز الآن ${arabicDigits(plan.wirdsTotal)}.',
        ),
      );
    } on Object {
      if (ref.mounted) {
        state = const BackupState(
          notice: BackupNotice('تعذّر تطبيق النسخة على التخزين المحلي.', isError: true),
        );
      }
    }
  }

  /// يبطل كل ما يقرأ من التخزين عند بنائه، فيعيد قراءته بالقيم المستعادة.
  void _refreshProviders() {
    ref
      ..invalidate(journeyProgressProvider)
      ..invalidate(pacingProvider)
      ..invalidate(themePreferenceProvider)
      ..invalidate(readingPreferencesProvider)
      ..invalidate(receptionModeProvider)
      ..invalidate(seerahVisitedProvider)
      ..invalidate(reminderControllerProvider);
    // التنبيه اليومي المجدول فعلياً يوافق الإعدادات المستعادة (جدولة أو إلغاء).
    unawaited(ref.read(reminderControllerProvider.notifier).syncSchedule(cancelWhenDisabled: true));
  }
}

/// النسخ الاحتياطي.
final NotifierProvider<BackupController, BackupState> backupControllerProvider =
    NotifierProvider<BackupController, BackupState>(BackupController.new);
