// بطاقة الفاصل بين قسمين من الكتاب على مسار المتون (Milestone Divider Banner).
//
// يضم المسار خمسين محطة متصلة، فيظن القارئ أنها كتاب واحد. هذه البطاقة العريضة تقع
// بين آخر حديث من قسم وأول حديث من القسم التالي (بين ٤٢ و٤٣): في نصفها الأعلى
// انتهاء القسم الأول بكتابه ومؤلفه ونطاق أحاديثه، وفي نصفها الأسفل بداية القسم
// الثاني بكتابه ومؤلفه ونطاق أحاديثه ووصفه. نصّا القسمين يأتيان من بيانات المنهج
// (CurriculumSection) لا من الكود، فيتغيران بتغيّر الملف وحده.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../../hadith/data/models/models.dart';
import '../../domain/journey_snapshot.dart';

/// بطاقة فاصل القسمين.
class SectionDividerBanner extends StatelessWidget {
  const SectionDividerBanner({super.key, required this.divider});

  /// الفاصل.
  final SectionDivider divider;

  static const double _padding = 20;
  static const double _bodySize = 15;
  static const double _bodyHeight = 1.8;

  /// حرف الترتيب في «نهاية القسم الأول».
  static String ordinal(int index) {
    const List<String> names = <String>[
      'الأول',
      'الثاني',
      'الثالث',
      'الرابع',
      'الخامس',
      'السادس',
      'السابع',
      'الثامن',
      'التاسع',
      'العاشر',
    ];
    return index < names.length ? names[index] : '${index + 1}';
  }

  /// ارتفاع تقديري للبطاقة من طول النصين وعرض المسار وتكبير الخط؛ يحسبه المسار قبل
  /// الرسم ليحجز لها موضعها بين العقدتين.
  static double estimateHeight({
    required SectionDivider divider,
    required double width,
    required double textScale,
  }) {
    final double scale = textScale < 1 ? 1 : (textScale > 1.3 ? 1.3 : textScale);
    final double inner = math.max(120.0, width - 32 - _padding * 2);
    final double charsPerLine = inner / (_bodySize * 0.58 * scale);
    int lines(String text) => (text.length / charsPerLine).ceil().clamp(1, 12).toInt();
    final double text = (lines(divider.endingLine) + lines(divider.startingLine)) * _bodySize * _bodyHeight * scale;
    // الزخرفة والعنوانان والمسافات والحشوة.
    const double chrome = 40 + 34 + 2 * 26 + 18 + 22;
    return chrome * scale + text;
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final String endingLabel = 'نهاية القسم ${ordinal(divider.index)}';
    final String startingLabel = 'بداية القسم ${ordinal(divider.index + 1)}';
    return Semantics(
      container: true,
      header: true,
      label: '$endingLabel: ${divider.endingLine}. $startingLabel: ${divider.startingLine}',
      child: ExcludeSemantics(
        child: SmoothSurface(
          key: ValueKey<String>('section-divider-${divider.index}'),
          elevated: true,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[palette.amberSoft, palette.surface],
          ),
          borderColor: palette.amber,
          borderWidth: 1.4,
          padding: const EdgeInsets.all(_padding),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double inner = constraints.maxWidth.isFinite ? constraints.maxWidth : 280;
              // إن ضاق الارتفاع (خطوط واسعة جداً) انكمش المحتوى بدل أن يفيض.
              return FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: inner,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _Ornament(palette: palette, icon: Icons.auto_stories_rounded),
                      const SizedBox(height: 12),
                      _SectionLine(
                        labelKey: ValueKey<String>('section-divider-ending-label-${divider.index}'),
                        textKey: ValueKey<String>('section-divider-ending-${divider.index}'),
                        icon: Icons.check_circle_rounded,
                        label: endingLabel,
                        labelColor: palette.emeraldText,
                        section: divider.ending,
                        line: divider.endingLine,
                      ),
                      const SizedBox(height: 10),
                      _Ornament(palette: palette, icon: Icons.keyboard_double_arrow_down_rounded, compact: true),
                      const SizedBox(height: 10),
                      _SectionLine(
                        labelKey: ValueKey<String>('section-divider-starting-label-${divider.index}'),
                        textKey: ValueKey<String>('section-divider-starting-${divider.index}'),
                        icon: Icons.flag_rounded,
                        label: startingLabel,
                        labelColor: palette.amberText,
                        section: divider.starting,
                        line: divider.startingLine,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// سطر قسم: وسم صغير، ثم الجملة كاملة يبرز فيها عنوان القسم بخط تراثي.
class _SectionLine extends StatelessWidget {
  const _SectionLine({
    required this.labelKey,
    required this.textKey,
    required this.icon,
    required this.label,
    required this.labelColor,
    required this.section,
    required this.line,
  });

  final Key labelKey;
  final Key textKey;
  final IconData icon;
  final String label;
  final Color labelColor;
  final CurriculumSection section;
  final String line;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final String title = section.title;
    final String rest = line.startsWith(title) ? line.substring(title.length) : line;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 18, color: labelColor),
            const SizedBox(width: 6),
            // يلتف الوسم على سطرين عند أكبر الخطوط بدل أن يفيض الصف.
            Flexible(
              child: Text(
                label,
                key: labelKey,
                textAlign: TextAlign.center,
                style: AppTypography.ui(color: labelColor, fontSize: 13, fontWeight: FontWeight.w700, height: 1.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            children: <InlineSpan>[
              TextSpan(
                text: title,
                style: AppTypography.heritageTitle(color: palette.ink, fontSize: 20),
              ),
              TextSpan(text: rest),
            ],
          ),
          key: textKey,
          textAlign: TextAlign.center,
          style: AppTypography.ui(
            color: palette.ink,
            fontSize: SectionDividerBanner._bodySize,
            height: SectionDividerBanner._bodyHeight,
          ),
        ),
      ],
    );
  }
}

/// زخرفة أفقية: خط، ثم أيقونة في دائرة، ثم خط.
class _Ornament extends StatelessWidget {
  const _Ornament({required this.palette, required this.icon, this.compact = false});

  final AppPalette palette;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double size = compact ? 18 : 24;
    final Widget rule = Expanded(
      child: Container(height: 1.2, color: palette.amber.withValues(alpha: 0.55)),
    );
    return Row(
      children: <Widget>[
        rule,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Icon(icon, size: size, color: palette.amberText),
        ),
        rule,
      ],
    );
  }
}
