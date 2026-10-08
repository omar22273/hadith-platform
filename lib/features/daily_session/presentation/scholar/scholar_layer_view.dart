// طبقة طالب العلم: شجرة الإسناد، وتراجم الرواة، ومقارنة الروايات، والتخريج.

import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_sheet.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../../hadith/data/models/models.dart';
import '../../../hadith/domain/hadith_bundle.dart';
import 'narrator_card.dart';
import 'sanad_tree_view.dart';
import 'takhrij_panel.dart';
import 'variant_matrix.dart';

/// الطبقة المتقدمة.
class ScholarLayerView extends StatelessWidget {
  const ScholarLayerView({super.key, required this.bundle});

  /// الحديث وفهارسه.
  final HadithBundle bundle;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: <Widget>[
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: <Widget>[
              Tab(text: 'شجرة الإسناد', icon: Icon(Icons.account_tree_rounded, size: 20)),
              Tab(text: 'الرواة', icon: Icon(Icons.person_rounded, size: 20)),
              Tab(text: 'مقارنة الروايات', icon: Icon(Icons.compare_arrows_rounded, size: 20)),
              Tab(text: 'التخريج', icon: Icon(Icons.menu_book_rounded, size: 20)),
            ],
          ),
          Expanded(
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              children: <Widget>[
                SanadTreeView(bundle: bundle),
                _NarratorsList(bundle: bundle),
                VariantMatrix(bundle: bundle),
                TakhrijPanel(bundle: bundle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NarratorsList extends StatelessWidget {
  const _NarratorsList({required this.bundle});

  final HadithBundle bundle;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final List<String> ids = <String>[];
    for (final SanadChain chain in bundle.hadith.scholar.chains) {
      for (final SanadLink link in chain.links) {
        if (!ids.contains(link.narratorId)) {
          ids.add(link.narratorId);
        }
      }
    }
    for (final NarrationVariant variant in bundle.hadith.scholar.variants) {
      if (!ids.contains(variant.companionNarratorId)) {
        ids.add(variant.companionNarratorId);
      }
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: ids.length,
      separatorBuilder: (BuildContext context, int _) => const SizedBox(height: 8),
      itemBuilder: (BuildContext context, int index) {
        final NarratorProfile? narrator = bundle.narrators.byId(ids[index]);
        if (narrator == null) {
          return const SizedBox.shrink();
        }
        final String subtitle = <String>[
          if (narrator.tabaqa != null) narrator.tabaqa!.text,
          if (narrator.gradeText != null) narrator.gradeText!,
          if (narrator.death != null) narrator.death!.text,
        ].join(' · ');
        return SmoothSurface(
          radius: AppShapes.radiusMedium,
          borderColor: palette.line,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          semanticLabel: narrator.displayName,
          onTap: () => showSmoothSheet<void>(
            context: context,
            builder: (BuildContext sheetContext) => NarratorCard(narrator: narrator, bundle: bundle),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      narrator.displayName,
                      style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      subtitle.isEmpty ? narratorCategoryLabel(narrator.category) : subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelSmall?.copyWith(color: palette.inkSoft, height: 1.5),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: palette.inkSoft, size: 20),
            ],
          ),
        );
      },
    );
  }
}
