// بطاقة الراوي بلمسة واحدة: الطبقة وسنة الوفاة ومرتبته في الجرح والتعديل،
// كلها بنصها من تقريب التهذيب، مع نص الترجمة كاملاً.

import 'package:flutter/material.dart';

import '../../../../core/text/arabic_digits.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../../hadith/data/models/models.dart';
import '../../../hadith/domain/hadith_bundle.dart';

/// صفة العلم في الإسناد.
String narratorCategoryLabel(NarratorCategory category) {
  switch (category) {
    case NarratorCategory.prophet:
      return 'النبي ﷺ';
    case NarratorCategory.companion:
      return 'صحابي';
    case NarratorCategory.narrator:
      return 'راوٍ';
    case NarratorCategory.compiler:
      return 'صاحب الكتاب';
  }
}

/// بطاقة الراوي.
class NarratorCard extends StatelessWidget {
  const NarratorCard({super.key, required this.narrator, required this.bundle});

  /// الترجمة.
  final NarratorProfile narrator;

  /// الفهارس.
  final HadithBundle bundle;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final RijalEntry? entry = narrator.entry;
    final DeathRecord? death = narrator.death;
    final List<(String, String)> rows = <(String, String)>[
      ('الصفة', narratorCategoryLabel(narrator.category)),
      if (narrator.tabaqa != null) ('الطبقة', narrator.tabaqa!.text),
      if (narrator.gradeText != null) ('المرتبة', narrator.gradeText!),
      if (death != null)
        (
          'الوفاة',
          death.yearHijri == null
              ? death.text
              : '${death.text} (${arabicDigits(death.yearHijri!)}هـ'
                  '${death.derivation == DeathYearDerivation.taqribCenturyRule ? '، المئة من قاعدة الطبقات' : ''})',
        ),
      if (narrator.sigla != null) ('من أخرج له', narrator.sigla!),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          narrator.displayName,
          style: AppTypography.heritageTitle(color: palette.ink, fontSize: 28),
        ),
        const SizedBox(height: 10),
        SmoothSurface(
          color: palette.surfaceMuted,
          borderColor: palette.line,
          radius: AppShapes.radiusMedium,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < rows.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 96,
                        child: Text(
                          rows[i].$1,
                          style: text.labelMedium?.copyWith(
                            color: palette.inkSoft,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          rows[i].$2,
                          style: AppTypography.athar(color: palette.ink, fontSize: 17),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (entry != null) ...<Widget>[
          const SizedBox(height: 14),
          const SectionEyebrow('نص الترجمة', icon: Icons.person_rounded),
          const SizedBox(height: 6),
          SelectableText(
            entry.text,
            style: AppTypography.athar(color: palette.ink, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            '${bundle.sourceTitle(entry.sourceId)}${entry.locator == null ? '' : ' · ${arabicDigits(entry.locator!)}'}',
            style: text.labelSmall?.copyWith(color: palette.inkSoft),
          ),
        ],
      ],
    );
  }
}
