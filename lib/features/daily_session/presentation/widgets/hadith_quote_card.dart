// بطاقة الاقتباس التي تُصدَّر صورةً للمشاركة: خلفية كتان عاجي في السمة
// النهارية أو كحلي فاخر في الداكنة، يعلوها رقم الحديث وتخريجه، ثم المتن المشكول
// حرفاً بحرف بخط النسخ التراثي (Amiri)، وتذييل باسم المنصة.
//
// عرض البطاقة ثابت وحجم الخط غير متأثر بتكبير النظام، فتخرج الصورة بالمقاس
// نفسه على كل الأجهزة. لا شيء يُضاف إلى المتن ولا تُولَّد عبارة من خارج الملف.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/text/arabic_digits.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../hadith/domain/hadith_bundle.dart';

/// بطاقة الحديث.
class HadithQuoteCard extends StatelessWidget {
  const HadithQuoteCard({super.key, required this.bundle});

  /// الحديث وفهارسه.
  final HadithBundle bundle;

  /// عرض البطاقة المنطقي ثابت.
  static const double width = 360;

  /// اسم المنصة في التذييل.
  static const String platformName = 'منصة الحديث النبوي';

  /// المتن الطويل يُضبط الهوامش بدل التوسيط.
  static const int justifyThreshold = 240;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color gold = dark ? palette.amberText : palette.amber;
    final String matn = bundle.hadith.matn.fullText;
    final int number = bundle.hadith.collection.numberInCollection;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox(
        width: width,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[palette.paper, palette.surfaceMuted],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: AppShapes.rounded(
                  AppShapes.radiusMedium,
                  side: BorderSide(color: gold.withValues(alpha: 0.7), width: 1.4),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      '${bundle.hadith.collection.title} · الحديث ${arabicDigits(number)}',
                      textAlign: TextAlign.center,
                      style: AppTypography.heritageTitle(color: palette.ink, fontSize: 21),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'التخريج: ${bundle.hadith.matn.takhrij.displayLabel}',
                      textAlign: TextAlign.center,
                      style: AppTypography.ui(color: palette.inkSoft, fontSize: 12.5, height: 1.6),
                    ),
                    const SizedBox(height: 14),
                    _Ornament(color: gold),
                    const SizedBox(height: 14),
                    Text(
                      matn,
                      textAlign: matn.length > justifyThreshold ? TextAlign.justify : TextAlign.center,
                      style: AppTypography.matn(color: palette.ink, fontSize: 23).copyWith(height: 2.1),
                    ),
                    const SizedBox(height: 14),
                    _Ornament(color: gold),
                    const SizedBox(height: 12),
                    for (final reference in bundle.hadith.matn.takhrij.references)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '${bundle.sourceTitle(reference.sourceId)} · رقم ${arabicDigits(reference.hadithNumber)}',
                          textAlign: TextAlign.center,
                          style: AppTypography.ui(color: palette.inkSoft, fontSize: 12, height: 1.6),
                        ),
                      ),
                    const SizedBox(height: 14),
                    Text(
                      platformName,
                      textAlign: TextAlign.center,
                      style: AppTypography.heritageTitle(color: gold, fontSize: 17),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// فاصل زخرفي: خط ومعيّن ذهبي وخط.
class _Ornament extends StatelessWidget {
  const _Ornament({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final Widget line = Expanded(child: SizedBox(height: 1, child: ColoredBox(color: color.withValues(alpha: 0.5))));
    return Row(
      children: <Widget>[
        line,
        const SizedBox(width: 10),
        Transform.rotate(
          angle: math.pi / 4,
          child: SizedBox(width: 7, height: 7, child: ColoredBox(color: color)),
        ),
        const SizedBox(width: 10),
        line,
      ],
    );
  }
}
