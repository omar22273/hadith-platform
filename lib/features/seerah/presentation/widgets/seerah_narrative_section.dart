// «الرواية التاريخية وتفاصيل الأحداث»: قسم قابل للطي في آخر شاشة المحطة، يُفتح
// اختيارياً لمن أراد القراءة الموسعة.
//
// - منزلق حجم الخط في أعلاه مربوط بإعداد «حجم خط المتن» نفسه: تحريكه هنا أو في
//   الإعدادات يغيّر الحجم في الموضعين.
// - تحته حقل detailed_narrative فقرةً فقرةً إن وُجد في ملف البيانات.
// - وتحته المشاهد الثلاثة الموثقة كاملة، وتحت كل مشهد نصوصه المصدرية كما وردت
//   في الشواهد مع إحالاتها.
//
// لا يُضاف هنا نص من خارج ملف البيانات: لا رواية تُولَّد ولا تُستكمل من الذاكرة.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/content/models/source_catalog.dart';
import '../../../../core/content/widgets/source_quote_tile.dart';
import '../../../../core/preferences/reading_preferences.dart';
import '../../../../core/text/arabic_digits.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../data/models/seerah_station.dart';
import 'seerah_labels.dart';

/// عنوان القسم القابل للطي.
const String seerahNarrativeTitle = 'الرواية التاريخية وتفاصيل الأحداث';

/// القسم القابل للطي.
class SeerahNarrativeSection extends StatelessWidget {
  const SeerahNarrativeSection({super.key, required this.station, required this.sources});

  /// المحطة.
  final SeerahStationModel station;

  /// فهرس المصادر.
  final SourceCatalog? sources;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final List<String> paragraphs = station.narrativeParagraphs;
    final ShapeBorder shape = AppShapes.rounded(
      AppShapes.radiusLarge,
      side: BorderSide(color: palette.line),
    );
    // الشرائح الفاصلة الافتراضية للقسم تُخفى فلا يتقاطع معها حد الشكل الناعم.
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: const ValueKey<String>('station-narrative'),
        initiallyExpanded: false,
        shape: shape,
        collapsedShape: shape,
        backgroundColor: palette.surface,
        collapsedBackgroundColor: palette.surface,
        clipBehavior: Clip.antiAlias,
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        leading: Icon(Icons.auto_stories_rounded, color: palette.amberText),
        title: Text(
          seerahNarrativeTitle,
          style: AppTypography.heritageTitle(color: palette.ink, fontSize: 21),
        ),
        subtitle: Text(
          'قراءة موسعة اختيارية بخط يتبع حجم الخط في الإعدادات',
          style: text.labelSmall?.copyWith(color: palette.inkSoft),
        ),
        children: <Widget>[
          const _ReadingSizeBar(),
          const SizedBox(height: 14),
          if (paragraphs.isNotEmpty)
            _NarrativeBody(paragraphs: paragraphs)
          else
            const _NarrativePendingNote(),
          const SizedBox(height: 22),
          for (final SeerahScene scene in SeerahScene.values) ...<Widget>[
            _SceneBlock(station: station, scene: scene, sources: sources),
            const SizedBox(height: 22),
          ],
          Text(
            'المشاهد أعلاه مقتصرة على الشواهد المنقولة تحتها، والنصوص المصدرية منقولة كما وردت.',
            style: text.labelSmall?.copyWith(color: palette.inkSoft, height: 1.7),
          ),
          for (final String note in station.review.notes.skip(1))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '• $note',
                style: text.labelSmall?.copyWith(color: palette.inkSoft, height: 1.7),
              ),
            ),
        ],
      ),
    );
  }
}

