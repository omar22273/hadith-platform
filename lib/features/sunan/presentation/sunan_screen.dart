// شاشة السنن النبوية المهجورة: شاشة مرجعية مستقلة عن مشغّل الأذكار، لا عدّاد فيها ولا تركيز.
//
// 1. الرأس: زر الرجوع، والعنوان، وعدد البطاقات المعروضة.
// 2. شريط التصفية العلوي: «الكل» ثم الأبواب الخمسة (الطهارة والصلاة، الطعام والشراب،
//    المنزل والخروج، النوم واللباس، المجالس والآداب)؛ يتمرر أفقياً فلا يفيض على الهاتف الضيق.
// 3. القائمة: بطاقة مستقلة لكل سنة: عنوانها، ووقتها وكيفيتها (عبارة حرفية من لفظ الحديث)،
//    والفضل النبوي إن نُصّ عليه، والدليل (نص الحديث مشكولاً بإحالته)، ودرجته المسجلة،
//    وتنبيه ظاهر إن كان دون الصحيح.
//
// الخط الأحمر: كل ما في البطاقة من نص نبوي يأتي من assets/data/sunan/sunan_mahjoorah.json وحده،
// وقد فُحص قبل العرض أن نص السنة جزء حرفي من أحد شواهدها (checkSunanCatalog).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/content/models/source_catalog.dart';
import '../../../core/content/source_catalog_provider.dart';
import '../../../core/content/widgets/source_quote_tile.dart';
import '../../../core/json/json_reader.dart';
import '../../../core/text/arabic_digits.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/ui/app_shapes.dart';
import '../../../core/ui/smooth_surface.dart';
import '../application/sunan_providers.dart';
import '../data/models/sunan.dart';
import '../domain/sunan_info.dart';
import '../domain/sunan_repository.dart';

/// شاشة السنن المهجورة.
class SunanScreen extends ConsumerStatefulWidget {
  const SunanScreen({super.key});

  @override
  ConsumerState<SunanScreen> createState() => _SunanScreenState();
}

class _SunanScreenState extends ConsumerState<SunanScreen> {
  /// الباب المختار في الشريط؛ null يعني «الكل».
  SunnahBab? _bab;

  void _select(SunnahBab? bab) {
    if (bab != _bab) {
      setState(() => _bab = bab);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SunanCatalog> catalog = ref.watch(sunanCatalogProvider);
    final Widget body;
    if (catalog.hasError) {
      body = _ErrorView(error: catalog.error!, onRetry: () => ref.invalidate(sunanCatalogProvider));
    } else if (catalog.value == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = _SunanBody(items: catalog.value!.itemsInOrder, bab: _bab, onBab: _select);
    }
    return Scaffold(
      key: const ValueKey<String>('sunan-screen'),
      body: SafeArea(child: body),
    );
  }
}

class _SunanBody extends ConsumerWidget {
  const _SunanBody({required this.items, required this.bab, required this.onBab});

  /// كل السنن بترتيبها.
  final List<SunnahItem> items;

  /// الباب المختار، أو null للكل.
  final SunnahBab? bab;
  final ValueChanged<SunnahBab?> onBab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final SourceCatalog? sources = ref.watch(sourceCatalogProvider).value;
    final List<SunnahItem> visible = filterSunan(items, bab);
    final String count = bab == null
        ? '${arabicDigits(items.length)} سنة بأدلتها'
        : '${arabicDigits(visible.length)} من ${arabicDigits(items.length)} سنة';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 16, 4),
          child: Row(
            children: <Widget>[
              IconButton(
                key: const ValueKey<String>('sunan-back'),
                tooltip: 'الرجوع إلى مركز الأذكار',
                onPressed: () => Navigator.of(context).maybePop(),
                color: palette.inkSoft,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      SunanInfo.title,
                      key: const ValueKey<String>('sunan-title'),
                      style: AppTypography.heritageTitle(color: palette.ink, fontSize: 26),
                    ),
                    Text(
                      count,
                      key: const ValueKey<String>('sunan-count'),
                      style: text.labelMedium?.copyWith(color: palette.inkSoft, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _FilterBar(selected: bab, onSelected: onBab),
        const SizedBox(height: 4),
        Expanded(
          child: ListView.separated(
            key: ValueKey<String>('sunan-list-${bab?.wire ?? 'all'}'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            itemCount: visible.length + 1,
            separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 12),
            itemBuilder: (BuildContext context, int index) {
              if (index == visible.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'النصوص منقولة كما وردت في المصدر دون تغيير، وبانتظار المراجعة العلمية.',
                    textAlign: TextAlign.center,
                    style: text.labelSmall?.copyWith(color: palette.inkSoft),
                  ),
                );
              }
              return _SunnahCard(item: visible[index], sources: sources);
            },
          ),
        ),
      ],
    );
  }
}

