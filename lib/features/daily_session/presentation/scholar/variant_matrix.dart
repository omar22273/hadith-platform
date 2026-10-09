// مصفوفة مقارنة الروايات: كل رواية بنصها من مصدرها، وتظليل ألفاظها التي لا
// يقابلها لفظ في المتن المعروض، مع الفروق الموثقة بالنص.

import 'package:flutter/material.dart';

import '../../../../core/text/arabic_digits.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../../hadith/data/models/models.dart';
import '../../../hadith/domain/hadith_bundle.dart';
import '../../domain/variant_diff.dart';

/// مصفوفة الروايات.
class VariantMatrix extends StatelessWidget {
  const VariantMatrix({super.key, required this.bundle});

  /// الحديث وفهارسه.
  final HadithBundle bundle;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final List<NarrationVariant> variants = bundle.hadith.scholar.variants;
    if (variants.isEmpty) {
      return Center(
        child: Text('لا روايات مقارنة لهذا الحديث بعد.', style: text.bodyMedium),
      );
    }
    final String base = bundle.hadith.matn.fullText;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        Row(
          children: <Widget>[
            DecoratedBox(
              decoration: ShapeDecoration(
                color: palette.amberSoft,
                shape: AppShapes.rounded(6, side: BorderSide(color: palette.amber.withValues(alpha: 0.5))),
              ),
              child: const SizedBox(width: 22, height: 14),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'المظلَّل: لفظ في الرواية لا يقابله لفظ في المتن المعروض (المقارنة على الرسم دون الحركات).',
                style: text.labelSmall?.copyWith(color: palette.inkSoft),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final NarrationVariant variant in variants) ...<Widget>[
          _VariantCard(variant: variant, bundle: bundle, base: base),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _VariantCard extends StatelessWidget {
  const _VariantCard({required this.variant, required this.bundle, required this.base});

  final NarrationVariant variant;
  final HadithBundle bundle;
  final String base;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final List<DiffWord> words = diffVariant(variantText: variant.matnText, baseText: base);
    final TextStyle style = AppTypography.matnOf(context, color: palette.ink, fontSize: 20).copyWith(height: 2.1);
    final String companion =
        bundle.narrators.byId(variant.companionNarratorId)?.displayName ?? variant.companionNarratorId;
    final String relation = variant.relation == VariantRelation.sameCompanion
        ? 'رواية عن الصحابي نفسه'
        : 'شاهد من حديث صحابي آخر';
    return SmoothSurface(
      elevated: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '${bundle.sourceTitle(variant.sourceId)} · رقم ${arabicDigits(variant.hadithNumber)}',
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              SoftChip(label: relation, icon: Icons.compare_arrows_rounded),
              SoftChip(label: companion, icon: Icons.person_rounded),
            ],
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                for (int i = 0; i < words.length; i++) ...<InlineSpan>[
                  if (i > 0) TextSpan(text: ' ', style: style),
                  TextSpan(
                    text: words[i].text,
                    style: words[i].shared
                        ? style
                        : style.copyWith(
                            backgroundColor: palette.amberSoft,
                            color: palette.amberText,
                          ),
                  ),
                ],
              ],
            ),
            textAlign: TextAlign.justify,
          ),
          if (variant.notes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            for (final String note in variant.notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Icon(Icons.circle, size: 6, color: palette.amberText),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(note, style: text.bodyMedium?.copyWith(height: 1.8))),
                  ],
                ),
              ),
          ],
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                'النص الكامل بإسناده',
                style: text.labelLarge?.copyWith(color: palette.amberText),
              ),
              children: <Widget>[
                SelectableText(
                  variant.fullText,
                  style: AppTypography.athar(color: palette.ink, fontSize: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
