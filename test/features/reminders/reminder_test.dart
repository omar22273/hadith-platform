// اختبارات تذكير الورد اليومي: الإعدادات الافتراضية والوقت، وطلب الإذن
// وحالة الرفض، والجدولة والإلغاء وإعادتها، والشاشة في الإعدادات.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/app/app_shell_screen.dart';
import 'package:hadith_platform/core/storage/key_value_store.dart';
import 'package:hadith_platform/features/reminders/application/notification_service.dart';
import 'package:hadith_platform/features/reminders/application/reminder_controller.dart';
import 'package:hadith_platform/features/reminders/domain/reminder_content.dart';
import 'package:hadith_platform/features/reminders/domain/reminder_settings.dart';

import '../../support/app_harness.dart';
import '../../support/fakes.dart';

Finder _navLabel(String label) {
  return find.descendant(of: find.byType(AppBottomBar), matching: find.text(label));
}

ProviderContainer _container(KeyValueStore store, FakeNotificationService service) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      keyValueStoreProvider.overrideWithValue(store),
      notificationServiceProvider.overrideWithValue(service),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('settings', () {
    test('default to disabled at 07:00 and survive corrupt storage', () {
      expect(ReminderSettings.initial.enabled, isFalse);
      expect(ReminderSettings.initial.hour, 7);
      expect(ReminderSettings.initial.minute, 0);
      expect(ReminderSettings.decode(null), ReminderSettings.initial);
      expect(ReminderSettings.decode('not json'), ReminderSettings.initial);
      expect(ReminderSettings.decode('[1,2]'), ReminderSettings.initial);
      expect(
        ReminderSettings.decode('{"enabled":true,"hour":99,"minute":-4}'),
        const ReminderSettings(enabled: true, hour: 7, minute: 0),
      );
      const ReminderSettings custom = ReminderSettings(enabled: true, hour: 21, minute: 30);
      expect(ReminderSettings.decode(custom.encode()), custom);
    });

    test('times read naturally in Arabic digits', () {
      expect(formatReminderTime(7, 0), '٧:٠٠ صباحاً');
      expect(formatReminderTime(21, 30), '٩:٣٠ مساءً');
      expect(formatReminderTime(0, 5), '١٢:٠٥ صباحاً');
      expect(formatReminderTime(12, 0), '١٢:٠٠ مساءً');
    });

    test('the notification text is exactly the requested encouragement', () {
      expect(ReminderContent.title, 'وِردك اليومي من الأربعين النبوية');
      expect(ReminderContent.body, 'حافظ على استمرارية مسيرتك وافتح حديث اليوم لتثبيت الورد.');
    });
  });

  group('controller', () {
    test('enabling asks for permission, schedules 07:00 daily and persists', () async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore();
      final FakeNotificationService service = FakeNotificationService();
      final ProviderContainer container = _container(store, service);
      final ReminderController controller = container.read(reminderControllerProvider.notifier);

      expect(container.read(reminderControllerProvider).settings, ReminderSettings.initial);
      expect(await controller.setEnabled(true), ReminderToggleResult.enabled);

      expect(service.permissionRequests, 1);
      expect(service.scheduled, hasLength(1));
      expect(service.scheduled.single.hour, 7);
      expect(service.scheduled.single.minute, 0);
      expect(service.scheduled.single.title, ReminderContent.title);
      expect(service.scheduled.single.body, ReminderContent.body);
      expect(container.read(reminderControllerProvider).settings.enabled, isTrue);
      expect(ReminderSettings.decode(store.readString(StorageKeys.reminder)).enabled, isTrue);
    });

    test('a denied permission leaves the reminder off, schedules nothing and flags the denial', () async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore();
      final FakeNotificationService service = FakeNotificationService(permissionGranted: false);
      final ProviderContainer container = _container(store, service);
      final ReminderController controller = container.read(reminderControllerProvider.notifier);

      expect(await controller.setEnabled(true), ReminderToggleResult.permissionDenied);

      expect(service.scheduled, isEmpty);
      expect(container.read(reminderControllerProvider).settings.enabled, isFalse);
      expect(container.read(reminderControllerProvider).permissionDenied, isTrue);
      expect(ReminderSettings.decode(store.readString(StorageKeys.reminder)).enabled, isFalse);

      // بعد أن يمنح المستخدم الإذن من إعدادات النظام يعمل التفعيل.
      service.permissionGranted = true;
      expect(await controller.setEnabled(true), ReminderToggleResult.enabled);
      expect(container.read(reminderControllerProvider).permissionDenied, isFalse);
      expect(service.scheduled, hasLength(1));
    });

    test('changing the time reschedules only while enabled', () async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore();
      final FakeNotificationService service = FakeNotificationService();
      final ProviderContainer container = _container(store, service);
      final ReminderController controller = container.read(reminderControllerProvider.notifier);

      await controller.setTime(6, 15);
      expect(service.scheduled, isEmpty, reason: 'disabled: only remembered');
      expect(container.read(reminderControllerProvider).settings.timeLabel, '٦:١٥ صباحاً');

      await controller.setEnabled(true);
      expect(service.scheduled.last.hour, 6);
      expect(service.scheduled.last.minute, 15);

      await controller.setTime(21, 45);
      expect(service.scheduled, hasLength(2));
      expect(service.scheduled.last.hour, 21);
      expect(service.scheduled.last.minute, 45);

      expect(await controller.setTime(25, 0), ReminderToggleResult.ignored);
      expect(await controller.setTime(8, 60), ReminderToggleResult.ignored);
      expect(service.scheduled, hasLength(2));
    });

    test('disabling cancels the scheduled notification', () async {
      final FakeNotificationService service = FakeNotificationService();
      final ProviderContainer container = _container(InMemoryKeyValueStore(), service);
      final ReminderController controller = container.read(reminderControllerProvider.notifier);
      await controller.setEnabled(true);

      expect(await controller.setEnabled(false), ReminderToggleResult.disabled);
      expect(service.cancelCount, 1);
      expect(container.read(reminderControllerProvider).settings.enabled, isFalse);
    });

    test('syncing on launch reschedules when allowed and reports a revoked permission', () async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore(<String, String>{
        StorageKeys.reminder: jsonEncode(<String, Object>{'enabled': true, 'hour': 5, 'minute': 40}),
      });
      final FakeNotificationService service = FakeNotificationService()..currentlyGranted = true;
      final ProviderContainer container = _container(store, service);

      await container.read(reminderControllerProvider.notifier).syncSchedule();
      expect(service.scheduled, hasLength(1));
      expect(service.scheduled.single.hour, 5);
      expect(service.scheduled.single.minute, 40);
      expect(container.read(reminderControllerProvider).permissionDenied, isFalse);

      service.currentlyGranted = false;
      await container.read(reminderControllerProvider.notifier).syncSchedule();
      expect(service.scheduled, hasLength(1), reason: 'nothing scheduled without permission');
      expect(container.read(reminderControllerProvider).permissionDenied, isTrue);
      expect(container.read(reminderControllerProvider).settings.enabled, isTrue, reason: 'the choice is kept');
    });

    test('an unavailable platform ignores the toggle', () async {
      final FakeNotificationService service = FakeNotificationService(available: false);
      final ProviderContainer container = _container(InMemoryKeyValueStore(), service);
      expect(
        await container.read(reminderControllerProvider.notifier).setEnabled(true),
        ReminderToggleResult.ignored,
      );
      expect(service.permissionRequests, 0);
    });
  });

  group('settings screen', () {
    Future<void> openSettings(WidgetTester tester, FakeNotificationService service, {Map<String, String>? stored}) async {
      await pumpApp(tester, size: const Size(412, 3200), stored: stored, notificationService: service);
      await tester.tap(_navLabel('الإعدادات'));
      await settle(tester);
    }

    testWidgets('the switch asks permission, schedules the default 07:00 and confirms', (WidgetTester tester) async {
      final FakeNotificationService service = FakeNotificationService();
      await openSettings(tester, service);

      expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey<String>('reminder-switch'))).value, isFalse);
      expect(find.text('٧:٠٠ صباحاً'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('reminder-switch')));
      await settle(tester);

      expect(service.permissionRequests, 1);
      expect(service.scheduled, hasLength(1));
      expect(service.scheduled.single.hour, 7);
      expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey<String>('reminder-switch'))).value, isTrue);
      expect(find.textContaining('سيصلك التذكير كل يوم'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a denied permission keeps the switch off and shows how to fix it', (WidgetTester tester) async {
      final FakeNotificationService service = FakeNotificationService(permissionGranted: false);
      await openSettings(tester, service);

      await tester.tap(find.byKey(const ValueKey<String>('reminder-switch')));
      await settle(tester);

      expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey<String>('reminder-switch'))).value, isFalse);
      expect(find.byKey(const ValueKey<String>('reminder-permission-notice')), findsOneWidget);
      expect(service.scheduled, isEmpty);

      await tester.tap(find.text('فتح إعدادات الإشعارات'));
      await settle(tester);
      expect(service.openedSettings, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a saved reminder is rescheduled when the app opens', (WidgetTester tester) async {
      final FakeNotificationService service = FakeNotificationService()..currentlyGranted = true;
      await openSettings(
        tester,
        service,
        stored: <String, String>{
          StorageKeys.reminder: const ReminderSettings(enabled: true, hour: 21, minute: 30).encode(),
        },
      );

      expect(service.scheduled, hasLength(1));
      expect(service.scheduled.single.hour, 21);
      expect(service.scheduled.single.minute, 30);
      expect(find.text('٩:٣٠ مساءً'), findsOneWidget);
    });

    testWidgets('the time tile opens the time picker', (WidgetTester tester) async {
      await openSettings(tester, FakeNotificationService());

      await tester.tap(find.byKey(const ValueKey<String>('reminder-time')));
      await settle(tester);
      expect(find.text('وقت التذكير اليومي'), findsOneWidget);

      await tester.tap(find.text('إلغاء'));
      await settle(tester);
      expect(find.text('وقت التذكير اليومي'), findsNothing);
      expect(find.text('٧:٠٠ صباحاً'), findsOneWidget);
    });

    testWidgets('without platform support the section explains it', (WidgetTester tester) async {
      await pumpApp(tester, size: const Size(412, 3200));
      await tester.tap(_navLabel('الإعدادات'));
      await settle(tester);

      expect(find.byKey(const ValueKey<String>('reminder-switch')), findsNothing);
      expect(find.textContaining('غير متاحة على هذا الجهاز'), findsOneWidget);
    });
  });
}
