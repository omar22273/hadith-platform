// بطاقات طبقة المعايشة والموقف في شاشة المحطة، وبطاقتا الجسر السردي:
//
// - الجسر: «ما سبق» (previous_link) و«في المحطة التالية» (next_hook).
// - التمهيد المشوق (hook) الذي يربط القارئ بالحدث.
// - المشهد الموجز في أربعة أسطر يُفتح كاملاً بزر.
// - مأزق الشورى والتحدي: المأزق بنصه وسؤال الشورى، وخياراته إن نصّ عليها الشاهد؛
//   فإن لم ينص فزر واحد لكشف القرار. لا يُخترع خيار من خارج ملف البيانات.
// - القرار النبوي ونتيجته مع شواهده، يظهر بعد الاختيار أو الكشف.
//
// كل نص هنا مقتصر على شواهد المحطة المنقولة بنصها، ولا حكم على اختيار القارئ.

import 'package:flutter/material.dart';

import '../../../../core/content/models/source_catalog.dart';
import '../../../../core/content/widgets/source_quote_tile.dart';
import '../../../../core/text/arabic_digits.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../../../core/ui/wide_action_button.dart';
import '../../data/models/seerah_station.dart';

/// عدد أسطر المشهد الموجز قبل فتحه كاملاً.
const int seerahBriefLines = 4;

/// عنوان بطاقة: أيقونة وعنوان تراثي.
class SeerahCardHeading extends StatelessWidget {
  const SeerahCardHeading({super.key, required this.icon, required this.title});

  /// الأيقونة.
  final IconData icon;

  /// العنوان.
  final String title;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Row(
      children: <Widget>[
        Icon(icon, color: palette.amberText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: AppTypography.heritageTitle(color: palette.ink, fontSize: 24),
          ),
        ),
      ],
    );
  }
}

/// بطاقة الجسر السردي بين محطتين.
class SeerahBridgeCard extends StatelessWidget {
  const SeerahBridgeCard({super.key, required this.icon, required this.label, required this.text});

  /// الأيقونة.
  final IconData icon;

  /// عنوان البطاقة الصغير.
  final String label;

  /// الجملة التحريرية المقتصرة على شواهد المحطتين.
  final String text;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return SmoothSurface(
      color: palette.surfaceMuted,
      borderColor: palette.line,
      radius: AppShapes.radiusMedium,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionEyebrow(label, icon: icon),
          const SizedBox(height: 6),
          Text(text, style: AppTypography.athar(color: palette.ink, fontSize: 19)),
        ],
      ),
    );
  }
}

/// التمهيد السردي المشوق.
class SeerahHookCard extends StatelessWidget {
  const SeerahHookCard({super.key, required this.text});

  /// نص التمهيد.
  final String text;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return SmoothSurface(
      key: const ValueKey<String>('station-hook'),
      gradient: LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: <Color>[palette.amberSoft, palette.surface],
      ),
      borderColor: palette.amber.withValues(alpha: 0.35),
      elevated: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SectionEyebrow('تمهيد', icon: Icons.auto_awesome_rounded),
          const SizedBox(height: 8),
          Text(text, style: AppTypography.athar(color: palette.ink, fontSize: 22)),
        ],
      ),
    );
  }
}

/// المشهد الموجز: وصف الموقف في أربعة أسطر، وزر لفتحه كاملاً إن زاد عنها.
class SeerahBriefScene extends StatefulWidget {
  const SeerahBriefScene({super.key, required this.text});

  /// وصف المشهد.
  final String text;

  @override
  State<SeerahBriefScene> createState() => _SeerahBriefSceneState();
}

class _SeerahBriefSceneState extends State<SeerahBriefScene> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextStyle style = AppTypography.athar(color: palette.ink, fontSize: 21);
    return SmoothSurface(
      key: const ValueKey<String>('station-brief'),
      elevated: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SeerahCardHeading(icon: Icons.wb_sunny_outlined, title: 'المشهد الموجز'),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final TextPainter probe = TextPainter(
                text: TextSpan(text: widget.text, style: style),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
                maxLines: seerahBriefLines,
              )..layout(maxWidth: constraints.maxWidth);
              final bool longer = probe.didExceedMaxLines;
              probe.dispose();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    widget.text,
                    key: const ValueKey<String>('station-brief-text'),
                    maxLines: _expanded ? null : seerahBriefLines,
                    overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: style,
                  ),
                  if (longer)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        key: const ValueKey<String>('station-brief-toggle'),
                        onPressed: () => setState(() => _expanded = !_expanded),
                        child: Text(_expanded ? 'طيّ المشهد' : 'قراءة المشهد كاملاً'),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// مأزق الشورى والتحدي: المأزق بنصه، وسؤال الشورى، ثم الخيارات (إن نص عليها الشاهد) أو زر كشف.
class SeerahDilemmaCard extends StatelessWidget {
  const SeerahDilemmaCard({
    super.key,
    required this.challenge,
    required this.shuraQuestion,
    required this.options,
    required this.chosen,
    required this.revealed,
    required this.onChoose,
    required this.onReveal,
  });

