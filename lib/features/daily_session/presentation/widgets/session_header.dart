// ترويسة الوِرد: العنوان، والتخريج الموثق في الزاوية، وزر التبديل إلى طبقة
// طالب العلم، وشريط المراحل الأربع.

import 'package:flutter/material.dart';

import '../../../../core/text/arabic_digits.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_sheet.dart';
import '../../../hadith/domain/hadith_bundle.dart';
import '../../application/session_state.dart';
import '../scholar/takhrij_panel.dart';
import 'share_hadith_button.dart';

/// الترويسة.
class SessionHeader extends StatelessWidget {
  const SessionHeader({
    super.key,
    required this.bundle,
    required this.state,
    required this.isReview,
    required this.onBack,
    required this.onToggleScholar,
    required this.onStageTap,
  });

  /// الحديث وفهارسه.
  final HadithBundle bundle;

  /// حالة الجلسة.
  final SessionState state;

  /// هل هي مراجعة.
  final bool isReview;

  /// رجوع.
  final VoidCallback onBack;

  /// تبديل طبقة طالب العلم.
  final VoidCallback onToggleScholar;

  /// لمس مرحلة.
  final ValueChanged<SessionStage> onStageTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final bool scholar = state.scholarLayerOpen;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              IconButton(
                onPressed: onBack,
                tooltip: 'العودة إلى المسار',
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${bundle.hadith.collection.title} · الحديث ${arabicDigits(bundle.hadith.collection.numberInCollection)}'
                        '${isReview ? ' · مراجعة' : ''}',
                        style: text.labelMedium?.copyWith(color: palette.amberText, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        bundle.hadith.title,
                        style: AppTypography.heritageTitle(color: palette.ink, fontSize: 24),
                      ),
                    ],
                  ),
                ),
              ),
              ShareHadithButton(bundle: bundle),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              const SizedBox(width: 8),
              Expanded(
                child: _HeaderPill(
                  icon: Icons.menu_book_rounded,
                  label: bundle.hadith.matn.takhrij.displayLabel,
                  selected: false,
                  semanticLabel: 'التخريج: ${bundle.hadith.matn.takhrij.displayLabel}',
                  onTap: () => showSmoothSheet<void>(
                    context: context,
                    builder: (BuildContext sheetContext) =>
                        TakhrijPanel(bundle: bundle, scrollable: false),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _HeaderPill(
                icon: Icons.account_tree_rounded,
                label: 'طالب العلم',
                selected: scholar,
                semanticLabel: scholar ? 'إغلاق طبقة طالب العلم' : 'فتح طبقة طالب العلم',
                onTap: onToggleScholar,
              ),
            ],
          ),
          if (!scholar) ...<Widget>[
            const SizedBox(height: 10),
            _StageBar(current: state.stage, visited: state.visited, onTap: onStageTap),
          ],
        ],
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Semantics(
      button: true,
      toggled: selected,
      label: semanticLabel,
      child: Material(
        color: selected ? palette.ink : palette.surfaceMuted,
        shape: AppShapes.rounded(
          AppShapes.radiusSmall,
          side: BorderSide(color: selected ? palette.ink : palette.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(icon, size: 18, color: selected ? palette.paper : palette.amberText),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: selected ? palette.paper : palette.ink,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
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

class _StageBar extends StatelessWidget {
  const _StageBar({required this.current, required this.visited, required this.onTap});

  final SessionStage current;
  final Set<SessionStage> visited;
  final ValueChanged<SessionStage> onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: <Widget>[
          for (final SessionStage stage in SessionStage.values) ...<Widget>[
            if (stage.index > 0) const SizedBox(width: 6),
            Expanded(
              child: Semantics(
                button: true,
                selected: stage == current,
                label: 'المرحلة ${arabicDigits(stage.index + 1)}: ${stage.title}',
                child: InkWell(
                  onTap: () => onTap(stage),
                  customBorder: AppShapes.rounded(AppShapes.radiusSmall),
                  child: ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: <Widget>[
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            height: 6,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              gradient: stage.index <= current.index ? palette.amberGradient : null,
                              color: stage.index <= current.index ? null : palette.line,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            stage.shortLabel,
                            style: text.labelSmall?.copyWith(
                              color: stage == current ? palette.ink : palette.inkSoft,
                              fontWeight: stage == current ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
