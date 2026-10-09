// نتائج البحث في الأحاديث المُعدّة: عنوان ورقم وبداية المتن المشكول.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/text/arabic_digits.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../../hadith/application/hadith_providers.dart';
import '../../../hadith/domain/hadith_search.dart';

/// قائمة النتائج.
class HadithSearchResults extends ConsumerWidget {
  const HadithSearchResults({super.key, required this.query, required this.onOpen});

  /// نص البحث.
  final String query;

  /// فتح حديث بمعرّفه.
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final AsyncValue<List<HadithSearchEntry>> index = ref.watch(hadithSearchIndexProvider);
    return index.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('تعذر تجهيز البحث: $error', textAlign: TextAlign.center),
        ),
      ),
      data: (List<HadithSearchEntry> entries) {
        final List<HadithSearchEntry> found = searchHadith(entries, query);
        if (found.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'لا حديث مُعدّاً يطابق «${query.trim()}».',
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(color: palette.inkSoft),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: found.length,
          separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 10),
          itemBuilder: (BuildContext context, int i) {
            final HadithSearchEntry entry = found[i];
            return SmoothSurface(
              radius: AppShapes.radiusMedium,
              borderColor: palette.line,
              padding: const EdgeInsets.all(14),
              onTap: () => onOpen(entry.hadithId),
              semanticLabel: 'الحديث ${arabicDigits(entry.number)}: ${entry.title}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'الحديث ${arabicDigits(entry.number)}',
                    style: text.labelMedium?.copyWith(color: palette.amberText, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    entry.title,
                    style: AppTypography.heritageTitle(color: palette.ink, fontSize: 22),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    entry.matnPreview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.matnOf(context, color: palette.inkSoft, fontSize: 18),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
