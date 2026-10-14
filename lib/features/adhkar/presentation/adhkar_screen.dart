// التبويب الثالث: مركز الأذكار الهادئ.
//
// سبع بطاقات كبيرة مرتبة رأسياً، كل منها بوابة إلى شاشة تركيز مستقلة:
// الفئات الست التي لها ملفات بيانات مشكولة (أذكار الصباح والمساء، النوم والاستيقاظ،
// أدبار الصلوات، دخول وخروج المنزل والمسجد، السنن المهجورة، جامع الأدعية المأثورة)
// يفتح كل منها مشغّل التركيز AdhkarPlayerScreen، والسابعة السبحة النبوية الذكية.
//
// المركز لا يعرض أي نص نبوي ولا تخريج؛ عناوين البطاقات وأسطرها التعريفية واجهة فقط،
// ونصوص الأذكار وشواهدها تُقرأ من ملفات assets/data/adhkar/ داخل المشغّل وحده.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/text/arabic_digits.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/ui/app_shapes.dart';
import '../../../core/ui/smooth_surface.dart';
import '../application/adhkar_providers.dart';
import '../application/sebha_controller.dart';
import '../domain/adhkar_category.dart';
import 'adhkar_player_screen.dart';
import 'sebha_screen.dart';

/// مركز الأذكار.
class AdhkarScreen extends StatelessWidget {
  const AdhkarScreen({super.key});

  void _openCategory(BuildContext context, AdhkarCategory category) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (BuildContext context) => AdhkarPlayerScreen(category: category)),
      ),
    );
  }

  void _openSebha(BuildContext context) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (BuildContext context) => const SebhaScreen()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          key: const ValueKey<String>('adhkar-hub'),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'مركز الأذكار',
                    key: const ValueKey<String>('adhkar-hub-title'),
                    style: AppTypography.heritageTitle(color: palette.ink, fontSize: 30),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'أذكار وسنن مشكولة، كل ذكر منها مقتطع حرفياً من شاهده الموثق.',
                    style: text.bodyMedium?.copyWith(color: palette.inkSoft, height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            for (final AdhkarCategory category in AdhkarCategories.all) ...<Widget>[
              _CategoryCard(category: category, onTap: () => _openCategory(context, category)),
              const SizedBox(height: 12),
            ],
            _SebhaCard(onTap: () => _openSebha(context)),
          ],
        ),
      ),
    );
  }
}

/// بطاقة فئة: أيقونة، وعنوان، وسطر تعريفي، وعدد الأذكار بعد تحميل ملفها.
class _CategoryCard extends ConsumerWidget {
  const _CategoryCard({required this.category, required this.onTap});

  final AdhkarCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final int total = ref.watch(adhkarItemsProvider(category.id)).length;
    return SmoothSurface(
      key: ValueKey<String>('adhkar-card-${category.id}'),
      onTap: onTap,
      elevated: true,
      borderColor: palette.line,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      semanticLabel: total == 0
          ? '${category.title}. ${category.subtitle}'
          : '${category.title}. ${category.subtitle}. ${arabicDigits(total)} بطاقة',
      child: Row(
        children: <Widget>[
          _IconTile(icon: category.icon, background: palette.amberSoft, foreground: palette.amberText),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  category.title,
                  style: text.titleMedium?.copyWith(color: palette.ink, fontWeight: FontWeight.w700, height: 1.4),
                ),
                const SizedBox(height: 4),
                Text(
                  category.subtitle,
                  style: text.bodySmall?.copyWith(color: palette.inkSoft, height: 1.5),
                ),
              ],
            ),
          ),
          if (total > 0) ...<Widget>[
            const SizedBox(width: 10),
            _CountBadge(
              key: ValueKey<String>('adhkar-card-count-${category.id}'),
              label: arabicDigits(total),
            ),
          ],
        ],
      ),
    );
  }
}

/// بطاقة السبحة الذكية: تتميز بلون أخضر هادئ، وتعرض مجموع ما سبّحه المستخدم إن وُجد.
class _SebhaCard extends ConsumerWidget {
  const _SebhaCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final int grand = ref.watch(sebhaProvider.select((SebhaState s) => s.grandTotal));
    final String subtitle = grand > 0
        ? 'مجموع ما سبّحتَه: ${arabicDigits(grand)}'
        : 'تسبيح حر بعدّاد هادئ: ٣٣ أو ١٠٠ أو بلا حد';
    return SmoothSurface(
      key: const ValueKey<String>('adhkar-card-sebha'),
      onTap: onTap,
      elevated: true,
      color: palette.emeraldSoft,
      borderColor: palette.emerald.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      semanticLabel: 'السبحة النبوية الذكية. $subtitle',
      child: Row(
        children: <Widget>[
          _IconTile(
            icon: Icons.donut_large_rounded,
            background: palette.surface,
            foreground: palette.emeraldText,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'السبحة النبوية الذكية',
                  style: text.titleMedium?.copyWith(
                    color: palette.emeraldText,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  key: const ValueKey<String>('adhkar-card-sebha-subtitle'),
                  style: text.bodySmall?.copyWith(color: palette.emeraldText, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// مربع الأيقونة بحواف ناعمة.
class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.background, required this.foreground});

  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: background,
        shape: AppShapes.rounded(AppShapes.radiusSmall),
      ),
      child: SizedBox.square(
        dimension: 52,
        child: Icon(icon, size: 28, color: foreground),
      ),
    );
  }
}

/// دائرة صغيرة بعدد البطاقات.
class _CountBadge extends StatelessWidget {
  const _CountBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: palette.surfaceMuted,
        shape: AppShapes.rounded(AppShapes.radiusSmall, side: BorderSide(color: palette.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: AppTypography.ui(color: palette.inkSoft, fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
