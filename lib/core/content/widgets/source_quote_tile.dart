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
                fromHadithCollection ? 'نص الرواية بضبط المصدر' : 'نص المصدر',
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
