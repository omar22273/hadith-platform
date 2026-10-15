// شاهد منقول بنصه من مصدره مع إحالته. يُعرض النص كما هو دون تعديل، ويشترك
// فيه الحديث والسيرة.

import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';
import '../../ui/app_shapes.dart';
import '../../ui/smooth_surface.dart';
import '../citation.dart';
import '../models/source_catalog.dart';
import '../models/source_ref.dart';

/// بطاقة الشاهد.
class SourceQuoteTile extends StatelessWidget {
  const SourceQuoteTile({
    super.key,
    required this.reference,
    required this.source,
  });

  /// الإحالة بنص الشاهد.
  final SourceRef reference;

  /// المصدر من الفهرس.
  final SourceWork? source;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final String? quote = reference.quote;
    final bool fromHadithCollection = source?.kind == SourceKind.hadithCollection;
    final String caption = switch (source?.kind) {
      SourceKind.hadithCollection => 'نص الرواية بضبط المصدر',
      SourceKind.quranText => 'نص الآية كما أدخله مالك المشروع',
      SourceKind.ownerText => 'نص أدخله مالك المشروع بتشكيله',
      SourceKind.adhkarCollection => 'نص حصن المسلم كما في الملف المرفق',
      _ => 'نص المصدر',
    };
    return SmoothSurface(
      color: palette.surfaceMuted,
      borderColor: palette.line,
      radius: AppShapes.radiusMedium,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (quote != null && quote.isNotEmpty)
            SelectableText(
              '«$quote»',
              style: AppTypography.athar(
                color: palette.ink,
                fontSize: fromHadithCollection ? 19 : 18,
              ),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                caption,
                style: text.labelSmall?.copyWith(
                  color: palette.amberText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                formatCitation(source, reference),
                style: text.labelSmall?.copyWith(color: palette.inkSoft),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