  /// نص المأزق.
  final String challenge;

  /// سؤال الشورى الموجَّه للقارئ، أو null إن لم يُكتب.
  final String? shuraQuestion;

  /// الخيارات المنصوص عليها في الشاهد؛ فارغة إن لم يُنص عليها.
  final List<String> options;

  /// الخيار المختار.
  final int? chosen;

  /// هل كُشف القرار.
  final bool revealed;

  /// اختيار خيار.
  final ValueChanged<int> onChoose;

  /// كشف القرار بلا خيارات.
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return SmoothSurface(
      key: const ValueKey<String>('station-dilemma'),
      borderColor: palette.amber.withValues(alpha: 0.45),
      elevated: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SeerahCardHeading(icon: Icons.help_outline_rounded, title: 'مأزق الشورى والتحدي'),
          const SizedBox(height: 10),
          Text(
            challenge,
            key: const ValueKey<String>('station-challenge'),
            style: AppTypography.athar(color: palette.ink, fontSize: 21),
          ),
          if (shuraQuestion != null) ...<Widget>[
            const SizedBox(height: 14),
            SmoothSurface(
              color: palette.amberSoft,
              borderColor: palette.amber.withValues(alpha: 0.4),
              radius: AppShapes.radiusMedium,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SectionEyebrow('سؤال الشورى', icon: Icons.groups_rounded),
                  const SizedBox(height: 4),
                  Text(
                    shuraQuestion!,
                    key: const ValueKey<String>('station-shura-question'),
                    style: AppTypography.athar(color: palette.ink, fontSize: 20),
                  ),
                ],
              ),
            ),
          ],
          if (options.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              revealed ? 'اخترتَ:' : 'اختر ما تراه ثم يُكشف القرار النبوي:',
              style: text.labelLarge?.copyWith(color: palette.inkSoft, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < options.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 8),
              _OptionTile(
                index: i,
                label: options[i],
                selected: chosen == i,
                dimmed: revealed && chosen != i,
                onTap: revealed ? null : () => onChoose(i),
              ),
            ],
          ] else if (!revealed) ...<Widget>[
            const SizedBox(height: 16),
            WideActionButton(
              key: const ValueKey<String>('station-reveal'),
              label: 'اكشف القرار النبوي',
              subtitle: 'تأمّل الموقف أولاً ثم اكشف',
              icon: Icons.lightbulb_outline_rounded,
              onPressed: onReveal,
            ),
          ],
        ],
      ),
    );
  }
}

/// خيار واحد من خيارات المأزق: نصه كما ورد في الشاهد.
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.index,
    required this.label,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final int index;
  final String label;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return SmoothSurface(
      key: ValueKey<String>('station-option-$index'),
      onTap: onTap,
      semanticLabel: 'الخيار ${arabicDigits(index + 1)}: $label',
      color: selected ? palette.amberSoft : palette.surface,
      borderColor: selected ? palette.amber : palette.line,
      radius: AppShapes.radiusMedium,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: <Widget>[
          Icon(
            selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
            size: 22,
            color: selected ? palette.amberText : palette.inkSoft,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: AppTypography.athar(
                color: dimmed ? palette.inkSoft : palette.ink,
                fontSize: 19,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// القرار النبوي ونتيجته مع شاهده، يظهر بعد الاختيار أو الكشف.
class SeerahDecisionCard extends StatelessWidget {
  const SeerahDecisionCard({
    super.key,
    required this.decision,
    required this.evidence,
    required this.sources,
  });

  /// نص القرار.
  final String decision;

  /// شواهد مشهد القرار.
  final List<SeerahEvidence> evidence;

  /// فهرس المصادر.
  final SourceCatalog? sources;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Duration fade = MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 380);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: fade,
      curve: Curves.easeOut,
      builder: (BuildContext context, double opacity, Widget? child) => Opacity(opacity: opacity, child: child),
      child: SmoothSurface(
        key: const ValueKey<String>('station-decision'),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: <Color>[palette.emeraldSoft, palette.surface],
        ),
        elevated: true,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SeerahCardHeading(icon: Icons.lightbulb_outline_rounded, title: 'القرار النبوي ونتيجته'),
            const SizedBox(height: 10),
            Text(
              decision,
              key: const ValueKey<String>('station-decision-text'),
              style: AppTypography.athar(color: palette.ink, fontSize: 21),
            ),
            const SizedBox(height: 16),
            SectionEyebrow(
              evidence.length == 1 ? 'الشاهد من المصادر' : 'الشواهد من المصادر (${arabicDigits(evidence.length)})',
              icon: Icons.format_quote_rounded,
            ),
            const SizedBox(height: 8),
            for (final SeerahEvidence item in evidence) ...<Widget>[
              SourceQuoteTile(reference: item.source, source: sources?.byId(item.source.sourceId)),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
