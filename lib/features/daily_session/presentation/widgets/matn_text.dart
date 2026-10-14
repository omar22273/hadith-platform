// عرض المتن الشريف المشكول بخط Amiri وبمسافات رأسية واسعة.
// يميز صاحب الكلام في كل مقطع، ويظلل غريب الألفاظ بظل كهرماني دافئ قابل
// للمس، ويضيء الكلمة الجارية عند توفر تلاوة متزامنة.
// النص يُعرض كما هو في الملف الموثق، كلمةً كلمة بعقد التقسيم المشترك.
//
// الاتجاه: الفقرة كلها نص واحد من TextSpan بـ TextDirection.rtl، والغريب المظلل نص
// بخلفية ومستمع لمس لا WidgetSpan. فالعناصر المضمّنة (WidgetSpan) المتجاورة تُعامَل في
// خوارزمية الاتجاه كأحرف محايدة فتُرسم متتابعاتها من اليسار إلى اليمين (فتنعكس
// «ما يريبك» و«فأنى يستجاب له»)؛ أما النص الصريح فيلتزم ترتيب القراءة العربي دائماً.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../hadith/data/models/models.dart';

/// المتن مع الغريب اللمسي.
class MatnText extends StatefulWidget {
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
  State<MatnText> createState() => _MatnTextState();
}

class _MatnTextState extends State<MatnText> {
  /// مستمع لمس لكل لفظة غريبة، تشترك فيه كلماتها المتتابعة.
  final Map<String, TapGestureRecognizer> _recognizers = <String, TapGestureRecognizer>{};

  TapGestureRecognizer _recognizerFor(String gharibId) {
    return _recognizers.putIfAbsent(
      gharibId,
      () => TapGestureRecognizer()..onTap = () => widget.onGharibTap?.call(gharibId),
    );
  }

  @override
  void dispose() {
    for (final TapGestureRecognizer recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    _recognizers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Matn matn = widget.matn;
    final Map<String, Map<int, GharibEntry>> anchors = <String, Map<int, GharibEntry>>{};
    for (final GharibEntry entry in matn.gharib) {
      final Map<int, GharibEntry> bySegment =
          anchors.putIfAbsent(entry.anchor.segmentId, () => <int, GharibEntry>{});
      for (int offset = 0; offset < entry.anchor.length; offset++) {
        bySegment[entry.anchor.tokenIndex + offset] = entry;
      }
    }

    final TextStyle base = AppTypography.matnOf(context, color: palette.ink, fontSize: widget.fontSize);
    final List<InlineSpan> spans = <InlineSpan>[];
    final bool tappable = widget.onGharibTap != null;
    bool first = true;
    GharibEntry? previousGharib;
    for (final MatnSegment segment in matn.segments) {
      final TextStyle voice = _voiceStyle(segment.voice, base, palette);
      for (final MatnToken token in segment.tokens) {
        final GharibEntry? anchored = anchors[segment.id]?[token.index];
        final GharibEntry? gharib = tappable ? anchored : null;
        final bool active = widget.activeSegmentId == segment.id && widget.activeTokenIndex == token.index;
        if (!first) {
          // المسافة بين كلمتين من لفظة واحدة تُظلَّل معهما فيبدو التظليل متصلاً.
          final GharibEntry? joinedWith = gharib != null && identical(gharib, previousGharib) ? gharib : null;
          spans.add(
            TextSpan(
              text: ' ',
              style: joinedWith == null ? voice : _gharibStyle(voice, palette, joinedWith, active: false),
              recognizer: joinedWith == null ? null : _recognizerFor(joinedWith.id),
            ),
          );
        }
        first = false;
        if (token.leading.isNotEmpty) {
          spans.add(TextSpan(text: token.leading, style: voice));
        }
        if (gharib != null) {
          spans.add(
            TextSpan(
              text: token.core,
              style: _gharibStyle(voice, palette, gharib, active: active),
              recognizer: _recognizerFor(gharib.id),
              semanticsLabel: '${token.core}، لفظة غريبة، المس لبيانها',
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
        previousGharib = gharib;
      }
    }
    return Text.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.justify,
      textDirection: TextDirection.rtl,
    );
  }

  /// نمط الكلمة الغريبة: خلفية كهرمانية دافئة وخط منقّط سفلي، وأوضح عند الاختيار.
  TextStyle _gharibStyle(
    TextStyle voice,
    AppPalette palette,
    GharibEntry gharib, {
    required bool active,
  }) {
    final bool selected = gharib.id == widget.selectedGharibId;
    return voice.copyWith(
      backgroundColor: active
          ? palette.emeraldSoft
          : selected
              ? palette.amber.withValues(alpha: 0.32)
              : palette.amberSoft,
      decoration: TextDecoration.underline,
      decorationStyle: selected ? TextDecorationStyle.solid : TextDecorationStyle.dotted,
      decorationColor: selected ? palette.amber : palette.amber.withValues(alpha: 0.7),
      decorationThickness: selected ? 2 : 1.4,
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
