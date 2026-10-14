// ورقة «شرح الحديث 📖»: الشرح الميسر المنقول من «التحفة الربانية في شرح الأربعين النووية»
// بنصه، في ورقة سفلية قابلة للتمرير بخط واضح يكبّره المنزلق ويصغّره.
//
// - مفردات الحديث كما وردت في الكتاب، كل لفظة وبيانها.
// - ثم «ما يستفاد من الحديث» فائدةً فائدة.
// - ثم إحالة الكتاب وتنبيه بأن النص قيد المراجعة العلمية.
//
// لا يُضاف هنا نص من خارج ملف بيانات الحديث: لا شرح يُولَّد ولا يُستكمل من الذاكرة.

import 'package:flutter/material.dart';

import '../../../../core/text/arabic_digits.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/reading_size_bar.dart';
import '../../../../core/ui/smooth_sheet.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../../hadith/data/models/models.dart';
import '../../../hadith/domain/hadith_bundle.dart';

/// عنوان الزر والورقة.
const String sharhButtonLabel = 'شرح الحديث 📖';

/// مفتاح منزلق حجم الخط داخل الورقة.
const ValueKey<String> sharhFontSliderKey = ValueKey<String>('sharh-font-slider');

/// ينبّه القارئ بأن النص منقول من مسح ضوئي ولم تتم مراجعته بعد.
const String sharhReviewNotice =
    'نص الشرح منقول من الكتاب كما ورد، وأصله ملف ممسوح ضوئياً قيد المراجعة العلمية؛ فإن رأيت فيه خللاً فاعرضه على المطبوع.';

/// يفتح ورقة الشرح الميسر للحديث.
Future<void> showHadithSharhSheet(BuildContext context, HadithBundle bundle) {
  return showSmoothSheet<void>(
    context: context,
    builder: (BuildContext sheetContext) => HadithSharhView(bundle: bundle),
  );
}

/// محتوى الورقة.
class HadithSharhView extends StatelessWidget {
  const HadithSharhView({super.key, required this.bundle});

  /// الحديث وفهارسه.
  final HadithBundle bundle;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final HadithDailyModel hadith = bundle.hadith;
    final ConciseExplanation? explanation = hadith.conciseExplanation;
    if (explanation == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'شرح هذا الحديث يتاح في التحديث القادم.',
            style: text.bodyLarge?.copyWith(color: palette.inkSoft),
          ),
        ),
      );
    }
    return Column(
      key: const ValueKey<String>('sharh-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.menu_book_rounded, size: 24, color: palette.amberText),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'شرح الحديث',
                style: AppTypography.heritageTitle(color: palette.ink, fontSize: 28),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${hadith.title} · ${bundle.citation(explanation.source)}',
          style: text.bodyMedium?.copyWith(color: palette.inkSoft, height: 1.6),
        ),
        const SizedBox(height: 12),
        const ReadingSizeBar(sliderKey: sharhFontSliderKey),
        if (explanation.vocabulary.isNotEmpty) ...<Widget>[
          const SizedBox(height: 18),
          const SectionEyebrow('مفردات الحديث', icon: Icons.translate_rounded),
          const SizedBox(height: 8),
          _VocabularyList(terms: explanation.vocabulary),
        ],
        const SizedBox(height: 18),
        const SectionEyebrow('ما يستفاد من الحديث', icon: Icons.lightbulb_outline_rounded),
        const SizedBox(height: 8),
        _BenefitList(benefits: explanation.benefits),
        const SizedBox(height: 16),
        Text(
          sharhReviewNotice,
          style: text.bodySmall?.copyWith(color: palette.inkSoft, height: 1.7),
        ),
      ],
    );
  }
}

class _VocabularyList extends StatelessWidget {
  const _VocabularyList({required this.terms});

  final List<ExplanationTerm> terms;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return SmoothSurface(
      key: const ValueKey<String>('sharh-vocabulary'),
      color: palette.surface,
      borderColor: palette.line,
      radius: AppShapes.radiusMedium,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < terms.length; i++) ...<Widget>[
            if (i > 0) Divider(height: 22, color: palette.line),
            SelectableText(
              terms[i].term,
              style: AppTypography.narrativeOf(
                context,
                color: palette.amberText,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ).copyWith(height: 1.7),
            ),
            const SizedBox(height: 2),
            SelectableText(
              terms[i].explanation,
              textAlign: TextAlign.justify,
              style: AppTypography.narrativeOf(context, color: palette.ink, fontSize: 19),
            ),
          ],
        ],
      ),
    );
  }
}

class _BenefitList extends StatelessWidget {
  const _BenefitList({required this.benefits});

  final List<String> benefits;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return SmoothSurface(
      key: const ValueKey<String>('sharh-benefits'),
      color: palette.surface,
      borderColor: palette.line,
      radius: AppShapes.radiusMedium,
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < benefits.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: palette.amberSoft,
                      shape: AppShapes.rounded(AppShapes.radiusSmall),
                    ),
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: Center(
                        child: Text(
                          arabicDigits(i + 1),
                          style: text.labelLarge?.copyWith(
                            color: palette.amberText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SelectableText(
                    benefits[i],
                    textAlign: TextAlign.justify,
                    style: AppTypography.narrativeOf(context, color: palette.ink, fontSize: 20),
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
