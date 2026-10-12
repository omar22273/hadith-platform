// التبويب الثالث: وِرد الأذكار والسبحة النبوية الذكية.
//
// بطاقة الذكر الحالي تُلمس في أي موضع منها لاحتساب ضغطة (اهتزاز لمسي خفيف)،
// فإذا بلغ العدد المسنون: اهتزاز مزدوج وهالة خضراء وقفل نهائي، ثم ينتقل الوِرد
// تلقائياً إلى الذكر التالي، أو تظهر شارة إتمام الوِرد.
//
// الخط الأحمر: نصوص الأذكار وشواهدها تأتي من ملف البيانات وحده، وتحت كل ذكر
// شاهده بنصه الحرفي وموضعه.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/content/models/source_catalog.dart';
import '../../../core/content/models/source_ref.dart';
import '../../../core/content/review_labels.dart';
import '../../../core/content/source_catalog_provider.dart';
import '../../../core/content/widgets/source_quote_tile.dart';
import '../../../core/json/json_reader.dart';
import '../../../core/text/arabic_digits.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/ui/app_shapes.dart';
import '../../../core/ui/smooth_surface.dart';
import '../application/adhkar_providers.dart';
import '../application/adhkar_wird_controller.dart';
import '../data/models/adhkar.dart';
import '../domain/adhkar_repository.dart';
import 'widgets/dhikr_card.dart';

/// شاشة وِرد الأذكار.
class AdhkarScreen extends ConsumerWidget {
  const AdhkarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AdhkarCatalog> catalog = ref.watch(adhkarCatalogProvider);
    final Widget body;
    if (catalog.hasError) {
      body = _ErrorView(
        error: catalog.error!,
        onRetry: () => ref.invalidate(adhkarCatalogProvider),
      );
    } else if (catalog.value == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = const _AdhkarBody();
    }
    return Scaffold(body: SafeArea(bottom: false, child: body));
  }
}

class _AdhkarBody extends ConsumerStatefulWidget {
  const _AdhkarBody();

  @override
  ConsumerState<_AdhkarBody> createState() => _AdhkarBodyState();
}

class _AdhkarBodyState extends ConsumerState<_AdhkarBody> {
  Timer? _secondPulse;

  @override
  void dispose() {
    _secondPulse?.cancel();
    super.dispose();
  }

  /// بلوغ العدد المسنون: اهتزاز متوسط مزدوج بفاصل قصير.
  void _doublePulse() {
    unawaited(HapticFeedback.mediumImpact());
    _secondPulse?.cancel();
    _secondPulse = Timer(const Duration(milliseconds: 140), () {
      unawaited(HapticFeedback.mediumImpact());
    });
  }

  void _onCardTap() {
    final DhikrTapResult result = ref.read(adhkarWirdProvider.notifier).tap();
    switch (result) {
      case DhikrTapResult.counted:
        unawaited(HapticFeedback.selectionClick());
      case DhikrTapResult.completed:
        _doublePulse();
      case DhikrTapResult.locked:
      case DhikrTapResult.unavailable:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final List<DhikrItem> items = ref.watch(adhkarItemsProvider);
    final AdhkarWirdState wird = ref.watch(adhkarWirdProvider);
    final SourceCatalog? sources = ref.watch(sourceCatalogProvider).value;
    if (items.isEmpty || wird.counts.length != items.length) {
      return const Center(child: CircularProgressIndicator());
    }
    final int index = wird.index.clamp(0, items.length - 1).toInt();
    final DhikrItem item = items[index];
    final bool complete = wird.isComplete(items);
    return ListView(
      key: const ValueKey<String>('adhkar-scroll'),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: <Widget>[
        Text(
          'وِرد الأذكار',
          style: AppTypography.heritageTitle(color: palette.ink, fontSize: 32),
        ),
        Text(
          'أتممتَ ${arabicDigits(wird.doneCount(items))} من ${arabicDigits(items.length)}',
          key: const ValueKey<String>('adhkar-progress'),
          style: text.bodyMedium?.copyWith(color: palette.inkSoft),
        ),
        const SizedBox(height: 12),
        _ItemPills(items: items, wird: wird, onSelect: ref.read(adhkarWirdProvider.notifier).select),
        const SizedBox(height: 14),
        if (complete) ...<Widget>[
          _WirdCompleteBadge(
            total: items.length,
            onRestart: ref.read(adhkarWirdProvider.notifier).restart,
          ),
          const SizedBox(height: 14),
        ],
        DhikrCard(
          key: ValueKey<String>('dhikr-${item.id}'),
          item: item,
          position: index + 1,
          total: items.length,
          count: wird.countOf(index),
          onTap: _onCardTap,
        ),
        const SizedBox(height: 18),
        _EvidenceSection(item: item, sources: sources),
        const SizedBox(height: 14),
        Text(
          'نصوص الأذكار وأعدادها منقولة من ملف البيانات حرفياً بشواهدها، ولا يُضاف إليها شيء من خارجه. '
          'ما عدا ذلك من الأذكار يصل مع حزمة المحتوى النهائية.',
          style: text.labelSmall?.copyWith(color: palette.inkSoft, height: 1.7),
        ),
      ],
    );
  }
}

/// أذكار الوِرد رقائق أفقية: الحالي مظلل، والمكتمل بعلامة.
class _ItemPills extends StatelessWidget {
  const _ItemPills({required this.items, required this.wird, required this.onSelect});