/// شريط التصفية العلوي: «الكل» ثم أبواب السنن؛ يتمرر أفقياً.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelected});

  final SunnahBab? selected;
  final ValueChanged<SunnahBab?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey<String>('sunan-filter-bar'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: <Widget>[
          _FilterChip(
            chipKey: const ValueKey<String>('sunan-filter-all'),
            label: SunanInfo.allLabel,
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final SunnahBab bab in SunnahBab.values) ...<Widget>[
            const SizedBox(width: 8),
            _FilterChip(
              chipKey: ValueKey<String>('sunan-filter-${bab.wire}'),
              label: bab.label,
              selected: selected == bab,
              onTap: () => onSelected(bab),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.chipKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key chipKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: SmoothSurface(
        key: chipKey,
        onTap: selected ? null : onTap,
        color: selected ? palette.amberSoft : palette.surfaceMuted,
        borderColor: selected ? palette.amber.withValues(alpha: 0.6) : palette.line,
        radius: AppShapes.radiusMedium,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        semanticLabel: label,
        child: Text(
          label,
          maxLines: 1,
          style: text.labelLarge?.copyWith(
            color: selected ? palette.amberText : palette.inkSoft,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// بطاقة سنة مستقلة.
class _SunnahCard extends StatelessWidget {
  const _SunnahCard({required this.item, required this.sources});

  final SunnahItem item;
  final SourceCatalog? sources;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final String? virtue = item.virtue?.trim();
    final String? caution = item.caution?.trim();
    final List<String> gradeLines = <String>[
      for (final String line in (item.grading ?? '').split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];
    return SmoothSurface(
      key: ValueKey<String>('sunnah-card-${item.id}'),
      elevated: true,
      borderColor: palette.line,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SoftChip(
              label: item.bab.label,
              background: palette.surfaceMuted,
              foreground: palette.inkSoft,
              borderColor: palette.line,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            key: ValueKey<String>('sunnah-title-${item.id}'),
            style: AppTypography.heritageTitle(color: palette.ink, fontSize: 24),
          ),
          if (caution != null && caution.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            SmoothSurface(
              key: ValueKey<String>('sunnah-caution-${item.id}'),
              color: palette.amberSoft,
              borderColor: palette.amber.withValues(alpha: 0.6),
              radius: AppShapes.radiusMedium,
              padding: const EdgeInsets.all(12),
              child: Text(
                caution,
                style: text.bodyMedium?.copyWith(color: palette.amberText, height: 1.7, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const SectionEyebrow('وقتها وكيفيتها', icon: Icons.schedule_rounded),
          const SizedBox(height: 6),
          SelectableText(
            item.text,
            key: ValueKey<String>('sunnah-text-${item.id}'),
            style: AppTypography.athar(color: palette.ink, fontSize: 22).copyWith(height: 2),
          ),
          if (virtue != null && virtue.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            const SectionEyebrow('الفضل النبوي', icon: Icons.auto_awesome_outlined),
            const SizedBox(height: 6),
            SmoothSurface(
              key: ValueKey<String>('sunnah-virtue-${item.id}'),
              color: palette.emeraldSoft,
              borderColor: palette.emerald.withValues(alpha: 0.35),
              radius: AppShapes.radiusMedium,
              padding: const EdgeInsets.all(14),
              child: SelectableText(
                '«$virtue»',
                textAlign: TextAlign.center,
                style: AppTypography.athar(color: palette.ink, fontSize: 20).copyWith(height: 2),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SectionEyebrow(item.evidence.length == 1 ? 'الدليل' : 'الأدلة', icon: Icons.menu_book_outlined),
          const SizedBox(height: 6),
          for (int i = 0; i < item.evidence.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 8),
            SourceQuoteTile(
              key: ValueKey<String>('sunnah-evidence-${item.id}-$i'),
              reference: item.evidence[i],
              source: sources?.byId(item.evidence[i].sourceId),
            ),
          ],
          if (gradeLines.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            const SectionEyebrow('الدرجة', icon: Icons.rule_rounded),
            const SizedBox(height: 6),
            Column(
              key: ValueKey<String>('sunnah-grading-${item.id}'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final String line in gradeLines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      arabicDigits(line),
                      style: text.bodySmall?.copyWith(color: palette.inkSoft, height: 1.7),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final String detail = switch (error) {
      SunanIntegrityException(:final List<String> issues) => issues.join('\n'),
      JsonParseException(:final String message) => message,
      _ => error.toString(),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.spa_outlined, size: 44, color: palette.inkSoft),
            const SizedBox(height: 12),
            Text('تعذّر تجهيز السنن', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'لم يُعرض شيء حتى لا تظهر سنة بلا دليلها الموثق.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: palette.inkSoft),
            ),
            const SizedBox(height: 10),
            SelectableText(
              detail,
              textAlign: TextAlign.center,
              style: text.labelSmall?.copyWith(color: palette.inkSoft),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const ValueKey<String>('sunan-error-back'),
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('الرجوع'),
            ),
          ],
        ),
      ),
    );
  }
}
