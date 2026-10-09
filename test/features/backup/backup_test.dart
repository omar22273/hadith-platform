// اختبارات النسخ الاحتياطي: صيغة الملف وبصمته، وفحص البيانات، وخطة الدمج التي
// لا تُنقص التقدم، ثم التصدير والاستعادة من شاشة الإعدادات مع تحديث فوري
// للمزودات دون إعادة تشغيل.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/app/app_shell_screen.dart';
import 'package:hadith_platform/core/preferences/theme_preference.dart';
import 'package:hadith_platform/core/storage/key_value_store.dart';
import 'package:hadith_platform/features/backup/domain/backup_codec.dart';
import 'package:hadith_platform/features/backup/domain/restore_plan.dart';
import 'package:hadith_platform/features/journey/application/journey_progress_controller.dart';
import 'package:hadith_platform/features/journey/application/pacing_notifier.dart';
import 'package:hadith_platform/features/journey/domain/journey_progress.dart';
import 'package:hadith_platform/features/journey/domain/pacing.dart';
import 'package:hadith_platform/features/reminders/domain/reminder_settings.dart';
import 'package:hadith_platform/features/seerah/application/seerah_providers.dart';

import '../../support/app_harness.dart';
import '../../support/fakes.dart';

Finder _navLabel(String label) {
  return find.descendant(of: find.byType(AppBottomBar), matching: find.text(label));
}

final DateTime _created = DateTime.utc(2026, 10, 10, 8);

String _progress(Map<String, DateTime> wirds) {
  return jsonEncode(
    JourneyProgress(
      completed: <CompletedWird>[
        for (final MapEntry<String, DateTime> entry in wirds.entries)
          CompletedWird(hadithId: entry.key, completedAt: entry.value),
      ],
    ).toJson(),
  );
}

String _pacing(int best, {int quota = 1}) {
  return jsonEncode(PacingSettings.initial.copyWith(recordedBestStreak: best, selectedQuota: quota).toJson());
}

