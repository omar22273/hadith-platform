// المرحلة الثانية: المتن الشريف والبيان اللغوي اللمسي.
// اللفظة المظللة تُفتح ببطاقة شرح مدمجة من كتب الغريب بنصوصها.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/content/widgets/source_quote_tile.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../../hadith/data/models/models.dart';
import '../../../hadith/domain/hadith_bundle.dart';
import '../../../recitation/application/recitation_controller.dart';
import '../../../recitation/presentation/recitation_bar.dart';
import '../../application/session_controller.dart';
import '../../application/session_state.dart';
import '../widgets/matn_text.dart';

/// مرحلة المتن.
class MatnStage extends ConsumerWidget {
  const MatnStage({super.key, required this.bundle});

  /// الحديث وفهارسه.
  final HadithBundle bundle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final HadithDailyModel hadith = bundle.hadith;
    final String? selectedId = ref.watch(
      sessionControllerProvider(hadith.id).select((SessionState s) => s.selectedGharibId),
    );
    final RecitationState recitation = ref.watch(recitationControllerProvider(hadith.id));
    GharibEntry? selected;
    for (final GharibEntry entry in hadith.matn.gharib) {
      if (entry.id == selectedId) {
        selected = entry;
      }
    }
    final Set<SegmentVoice> voices = hadith.matn.segments.map((MatnSegment s) => s.voice).toSet();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        SmoothSurface(
          elevated: true,
          padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Expanded(
                    child: SectionEyebrow('المتن الشريف', icon: Icons.menu_book_rounded),
                  ),
                  if (hadith.matn.gharib.isNotEmpty)
                    Text(
                      'المس المظلَّل لبيانه',
                      style: text.labelSmall?.copyWith(color: palette.inkSoft),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: <Widget>[
                  if (voices.contains(SegmentVoice.narration))
                    _LegendDot(color: palette.inkSoft, label: 'كلام الراوي'),
                  if (voices.contains(SegmentVoice.prophet))
                    _LegendDot(color: palette.ink, label: 'كلام النبي ﷺ'),
                  if (voices.contains(SegmentVoice.interlocutor))
                    _LegendDot(color: palette.amberText, label: 'كلام السائل'),
                ],
              ),
              const SizedBox(height: 6),
              MatnText(
                matn: hadith.matn,
                selectedGharibId: selectedId,
                activeSegmentId: recitation.activeSegmentId,
                activeTokenIndex: recitation.activeTokenIndex,
                onGharibTap: (String id) =>
                    ref.read(sessionControllerProvider(hadith.id).notifier).selectGharib(id),
              ),
              const SizedBox(height: 10),
              RecitationBar(hadithId: hadith.id),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: selected == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _GharibCard(
                    entry: selected,
                    bundle: bundle,
                    onClose: () =>
                        ref.read(sessionControllerProvider(hadith.id).notifier).clearGharib(),
                  ),
                ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const SizedBox.square(dimension: 8),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppPalette.of(context).inkSoft),
        ),
      ],
    );
  }
}

class _GharibCard extends StatelessWidget {
  const _GharibCard({required this.entry, required this.bundle, required this.onClose});

  final GharibEntry entry;
  final HadithBundle bundle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return SmoothSurface(
      color: palette.amberSoft,
      borderColor: palette.amber.withValues(alpha: 0.5),
      radius: AppShapes.radiusLarge,
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  entry.headword,
                  style: AppTypography.matnOf(
                    context,
                    color: palette.amberText,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ).copyWith(height: 1.6),
                ),
              ),
              IconButton(
                onPressed: onClose,
                tooltip: 'إغلاق البيان',
                icon: Icon(Icons.close_rounded, color: palette.inkSoft),
              ),
            ],
          ),
          Text(
            entry.meaning,
            style: text.bodyLarge?.copyWith(color: palette.ink, height: 1.85),
          ),
          const SizedBox(height: 10),
          for (final SourceRef ref in entry.sources) ...<Widget>[
            SourceQuoteTile(reference: ref, source: bundle.sources.byId(ref.sourceId)),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}