/// شريط حجم الخط: منزلق مربوط بإعدادات القراءة نفسها التي في شاشة الإعدادات.
class _ReadingSizeBar extends ConsumerWidget {
  const _ReadingSizeBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final ReadingPreferences reading = ref.watch(readingPreferencesProvider);
    final ReadingPreferencesController controller = ref.read(readingPreferencesProvider.notifier);
    return SmoothSurface(
      color: palette.surfaceMuted,
      radius: AppShapes.radiusMedium,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: <Widget>[
          Icon(Icons.text_fields_rounded, size: 20, color: palette.amberText),
          const SizedBox(width: 8),
          Text('حجم الخط', style: text.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
          Expanded(
            child: Slider(
              key: const ValueKey<String>('narrative-font-slider'),
              value: reading.matnFontSize,
              min: ReadingPreferences.minMatnFontSize,
              max: ReadingPreferences.maxMatnFontSize,
              divisions: (ReadingPreferences.maxMatnFontSize - ReadingPreferences.minMatnFontSize).round(),
              label: arabicDigits(reading.matnFontSize.round()),
              semanticFormatterCallback: (double value) => 'حجم خط القراءة ${arabicDigits(value.round())}',
              onChanged: (double value) => controller.setMatnFontSize(value, persist: false),
              onChangeEnd: controller.setMatnFontSize,
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              arabicDigits(reading.matnFontSize.round()),
              textAlign: TextAlign.center,
              style: text.labelLarge?.copyWith(color: palette.amberText, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// الرواية المفصلة فقرات متتالية.
class _NarrativeBody extends StatelessWidget {
  const _NarrativeBody({required this.paragraphs});

  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.auto_stories_rounded, size: 20, color: palette.amberText),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'الرواية الكاملة',
                style: AppTypography.heritageTitle(color: palette.ink, fontSize: 24),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SmoothSurface(
          key: const ValueKey<String>('narrative-body'),
          color: palette.surface,
          borderColor: palette.line,
          radius: AppShapes.radiusMedium,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int i = 0; i < paragraphs.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(height: 10),
                SelectableText(
                  paragraphs[i],
                  textAlign: TextAlign.justify,
                  style: AppTypography.narrativeOf(context, color: palette.ink, fontSize: 21),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// تنبيه يظهر ما دامت الرواية المفصلة لم تصل في حزمة المحتوى.
class _NarrativePendingNote extends StatelessWidget {
  const _NarrativePendingNote();

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return SmoothSurface(
      key: const ValueKey<String>('narrative-pending-note'),
      color: palette.amberSoft,
      borderColor: palette.amber.withValues(alpha: 0.45),
      radius: AppShapes.radiusMedium,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.hourglass_empty_rounded, size: 20, color: palette.amberText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'الرواية المفصلة لهذه المحطة تصل مع حزمة المحتوى القادمة. وفيما يلي مشاهدها '
              'الثلاثة الموثقة كاملة، وتحت كل مشهد نصوصه المصدرية بإحالاتها.',
              style: AppTypography.ui(color: palette.amberText, fontSize: 13.5, height: 1.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneBlock extends StatelessWidget {
  const _SceneBlock({required this.station, required this.scene, required this.sources});

  final SeerahStationModel station;
  final SeerahScene scene;
  final SourceCatalog? sources;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final List<SeerahEvidence> evidence = station.evidenceFor(scene);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(sceneIcon(scene), size: 20, color: palette.amberText),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                sceneTitle(scene),
                style: AppTypography.heritageTitle(color: palette.ink, fontSize: 22),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SmoothSurface(
          color: palette.surface,
          borderColor: palette.line,
          radius: AppShapes.radiusMedium,
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            sceneText(station, scene),
            key: ValueKey<String>('narrative-scene-${scene.wire}'),
            textAlign: TextAlign.justify,
            style: AppTypography.narrativeOf(context, color: palette.ink, fontSize: 20),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          evidence.length == 1 ? 'النص المصدري' : 'النصوص المصدرية (${arabicDigits(evidence.length)})',
          style: text.labelLarge?.copyWith(color: palette.inkSoft, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        for (final SeerahEvidence item in evidence) ...<Widget>[
          SourceQuoteTile(reference: item.source, source: sources?.byId(item.source.sourceId)),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
