// قسم «النسخ الاحتياطي» في الإعدادات: تصدير التقدم ملفاً hadith_backup.json
// عبر قائمة المشاركة (Google Drive أو التنزيلات)، واستعادته من ملف مع عرض ما
// سيتغير وطلب التأكيد قبل التطبيق.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/text/arabic_digits.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/ui/app_shapes.dart';
import '../../../core/ui/smooth_surface.dart';
import '../../settings/presentation/widgets/settings_card.dart';
import '../application/backup_controller.dart';
import '../domain/backup_codec.dart';
import '../domain/restore_plan.dart';

/// قسم النسخ الاحتياطي.
class BackupSection extends ConsumerWidget {
  const BackupSection({super.key});

  static String _dateLabel(DateTime? at) {
    if (at == null) {
      return 'غير معروف';
    }
    final String month = at.month.toString().padLeft(2, '0');
    final String day = at.day.toString().padLeft(2, '0');
    return arabicDigits('${at.year}/$month/$day');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final BackupState state = ref.watch(backupControllerProvider);
    final BackupController controller = ref.read(backupControllerProvider.notifier);

    Future<void> restore() async {
      final RestorePlan? plan = await controller.pickAndPlan();
      if (plan == null || !context.mounted) {
        return;
      }
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          shape: AppShapes.rounded(AppShapes.radiusLarge),
          title: const Text('استعادة التقدم؟'),
          content: Text(
            'تاريخ النسخة: ${_dateLabel(plan.createdAt)}\n'
            'الأوراد المنجزة فيها: ${arabicDigits(plan.wirdsInBackup)}، '
            'ويُضاف منها ${arabicDigits(plan.wirdsAdded)} إلى تقدمك الحالي دون حذف شيء.\n'
            'تُستبدل التفضيلات (السمة والخطوط والتذكير والوتيرة) بما في النسخة.',
            style: AppTypography.ui(color: palette.ink, fontSize: 14, height: 1.8),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              key: const ValueKey<String>('backup-confirm-restore'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('استعادة'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await controller.apply(plan);
      }
    }

    final BackupNotice? notice = state.notice;
    return SettingsCard(
      title: 'النسخ الاحتياطي',
      icon: Icons.cloud_upload_outlined,
      children: <Widget>[
        Text(
          'احفظ تقدمك (الأوراد المنجزة وسلسلة الاستمرارية والتفضيلات) في ملف ${BackupFormat.fileName} '
          'وأرسله إلى Google Drive أو التنزيلات، ثم استعده متى شئت على هذا الجهاز أو جهاز جديد.',
          style: text.bodySmall?.copyWith(color: palette.inkSoft, height: 1.8),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey<String>('backup-export'),
                onPressed: state.busy ? null : () => unawaited(controller.exportBackup()),
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('تصدير التقدم'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey<String>('backup-import'),
                onPressed: state.busy ? null : () => unawaited(restore()),
                icon: const Icon(Icons.download_rounded),
                label: const Text('استعادة التقدم'),
              ),
            ),
          ],
        ),
        if (state.busy) ...<Widget>[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        if (notice != null) ...<Widget>[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: SmoothSurface(
              key: const ValueKey<String>('backup-notice'),
              color: notice.isError ? palette.amberSoft : palette.emeraldSoft,
              borderColor: notice.isError ? palette.amber.withValues(alpha: 0.5) : palette.emerald.withValues(alpha: 0.5),
              radius: AppShapes.radiusMedium,
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    notice.isError ? Icons.info_outline_rounded : Icons.check_circle_outline_rounded,
                    color: notice.isError ? palette.amberText : palette.emeraldText,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      notice.message,
                      style: text.bodySmall?.copyWith(
                        color: notice.isError ? palette.amberText : palette.emeraldText,
                        height: 1.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          'الملف محميّ ببصمة تحقق (SHA-256) تكشف أي تلف أو تعديل بعد التصدير، ولا يحوي سوى تقدمك وتفضيلاتك '
          'دون أي بيانات شخصية، لذا لا يُشفَّر بكلمة سر.',
          style: text.labelSmall?.copyWith(color: palette.inkSoft, height: 1.7),
        ),
      ],
    );
  }
}
