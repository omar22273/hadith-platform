// قسم «تذكير الورد اليومي» في الإعدادات: مفتاح التفعيل، ومحدد وقت التنبيه،
// وإرشاد واضح حين يُرفض إذن الإشعارات (مع زر يفتح إعدادات النظام).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/ui/app_shapes.dart';
import '../../../core/ui/smooth_surface.dart';
import '../../settings/presentation/widgets/settings_card.dart';
import '../application/notification_service.dart';
import '../application/reminder_controller.dart';
import '../domain/reminder_settings.dart';

/// قسم التذكير.
class ReminderSection extends ConsumerWidget {
  const ReminderSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final ReminderState state = ref.watch(reminderControllerProvider);
    final bool available = ref.watch(notificationServiceProvider).isAvailable;
    final ReminderSettings settings = state.settings;

    if (!available) {
      return SettingsCard(
        title: 'تذكير الورد اليومي',
        icon: Icons.notifications_off_outlined,
        children: <Widget>[
          Text(
            'التنبيهات المحلية غير متاحة على هذا الجهاز.',
            style: text.bodySmall?.copyWith(color: palette.inkSoft, height: 1.7),
          ),
        ],
      );
    }

    Future<void> toggle(bool value) async {
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      final ReminderToggleResult result = await ref.read(reminderControllerProvider.notifier).setEnabled(value);
      switch (result) {
        case ReminderToggleResult.enabled:
          final ReminderSettings now = ref.read(reminderControllerProvider).settings;
          messenger.showSnackBar(
            SnackBar(content: Text('سيصلك التذكير كل يوم في ${now.timeLabel}')),
          );
        case ReminderToggleResult.failed:
          messenger.showSnackBar(const SnackBar(content: Text('تعذّر ضبط التذكير. حاول مرة أخرى.')));
        case ReminderToggleResult.disabled:
        case ReminderToggleResult.permissionDenied:
        case ReminderToggleResult.ignored:
          break;
      }
    }

    Future<void> pickTime() async {
      final TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: settings.hour, minute: settings.minute),
        helpText: 'وقت التذكير اليومي',
        cancelText: 'إلغاء',
        confirmText: 'حفظ',
      );
      if (picked == null) {
        return;
      }
      await ref.read(reminderControllerProvider.notifier).setTime(picked.hour, picked.minute);
    }

    return SettingsCard(
      title: 'تذكير الورد اليومي',
      icon: Icons.notifications_active_outlined,
      children: <Widget>[
        SwitchListTile(
          key: const ValueKey<String>('reminder-switch'),
          contentPadding: EdgeInsets.zero,
          value: settings.enabled,
          onChanged: state.busy ? null : (bool value) => unawaited(toggle(value)),
          title: const Text('ذكّرني كل يوم'),
          subtitle: Text(
            settings.enabled
                ? 'ينبّهك التطبيق كل يوم في ${settings.timeLabel} لتفتح حديث اليوم.'
                : 'تنبيه لطيف يحافظ على استمرارية وردك اليومي.',
          ),
          secondary: Icon(Icons.alarm_rounded, color: palette.amberText),
        ),
        const SizedBox(height: 4),
        ListTile(
          key: const ValueKey<String>('reminder-time'),
          contentPadding: EdgeInsets.zero,
          enabled: !state.busy,
          leading: Icon(Icons.schedule_rounded, color: palette.amberText),
          title: const Text('وقت التذكير'),
          subtitle: Text(settings.enabled ? 'اضغط لتغيير الوقت' : 'يُطبَّق عند تفعيل التذكير'),
          trailing: Text(
            settings.timeLabel,
            style: AppTypography.ui(
              color: palette.amberText,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          onTap: () => unawaited(pickTime()),
        ),
        if (state.permissionDenied) ...<Widget>[
          const SizedBox(height: 8),
          SmoothSurface(
            key: const ValueKey<String>('reminder-permission-notice'),
            color: palette.amberSoft,
            borderColor: palette.amber.withValues(alpha: 0.4),
            radius: AppShapes.radiusMedium,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'لم يُمنح إذن الإشعارات، فلا يستطيع التطبيق تذكيرك. '
                  'يمكنك منحه من إعدادات النظام ثم تفعيل المفتاح من جديد.',
                  style: text.bodySmall?.copyWith(color: palette.amberText, height: 1.7),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => unawaited(ref.read(reminderControllerProvider.notifier).openSystemSettings()),
                    icon: const Icon(Icons.settings_rounded),
                    label: const Text('فتح إعدادات الإشعارات'),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (state.failed) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            'تعذّرت جدولة التذكير على هذا الجهاز. جرّب إعادة تفعيله.',
            style: text.bodySmall?.copyWith(color: palette.inkSoft, height: 1.7),
          ),
        ],
      ],
    );
  }
}
