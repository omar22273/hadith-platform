// الطبقة الثانية في شاشة المحطة: «الرواية التاريخية المطولة».
//
// فصول قرائية منسابة، كل فصل مقاطعُ منقولة حرفياً من الكتب المثبتة (سيرة ابن هشام
// وما معها) بخط تراثي يتبع «حجم خط المتن» في الإعدادات، وتحت كل مقطع شارة بمصدره
// وصفحته تفتح ورقة بيانات النسخة المنقول عنها. ولا يُضاف هنا نص من خارج ملف
// البيانات: لا رواية تُولَّد ولا تُستكمل من الذاكرة.
//
// الرأس والفصول والمقاطع عناصر منفصلة كي تُركَّب في قائمة الشاشة العمودية فتُبنى
// عند الوصول إليها لا دفعة واحدة.

import 'package:flutter/material.dart';

import '../../../../core/content/citation.dart';
import '../../../../core/content/models/source_catalog.dart';
import '../../../../core/content/models/source_ref.dart';
import '../../../../core/text/arabic_digits.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_sheet.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../data/models/seerah_station.dart';
import 'seerah_labels.dart';

/// عنوان الطبقة الثانية.
const String seerahReadingTitle = 'الرواية التاريخية المطولة';

/// رأس الطبقة الثانية: يطوي الفصول ويفتحها.
class SeerahReadingHeader extends StatelessWidget {
  const SeerahReadingHeader({
    super.key,
    required this.station,
    required this.open,
    required this.onToggle,
  });

  /// المحطة.
  final SeerahStationModel station;

  /// هل الفصول مفتوحة.
  final bool open;

  /// طي الفصول أو فتحها.
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final String counts = '${chaptersLabel(station.chapters.length)} · '
        '${passagesLabel(station.passageCount)} حرفياً من المصادر المثبتة';
    return SmoothSurface(
      key: const ValueKey<String>('station-reading'),
      onTap: onToggle,
      semanticLabel: '$seerahReadingTitle، $counts، ${open ? 'مفتوحة' : 'مطوية'}',
      elevated: true,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 10, 12),
      child: Row(
        children: <Widget>[
          Icon(Icons.auto_stories_rounded, color: palette.amberText),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  seerahReadingTitle,
                  style: AppTypography.heritageTitle(color: palette.ink, fontSize: 22),
                ),
                Text(
                  counts,
                  style: text.labelSmall?.copyWith(color: palette.inkSoft, height: 1.6),
                ),
              ],
            ),
          ),
          Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: palette.inkSoft),
        ],
      ),
    );
  }
}

/// عنوان فصل: رقمه من عدد الفصول وعنوانه التحريري.
class SeerahChapterHeading extends StatelessWidget {
  const SeerahChapterHeading({
    super.key,
    required this.chapter,
    required this.number,
    required this.total,
  });

  /// الفصل.
  final SeerahChapter chapter;

  /// رقمه (من ١).
  final int number;

  /// عدد فصول المحطة.
  final int total;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'الفصل ${arabicDigits(number)} من ${arabicDigits(total)}',
            style: text.labelMedium?.copyWith(color: palette.amberText, fontWeight: FontWeight.w600),
          ),
          Text(
            chapter.title,
            style: AppTypography.heritageTitle(color: palette.ink, fontSize: 24),
          ),
        ],
      ),
    );
  }
}

/// مقطع حرفي واحد وشارة مصدره وصفحته تحته.
class SeerahPassageView extends StatelessWidget {
  const SeerahPassageView({
    super.key,
    required this.id,
    required this.passage,
    required this.sources,
  });

  /// معرّف المقطع في الشاشة («معرّف الفصل-رقم المقطع»)، تُشتق منه مفاتيح نصه وشارته.
  final String id;

  /// المقطع: quote نص الكتاب، وlocator الجزء والصفحة أو رقم الحديث.
  final SourceRef passage;

  /// فهرس المصادر.
  final SourceCatalog? sources;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final SourceWork? work = sources?.byId(passage.sourceId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            border: BorderDirectional(
              start: BorderSide(color: palette.amber.withValues(alpha: 0.55), width: 3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 14),
            child: SelectableText(
              passage.quote ?? '',
              key: ValueKey<String>('passage-$id'),
              textAlign: TextAlign.justify,
              style: AppTypography.narrativeOf(context, color: palette.ink, fontSize: 21),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: _SourceBadge(badgeKey: ValueKey<String>('passage-badge-$id'), passage: passage, work: work),
        ),
      ],
    );
  }
}