void main() {
  group('codec', () {
    final Map<String, String> entries = <String, String>{
      StorageKeys.journeyProgress: _progress(<String, DateTime>{'nawawi40_001': DateTime.utc(2026, 10, 1)}),
      StorageKeys.themeMode: 'dark',
      StorageKeys.pacing: _pacing(4),
    };

    test('round-trips the stored values with a checksum', () {
      final String file = BackupCodec.encode(entries, appVersion: '2.2.0', createdAt: _created);
      final Map<String, dynamic> document = jsonDecode(file) as Map<String, dynamic>;
      expect(document['format'], BackupFormat.id);
      expect(document['version'], 1);
      expect(document['appVersion'], '2.2.0');
      expect((document['checksum'] as String).length, 64);

      final BackupContents contents = BackupCodec.decode(file);
      expect(contents.entries, entries);
      expect(contents.appVersion, '2.2.0');
      expect(contents.createdAt, isNotNull);
    });

    test('never exports the device salt or unreadable-progress copy', () {
      final String file = BackupCodec.encode(
        <String, String>{
          ...entries,
          StorageKeys.installSalt: 'secret-salt',
          StorageKeys.journeyProgressUnreadable: 'garbage',
        },
        appVersion: '2.2.0',
        createdAt: _created,
      );
      expect(file, isNot(contains('secret-salt')));
      expect(file, isNot(contains('garbage')));
      expect(BackupCodec.decode(file).entries.keys.toSet(), entries.keys.toSet());
    });

    test('any edit after export is caught by the checksum', () {
      final String file = BackupCodec.encode(entries, appVersion: '2.2.0', createdAt: _created);
      expect(
        () => BackupCodec.decode(file.replaceFirst('dark', 'light')),
        throwsA(isA<BackupFormatException>().having((BackupFormatException e) => e.message, 'message', contains('فحص السلامة'))),
      );
    });

    test('rejects foreign, broken, newer and oversized files with clear messages', () {
      expect(() => BackupCodec.decode('not json at all'), throwsA(isA<BackupFormatException>()));
      expect(() => BackupCodec.decode('{"hello":1}'), throwsA(isA<BackupFormatException>()));
      expect(() => BackupCodec.decode('[1,2,3]'), throwsA(isA<BackupFormatException>()));
      expect(
        () => BackupCodec.decode(jsonEncode(<String, Object>{'format': BackupFormat.id, 'version': 1, 'data': 5})),
        throwsA(isA<BackupFormatException>()),
      );
      expect(
        () => BackupCodec.decode(
          jsonEncode(<String, Object>{'format': BackupFormat.id, 'version': 99, 'data': <String, String>{}, 'checksum': 'x'}),
        ),
        throwsA(isA<BackupFormatException>().having((BackupFormatException e) => e.message, 'message', contains('أحدث'))),
      );
      expect(() => BackupCodec.decode('x' * (BackupFormat.maxBytes + 1)), throwsA(isA<BackupFormatException>()));
    });

    test('keys this app does not know are ignored, not applied', () {
      final Map<String, String> data = <String, String>{'evil.key': 'x', StorageKeys.themeMode: 'dark'};
      final String file = jsonEncode(<String, Object>{
        'format': BackupFormat.id,
        'version': 1,
        'appVersion': '9',
        'createdAt': _created.toIso8601String(),
        'data': data,
        'checksum': BackupCodec.checksumOf(data),
      });
      expect(BackupCodec.decode(file).entries, <String, String>{StorageKeys.themeMode: 'dark'});
    });
  });

  group('restore plan', () {
    BackupContents backup(Map<String, String> entries) {
      return BackupCodec.decode(BackupCodec.encode(entries, appVersion: '2.2.0', createdAt: _created));
    }

    test('merges progress without ever reducing it, keeping the earliest completion', () {
      final DateTime early = DateTime.utc(2026, 10, 1);
      final DateTime late = DateTime.utc(2026, 10, 5);
      final RestorePlan plan = planRestore(
        backup(<String, String>{
          StorageKeys.journeyProgress: _progress(<String, DateTime>{'nawawi40_001': early, 'nawawi40_002': late}),
        }),
        <String, String>{
          StorageKeys.journeyProgress: _progress(<String, DateTime>{'nawawi40_001': late, 'nawawi40_003': late}),
        },
      );
      expect(plan.wirdsInBackup, 2);
      expect(plan.wirdsAdded, 1);
      expect(plan.wirdsTotal, 3);
      final JourneyProgress merged = parseProgressOrEmpty(plan.writes[StorageKeys.journeyProgress]);
      expect(merged.completed.map((CompletedWird w) => w.hadithId).toSet(), <String>{'nawawi40_001', 'nawawi40_002', 'nawawi40_003'});
      expect(
        merged.completed.firstWhere((CompletedWird w) => w.hadithId == 'nawawi40_001').completedAt.toUtc(),
        early,
        reason: 'the earlier completion wins',
      );
    });

    test('keeps the higher best streak and unions visited seerah stations', () {
      final RestorePlan plan = planRestore(
        backup(<String, String>{
          StorageKeys.pacing: _pacing(3, quota: 2),
          StorageKeys.seerahVisited: jsonEncode(<String>['a', 'b']),
        }),
        <String, String>{
          StorageKeys.pacing: _pacing(9),
          StorageKeys.seerahVisited: jsonEncode(<String>['b', 'c']),
        },
      );
      final PacingSettings pacing = PacingSettings.fromJson(jsonDecode(plan.writes[StorageKeys.pacing]!) as Map<String, dynamic>);
      expect(pacing.recordedBestStreak, 9);
      expect(pacing.selectedQuota, 2, reason: 'the backup preference is applied');
      expect(jsonDecode(plan.writes[StorageKeys.seerahVisited]!), <String>['a', 'b', 'c']);
      expect(plan.stationsAdded, 1);
    });

    test('replaces preferences and normalizes the reminder', () {
      final RestorePlan plan = planRestore(
        backup(<String, String>{
          StorageKeys.themeMode: 'dark',
          StorageKeys.receptionMode: 'oral',
          StorageKeys.readingPreferences: jsonEncode(<String, Object>{'matnFontSize': 30}),
          StorageKeys.reminder: const ReminderSettings(enabled: true, hour: 6, minute: 5).encode(),
        }),
        <String, String>{StorageKeys.themeMode: 'parchment'},
      );
      expect(plan.writes[StorageKeys.themeMode], 'dark');
      expect(plan.writes[StorageKeys.receptionMode], 'oral');
      expect(ReminderSettings.decode(plan.writes[StorageKeys.reminder]).hour, 6);
      expect(plan.writes.containsKey(StorageKeys.readingPreferences), isTrue);
    });

    test('a corrupt value rejects the whole backup before anything is written', () {
      expect(
        () => planRestore(backup(<String, String>{StorageKeys.journeyProgress: '{"completed": 7}'}), const <String, String>{}),
        throwsA(isA<BackupFormatException>()),
      );
      expect(
        () => planRestore(backup(<String, String>{StorageKeys.seerahVisited: '{"a":1}'}), const <String, String>{}),
        throwsA(isA<BackupFormatException>()),
      );
      expect(
        () => planRestore(backup(<String, String>{StorageKeys.themeMode: ''}), const <String, String>{}),
        throwsA(isA<BackupFormatException>()),
      );
    });
  });

  group('settings screen', () {
    Future<ProviderContainer> openSettings(
      WidgetTester tester, {
      Map<String, String>? stored,
      FakeShareService? share,
      FakeBackupFilePicker? picker,
    }) async {
      final ProviderContainer container = await pumpApp(
        tester,
        size: const Size(412, 3200),
        stored: stored,
        shareService: share,
        backupFilePicker: picker,
      );
      await tester.tap(_navLabel('الإعدادات'));
      await settle(tester);
      return container;
    }

    testWidgets('exporting shares hadith_backup.json with the progress and preferences', (WidgetTester tester) async {
      final FakeShareService share = FakeShareService();
      await openSettings(
        tester,
        share: share,
        stored: <String, String>{
          StorageKeys.journeyProgress: completedProgressJson(),
          StorageKeys.themeMode: 'dark',
          StorageKeys.installSalt: 'device-secret',
        },
      );

      await tester.tap(find.byKey(const ValueKey<String>('backup-export')));
      await settle(tester);

      expect(share.files, hasLength(1));
      final SharedFile file = share.files.single;
      expect(file.fileName, 'hadith_backup.json');
      expect(file.mimeType, 'application/json');
      final String text = utf8.decode(file.bytes);
      expect(text, isNot(contains('device-secret')));
      final BackupContents contents = BackupCodec.decode(text);
      expect(parseProgressOrEmpty(contents.entries[StorageKeys.journeyProgress]).completed, hasLength(2));
      expect(contents.entries[StorageKeys.themeMode], 'dark');
      expect(find.byKey(const ValueKey<String>('backup-notice')), findsOneWidget);
      expect(find.textContaining('hadith_backup.json'), findsWidgets);
    });

    testWidgets('a failing share sheet is reported without crashing', (WidgetTester tester) async {
      final FakeShareService share = FakeShareService()..failing = true;
      await openSettings(tester, share: share);

      await tester.tap(find.byKey(const ValueKey<String>('backup-export')));
      await settle(tester);

      expect(find.textContaining('تعذّر تجهيز النسخة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('restoring applies progress and preferences immediately, without a restart', (WidgetTester tester) async {
      final String file = BackupCodec.encode(
        <String, String>{
          StorageKeys.journeyProgress: completedProgressJson(),
          StorageKeys.themeMode: 'dark',
          StorageKeys.pacing: _pacing(9),
          StorageKeys.seerahVisited: jsonEncode(<String>['station_a']),
          StorageKeys.receptionMode: 'oral',
        },
        appVersion: '2.2.0',
        createdAt: _created,
      );
      final FakeBackupFilePicker picker = FakeBackupFilePicker(file);
      final ProviderContainer container = await openSettings(tester, picker: picker);

      expect((await container.read(journeyProgressProvider.future)).completed, isEmpty);
      expect(container.read(themePreferenceProvider), ThemePreference.system);

      await tester.tap(find.byKey(const ValueKey<String>('backup-import')));
      await settle(tester);
      expect(picker.picks, 1);
      expect(find.text('استعادة التقدم؟'), findsOneWidget);
      expect(find.textContaining('ويُضاف منها ٢'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('backup-confirm-restore')));
      await settle(tester);

      // التخزين والمزودات والواجهة كلها تحدثت فوراً.
      final KeyValueStore store = container.read(keyValueStoreProvider);
      expect(parseProgressOrEmpty(store.readString(StorageKeys.journeyProgress)).completed, hasLength(2));
      expect((await container.read(journeyProgressProvider.future)).completed, hasLength(2));
      expect(container.read(themePreferenceProvider), ThemePreference.dark);
      expect(container.read(seerahVisitedProvider), <String>{'station_a'});
      expect((await container.read(pacingProvider.future)).bestStreak, greaterThanOrEqualTo(9));
      expect(Theme.of(tester.element(find.byType(Scaffold).first)).brightness, Brightness.dark);
      expect(find.textContaining('اكتملت الاستعادة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancelling the confirmation leaves everything untouched', (WidgetTester tester) async {
      final String file = BackupCodec.encode(
        <String, String>{StorageKeys.themeMode: 'dark'},
        appVersion: '2.2.0',
        createdAt: _created,
      );
      final ProviderContainer container = await openSettings(tester, picker: FakeBackupFilePicker(file));

      await tester.tap(find.byKey(const ValueKey<String>('backup-import')));
      await settle(tester);
      await tester.tap(find.text('إلغاء').last);
      await settle(tester);

      expect(container.read(themePreferenceProvider), ThemePreference.system);
      expect(container.read(keyValueStoreProvider).readString(StorageKeys.themeMode), isNull);
    });

    testWidgets('a corrupt or tampered file is refused with a clear message and no change', (WidgetTester tester) async {
      final String good = BackupCodec.encode(
        <String, String>{StorageKeys.themeMode: 'dark'},
        appVersion: '2.2.0',
        createdAt: _created,
      );
      final FakeBackupFilePicker picker = FakeBackupFilePicker('{"hello": "world"}');
      final ProviderContainer container = await openSettings(tester, picker: picker);

      await tester.tap(find.byKey(const ValueKey<String>('backup-import')));
      await settle(tester);
      expect(find.text('استعادة التقدم؟'), findsNothing);
      expect(find.textContaining('ليس نسخة احتياطية'), findsOneWidget);

      picker.text = good.replaceFirst('dark', 'parchment');
      await tester.tap(find.byKey(const ValueKey<String>('backup-import')));
      await settle(tester);
      expect(find.text('استعادة التقدم؟'), findsNothing);
      expect(find.textContaining('فحص السلامة'), findsOneWidget);

      expect(container.read(themePreferenceProvider), ThemePreference.system);
      expect(container.read(keyValueStoreProvider).readString(StorageKeys.themeMode), isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dismissing the file picker is silent', (WidgetTester tester) async {
      final FakeBackupFilePicker picker = FakeBackupFilePicker();
      await openSettings(tester, picker: picker);

      await tester.tap(find.byKey(const ValueKey<String>('backup-import')));
      await settle(tester);

      expect(picker.picks, 1);
      expect(find.byKey(const ValueKey<String>('backup-notice')), findsNothing);
      expect(find.text('استعادة التقدم؟'), findsNothing);
    });
  });
}
