// ورقة معلومات الذكر: التخريج، والفضل النبوي، والمصدر. كل ما فيها منقول من
// ملف البيانات: الإحالات من شواهد الذكر، والفضل عبارة حرفية من أحد شواهده تغيب
// عن الورقة إن لم يكن للذكر فضل منصوص، فلا يُكتب هنا لفظ من خارج الملف.

import 'package:flutter/material.dart';

import '../../../../core/content/citation.dart';
import '../../../../core/content/models/source_catalog.dart';
import '../../../../core/content/models/source_ref.dart';
import '../../../../core/content/widgets/source_quote_tile.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_sheet.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../data/models/adhkar.dart';

/// يفتح ورقة معلومات الذكر.
Future<void> showDhikrInfoSheet({
  required BuildContext context,
  required DhikrItem item,
  required SourceCatalog? sources,
}) {
  return showSmoothSheet<void>(
    context: context,
    builder: (BuildContext sheetContext) => DhikrInfoSheet(item: item, sources: sources),
  );
}

/// محتوى ورقة معلومات الذكر.
class DhikrInfoSheet extends StatelessWidget {
  const DhikrInfoSheet({super.key, required this.item, required this.sources});

  /// الذكر.
  final DhikrItem item;

  /// فهرس المصادر.
  final SourceCatalog? sources;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final String? virtue = item.virtue?.trim();
    final List<SourceRef> citations = _distinctByCitation(item.evidence, sources);
    return Column(
      key: const ValueKey<String>('dhikr-info-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          item.title,
          textAlign: TextAlign.center,
          style: AppTypography.heritageTitle(color: palette.ink, fontSize: 26),
        ),
        const SizedBox(height: 18),
        const SectionEyebrow('التخريج', icon: Icons.fact_check_outlined),
        const SizedBox(height: 8),
        for (final SourceRef reference in citations) ...<Widget>[
          _TakhrijLine(reference: reference, source: sources?.byId(reference.sourceId)),
          const SizedBox(height: 6),
        ],
        if (virtue != null && virtue.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          const SectionEyebrow('الفضل النبوي', icon: Icons.auto_awesome_outlined),
          const SizedBox(height: 8),
          SmoothSurface(
            key: const ValueKey<String>('dhikr-info-virtue'),
            color: palette.emeraldSoft,
            borderColor: palette.emerald.withValues(alpha: 0.35),
            radius: AppShapes.radiusMedium,
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              '«$virtue»',
              textAlign: TextAlign.center,
              style: AppTypography.athar(color: palette.ink, fontSize: 21).copyWith(height: 2),
            ),
          ),
        ],
        const SizedBox(height: 14),
        SectionEyebrow(
          citations.length == 1 ? 'المصدر' : 'المصادر',
          icon: Icons.menu_book_outlined,
        ),
        const SizedBox(height: 8),
        for (final SourceRef reference in item.evidence) ...<Widget>[
          SourceQuoteTile(reference: reference, source: sources?.byId(reference.sourceId)),
          const SizedBox(height: 8),
        ],
        Text(
          'النصوص منقولة كما وردت في المصدر دون تغيير.',
          textAlign: TextAlign.center,
          style: text.labelSmall?.copyWith(color: palette.inkSoft),
        ),
      ],
    );
  }
}

/// شواهد الذكر بإحالات متمايزة: الحديث الواحد قد يحمل شاهدين (الذكر وفضله)
/// فتُذكر إحالته مرة واحدة في التخريج، وتبقى نصوصه كلها في قسم المصدر.
List<SourceRef> _distinctByCitation(List<SourceRef> evidence, SourceCatalog? sources) {
  final Set<String> seen = <String>{};
  final List<SourceRef> distinct = <SourceRef>[];
  for (final SourceRef reference in evidence) {
    if (seen.add(formatCitation(sources?.byId(reference.sourceId), reference))) {
      distinct.add(reference);
    }
  }
  return distinct;
}

/// سطر تخريج: الإحالة المقروءة، ومؤلف الكتاب.
class _TakhrijLine extends StatelessWidget {
  const _TakhrijLine({required this.reference, required this.source});

  final SourceRef reference;
  final SourceWork? source;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final String byline = formatSourceByline(source);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          formatCitation(source, reference),
          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (byline.isNotEmpty && byline != source?.title)
          Text(byline, style: text.labelMedium?.copyWith(color: palette.inkSoft)),
      ],
    );
  }
}