/// شارة المصدر والصفحة؛ لمسها يفتح ورقة بيانات النسخة.
class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.badgeKey, required this.passage, required this.work});

  final Key badgeKey;
  final SourceRef passage;
  final SourceWork? work;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final String citation = formatCitation(work, passage);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Center(
        widthFactor: 1,
        child: SmoothSurface(
          key: badgeKey,
          onTap: () => showSmoothSheet<void>(
            context: context,
            builder: (BuildContext sheetContext) => _SourceSheet(passage: passage, work: work),
          ),
          semanticLabel: 'مصدر المقطع: $citation',
          color: palette.surfaceMuted,
          borderColor: palette.line,
          radius: AppShapes.radiusSmall,
          padding: const EdgeInsetsDirectional.fromSTEB(10, 5, 12, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.menu_book_rounded, size: 16, color: palette.amberText),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  citation,
                  style: text.labelMedium?.copyWith(color: palette.amberText, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ورقة بيانات النسخة المنقول عنها المقطع.
class _SourceSheet extends StatelessWidget {
  const _SourceSheet({required this.passage, required this.work});

  final SourceRef passage;
  final SourceWork? work;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final SourceWork? source = work;
    final SourceEdition? edition = source?.edition;
    final String? editor = edition?.editor;
    final String? publisher = edition?.publisher;
    final String? printing = edition?.printing;
    final int? death = source?.authorDeathHijri;
    final List<String> lines = <String>[
      if (source != null) death == null ? source.author : '${source.author} (ت ${arabicDigits(death)}هـ)',
      if (editor != null) 'تحقيق: $editor',
      if (publisher != null) 'الناشر: $publisher',
      if (printing != null) 'الطبعة: $printing',
      if (source != null) 'النسخة الرقمية: ${source.digital.provider}',
    ];
    return Column(
      key: const ValueKey<String>('passage-source-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          source?.title ?? passage.sourceId,
          style: AppTypography.heritageTitle(color: palette.ink, fontSize: 28),
        ),
        const SizedBox(height: 4),
        Text(
          formatCitation(source, passage),
          style: text.titleSmall?.copyWith(color: palette.amberText, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        for (final String line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(line, style: text.bodyMedium?.copyWith(color: palette.ink, height: 1.7)),
          ),
        const SizedBox(height: 10),
        Text(
          'نص المقطع منقول بلفظه من هذه النسخة، وأُزيلت منه علامات بنية الملف الرقمي وحدها.',
          style: text.labelMedium?.copyWith(color: palette.inkSoft, height: 1.8),
        ),
      ],
    );
  }
}

/// رأس قسم «شواهد المشاهد الثلاثة»: يطوي الشواهد الحرفية التي تستند إليها طبقة المعايشة ويفتحها.
class SeerahEvidenceHeader extends StatelessWidget {
  const SeerahEvidenceHeader({super.key, required this.open, required this.onToggle});

  /// هل الشواهد مفتوحة.
  final bool open;

  /// طي الشواهد أو فتحها.
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return SmoothSurface(
      key: const ValueKey<String>('station-evidence'),
      onTap: onToggle,
      semanticLabel: 'شواهد المشاهد الثلاثة، ${open ? 'مفتوحة' : 'مطوية'}',
      color: palette.surfaceMuted,
      borderColor: palette.line,
      radius: AppShapes.radiusMedium,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 10, 10),
      child: Row(
        children: <Widget>[
          Icon(Icons.format_quote_rounded, color: palette.amberText),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'شواهد المشاهد الثلاثة',
                  style: AppTypography.heritageTitle(color: palette.ink, fontSize: 20),
                ),
                Text(
                  'النصوص المصدرية التي صِيغ منها المشهد والمأزق والقرار',
                  style: text.labelSmall?.copyWith(color: palette.inkSoft, height: 1.6),
                ),
              ],
            ),
          ),
          Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: palette.inkSoft),
        ],
      ),
    );
  }
}

/// عنوان مشهد وتحته شواهده الحرفية.
class SeerahSceneEvidenceBlock extends StatelessWidget {
  const SeerahSceneEvidenceBlock({
    super.key,
    required this.scene,
    required this.evidence,
    required this.builder,
  });

  /// المشهد.
  final SeerahScene scene;

  /// شواهده.
  final List<SeerahEvidence> evidence;

  /// يبني بطاقة الشاهد الواحد (الصفحة تمرر SourceQuoteTile).
  final Widget Function(SeerahEvidence evidence) builder;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Column(
      key: ValueKey<String>('evidence-scene-${scene.wire}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(sceneIcon(scene), size: 20, color: palette.amberText),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                sceneTitle(scene),
                style: AppTypography.heritageTitle(color: palette.ink, fontSize: 21),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final SeerahEvidence item in evidence) ...<Widget>[
          builder(item),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
