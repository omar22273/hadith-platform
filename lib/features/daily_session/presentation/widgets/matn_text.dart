// عرض المتن الشريف المشكول بخط Amiri وبمسافات رأسية واسعة.
// يميز صاحب الكلام في كل مقطع، ويظلل غريب الألفاظ بظل كهرماني دافئ قابل
// للمس، ويضيء الكلمة الجارية عند توفر تلاوة متزامنة.
// النص يُعرض كما هو في الملف الموثق، كلمةً كلمة بعقد التقسيم المشترك.

import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../hadith/data/models/models.dart';

/// المتن مع الغريب اللمسي.
class MatnText extends StatelessWidget {
  const MatnText({
    super.key,
    required this.matn,
    this.selectedGharibId,
    this.onGharibTap,
    this.activeSegmentId,
    this.activeTokenIndex,
    this.fontSize = 27,
  });

  /// المتن.
  final Matn matn;

  /// اللفظة المختارة.
  final String? selectedGharibId;

  /// لمس لفظة غريبة.
  final ValueChanged<String>? onGharibTap;

  /// مقطع الكلمة الجارية في التلاوة.
  final String? activeSegmentId;

  /// رقم الكلمة الجارية في التلاوة.
  final int? activeTokenIndex;

  /// حجم الخط.
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Map<String, Map<int, GharibEntry>> anchors = <String, Map<int, GharibEntry>>{};
    for (final GharibEntry entry in matn.gharib) {
      final Map<int, GharibEntry> bySegment =
          anchors.putIfAbsent(entry.anchor.segmentId, () => <int, GharibEntry>{});
      for (int offset = 0; offset < entry.anchor.length; offset++) {
        bySegment[entry.anchor.tokenIndex + offset] = entry;
      }
    }

    final TextStyle base = AppTypography.matnOf(context, color: palette.ink, fontSize: fontSize);
    final List<InlineSpan> spans = <InlineSpan>[];
    bool first = true;
    for (final MatnSegment segment in matn.segments) {
      final TextStyle voice = _voiceStyle(segment.voice, base, palette);
      for (final MatnToken token in segment.tokens) {
        if (!first) {
          spans.add(TextSpan(text: ' ', style: voice));
        }
        first = false;
        if (token.leading.isNotEmpty) {
          spans.add(TextSpan(text: token.leading, style: voice));
        }
        final GharibEntry? gharib = anchors[segment.id]?[token.index];
        final bool active = activeSegmentId == segment.id && activeTokenIndex == token.index;
        if (gharib != null && onGharibTap != null) {
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: _GharibWord(
                word: token.core,
                style: voice,
                selected: gharib.id == selectedGharibId,
                active: active,
                onTap: () => onGharibTap!(gharib.id),
              ),
            ),
          );
        } else {
          spans.add(
            TextSpan(
              text: token.core,
              style: active ? voice.copyWith(backgroundColor: palette.emeraldSoft) : voice,
            ),
          );
        }
        if (token.trailing.isNotEmpty) {
          spans.add(TextSpan(text: token.trailing, style: voice));
        }
      }
    }
    return Text.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.justify,
      textDirection: TextDirection.rtl,
    );
  }

  static TextStyle _voiceStyle(SegmentVoice voice, TextStyle base, AppPalette palette) {
    switch (voice) {
      case SegmentVoice.narration:
        return base.copyWith(color: palette.inkSoft, fontSize: (base.fontSize ?? 27) * 0.86);
      case SegmentVoice.prophet:
        return base.copyWith(fontWeight: FontWeight.w700);
      case SegmentVoice.interlocutor:
        return base.copyWith(color: palette.amberText);
    }
  }
}

class _GharibWord extends StatelessWidget {
  const _GharibWord({
    required this.word,
    required this.style,
    required this.selected,
    required this.active,
    required this.onTap,
  });

  final String word;
  final TextStyle style;
  final bool selected;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '$word، لفظة غريبة، المس لبيانها',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ExcludeSemantics(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: active
                  ? palette.emeraldSoft
                  : selected
                      ? palette.amber.withValues(alpha: 0.32)
                      : palette.amberSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border(
                bottom: BorderSide(
                  color: selected ? palette.amber : palette.amber.withValues(alpha: 0.55),
                  width: selected ? 2 : 1.4,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(word, style: style.copyWith(height: 1.75)),
            ),
          ),
        ),
      ),
    );
  }
}