  final List<DhikrItem> items;
  final AdhkarWirdState wird;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (BuildContext context, int _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int i) {
          final bool current = i == wird.index;
          final bool done = wird.isDone(items, i);
          final Color foreground = done ? palette.emeraldText : (current ? palette.amberText : palette.inkSoft);
          return Semantics(
            label: 'الذكر ${arabicDigits(i + 1)}: ${items[i].title}${done ? '، مكتمل' : ''}',
            child: ExcludeSemantics(
              child: ChoiceChip(
                key: ValueKey<String>('adhkar-pill-$i'),
                selected: current,
                onSelected: (bool _) => onSelect(i),
                avatar: Icon(
                  done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: foreground,
                ),
                label: Text(items[i].title),
                selectedColor: palette.amberSoft,
                backgroundColor: done ? palette.emeraldSoft : palette.surface,
                side: BorderSide(color: done ? palette.emerald : (current ? palette.amber : palette.line)),
                shape: AppShapes.rounded(AppShapes.radiusSmall),
                showCheckmark: false,
                labelStyle: AppTypography.ui(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: current ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// شارة إتمام الوِرد.
class _WirdCompleteBadge extends StatelessWidget {
  const _WirdCompleteBadge({required this.total, required this.onRestart});

  final int total;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return SmoothSurface(
      key: const ValueKey<String>('adhkar-wird-complete'),
      color: palette.emeraldSoft,
      borderColor: palette.emerald.withValues(alpha: 0.5),
      radius: AppShapes.radiusMedium,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: <Widget>[
          Icon(Icons.workspace_premium_rounded, size: 34, color: palette.emeraldText),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'أتممتَ وِرد الأذكار',
                  style: text.titleMedium?.copyWith(color: palette.emeraldText, fontWeight: FontWeight.w700),
                ),
                Text(
                  'بلغتَ العدد المسنون في ${arabicDigits(total)} من ${arabicDigits(total)}.',
                  style: text.bodySmall?.copyWith(color: palette.emeraldText),
                ),
              ],
            ),
          ),
          TextButton(
            key: const ValueKey<String>('adhkar-restart'),
            onPressed: onRestart,
            child: const Text('وِرد جديد'),
          ),
        ],
      ),
    );
  }
}

/// شواهد الذكر الحالي بنصها الحرفي وموضعها، وحالة مراجعتها.
class _EvidenceSection extends StatelessWidget {
  const _EvidenceSection({required this.item, required this.sources});

  final DhikrItem item;
  final SourceCatalog? sources;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                item.evidence.length == 1 ? 'المصدر' : 'المصادر (${arabicDigits(item.evidence.length)})',
                style: text.labelLarge?.copyWith(color: palette.inkSoft, fontWeight: FontWeight.w700),
              ),
            ),
            SoftChip(label: reviewStatusLabel(item.review.status), icon: Icons.fact_check_outlined),
          ],
        ),
        const SizedBox(height: 8),
        for (final SourceRef reference in item.evidence) ...<Widget>[
          SourceQuoteTile(reference: reference, source: sources?.byId(reference.sourceId)),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final String detail = switch (error) {
      AdhkarIntegrityException(:final List<String> issues) => issues.join('\n'),
      JsonParseException(:final String message) => message,
      _ => error.toString(),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.spa_outlined, size: 44, color: palette.inkSoft),
            const SizedBox(height: 12),
            Text(
              'تعذّر تجهيز وِرد الأذكار',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'لم يُعرض شيء حتى لا يظهر ذكر بلا شاهده الموثق.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: palette.inkSoft),
            ),
            const SizedBox(height: 10),
            SelectableText(
              detail,
              textAlign: TextAlign.center,
              style: text.labelSmall?.copyWith(color: palette.inkSoft),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
