// التخريج والتوثيق: مواضع الحديث، وعبارة المصنف بنصها، وأحكام الأئمة منقولة
// فقط، وحالة المراجعة العلمية، وسجل تعديلات الضبط بمستنداتها.

import 'package:flutter/material.dart';

import '../../../../core/text/arabic_digits.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../../hadith/data/models/models.dart';
import '../../../hadith/domain/hadith_bundle.dart';
import '../../../hadith/presentation/widgets/source_quote_tile.dart';

/// لوحة التخريج.
class TakhrijPanel extends StatelessWidget {
  const TakhrijPanel({super.key, required this.bundle, this.scrollable = true});

  /// الحديث وفهارسه.
  final HadithBundle bundle;

  /// هل اللوحة قائمة تمرير مستقلة.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final HadithDailyModel hadith = bundle.hadith;
    final Takhrij takhrij = hadith.matn.takhrij;
    final CompilerStatement? statement = takhrij.compilerStatement;
    final ReviewInfo review = hadith.review;
    final List<Widget> children = <Widget>[
      const SectionEyebrow('مواضع الحديث', icon: Icons.menu_book_rounded),
      const SizedBox(height: 8),
      for (final TakhrijReference reference in takhrij.references)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: SmoothSurface(
            color: palette.surfaceMuted,
            borderColor: palette.line,
            radius: AppShapes.radiusMedium,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    bundle.sourceTitle(reference.sourceId),
                    style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  'رقم ${arabicDigits(reference.hadithNumber)}',
                  style: text.titleSmall?.copyWith(color: palette.amberText),
                ),
              ],
            ),
          ),
        ),
      if (statement != null) ...<Widget>[
        const SizedBox(height: 12),
        const SectionEyebrow('عبارة المصنف', icon: Icons.format_quote_rounded),
        const SizedBox(height: 8),
        SmoothSurface(
          color: palette.amberSoft,
          radius: AppShapes.radiusMedium,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SelectableText(
                statement.text,
                style: AppTypography.athar(color: palette.ink, fontSize: 19),
              ),
              Text(
                bundle.sourceTitle(statement.sourceId),
                style: text.labelSmall?.copyWith(color: palette.inkSoft),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 12),
      const SectionEyebrow('الحكم على الحديث', icon: Icons.verified_outlined),
      const SizedBox(height: 8),
      if (takhrij.gradings.isEmpty)
        Text(
          'لا تعرض المنصة حكماً إلا منقولاً بنصه عن إمام مع موضعه، ولم يُضف حكم منقول لهذا الحديث بعد.',
          style: text.bodyMedium?.copyWith(color: palette.inkSoft, height: 1.8),
        )
      else
        for (final Grading grading in takhrij.gradings) ...<Widget>[
          Text(
            '${grading.gradedBy}: ${grading.grade}',
            style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          SourceQuoteTile(reference: grading.source, source: bundle.sources.byId(grading.source.sourceId)),
          const SizedBox(height: 8),
        ],
      const SizedBox(height: 12),
      const SectionEyebrow('حالة المادة', icon: Icons.fact_check_outlined),
      const SizedBox(height: 8),
      SoftChip(
        label: _reviewLabel(review.status),
        icon: review.status == ReviewStatus.approved ? Icons.verified_outlined : Icons.timer_outlined,
        background: review.status == ReviewStatus.approved ? palette.emeraldSoft : palette.amberSoft,
        foreground: review.status == ReviewStatus.approved ? palette.emeraldText : palette.amberText,
      ),
      for (final String note in review.notes)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(note, style: text.bodySmall?.copyWith(color: palette.inkSoft, height: 1.7)),
        ),
      const SizedBox(height: 12),
      _EditsSection(bundle: bundle),
    ];
    if (!scrollable) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: children);
  }

  static String _reviewLabel(ReviewStatus status) {
    switch (status) {
      case ReviewStatus.pendingScholarlyReview:
        return 'قيد المراجعة العلمية';
      case ReviewStatus.approved:
        return 'معتمد بعد المراجعة';
      case ReviewStatus.changesRequested:
        return 'طُلبت تعديلات';
    }
  }
}

class _EditsSection extends StatelessWidget {
  const _EditsSection({required this.bundle});

  final HadithBundle bundle;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final Provenance provenance = bundle.hadith.provenance;
    final List<VocalizationEdit> edits = provenance.vocalizationEdits;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: SectionEyebrow(
          'سجل الضبط: ${arabicDigits(edits.length)} تعديل موثق',
          icon: Icons.history_edu_rounded,
        ),
        children: <Widget>[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'مصدر المتن: ${bundle.citation(provenance.matnSource)}',
              style: text.labelMedium?.copyWith(color: palette.inkSoft),
            ),
          ),
          const SizedBox(height: 8),
          for (final VocalizationEdit edit in edits)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SmoothSurface(
                color: palette.surfaceMuted,
                borderColor: palette.line,
                radius: AppShapes.radiusMedium,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text.rich(
                      TextSpan(
                        style: AppTypography.matn(color: palette.ink, fontSize: 21).copyWith(height: 1.8),
                        children: <InlineSpan>[
                          TextSpan(text: edit.before, style: TextStyle(color: palette.inkSoft)),
                          const TextSpan(text: '  ←  '),
                          TextSpan(
                            text: edit.after,
                            style: TextStyle(color: palette.emeraldText, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${_ruleLabel(edit.rule)} · ${edit.method == EditMethod.alignedSource ? 'من الكلمة المقابلة في المصدر المشكول' : 'قاعدة إملائية ثابتة'}'
                      '${edit.source == null ? '' : ' · ${bundle.citation(edit.source!)}'}',
                      style: text.labelSmall?.copyWith(color: palette.inkSoft),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _ruleLabel(LintRule rule) {
    switch (rule) {
      case LintRule.missingFinalVowel:
        return 'آخر الكلمة بلا حركة';
      case LintRule.sukunBeforeWasl:
        return 'سكون قبل همزة وصل';
      case LintRule.fathaOnWaslAlif:
        return 'فتحة على ألف وصل';
      case LintRule.hamzaBelowWithoutKasra:
        return 'همزة تحت الألف بلا كسرة';
    }
  }
}
