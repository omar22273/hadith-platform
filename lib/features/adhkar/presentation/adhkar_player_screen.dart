// مشغّل التركيز لفئة من الأذكار: شاشة هادئة بثلاثة عناصر بصرية لا غير:
//
// 1. الرأس: زر الرجوع، واسم الفئة وعنوان الذكر الحالي، وشريط تقدم رفيع بموضعه
//    («٣ / ١٥»)، وزر معلومات دائري صغير. لا شرائح اختيار ولا قوائم.
// 2. المتن: نص الذكر المشكول كبيراً في المنتصف، يتمرر داخلياً بنعومة إن طال.
// 3. النصف السفلي: منطقة لمس واحدة تحتسب أي نقرة، وفيها عدّاد دائري هادئ «باقٍ N».
//
// الانتقال بين الأذكار بسحب الصفحة أفقياً (PageView). التخريج والفضل النبوي
// والمصدر كلها في ورقة تُفتح من زر المعلومات، لا على الشاشة.
//
// عند بلوغ العدد المسنون: اهتزاز مزدوج، وقفل العدّاد، ثم ينتقل الوِرد إلى الذكر
// التالي بـ PageView.nextPage، أو تظهر شارة إتمام الوِرد.
//
// الخط الأحمر: نصوص الأذكار وشواهدها وفضلها تأتي من ملف البيانات وحده.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/content/models/source_catalog.dart';
import '../../../core/content/source_catalog_provider.dart';
import '../../../core/json/json_reader.dart';
import '../../../core/text/arabic_digits.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/ui/app_shapes.dart';
import '../../../core/ui/smooth_surface.dart';
import '../application/adhkar_providers.dart';
import '../application/adhkar_wird_controller.dart';
import '../data/models/adhkar.dart';
import '../domain/adhkar_category.dart';
import '../domain/adhkar_repository.dart';
import 'widgets/dhikr_info_sheet.dart';
import 'widgets/dhikr_page.dart';

/// مدة انزلاق الصفحة عند الانتقال التلقائي.
const Duration _pageSlide = Duration(milliseconds: 380);

/// مشغّل التركيز لفئة.
class AdhkarPlayerScreen extends ConsumerWidget {
  const AdhkarPlayerScreen({super.key, required this.category});

  /// الفئة المعروضة.
  final AdhkarCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AdhkarCatalog> catalog = ref.watch(adhkarCatalogProvider(category.id));
    final Widget body;
    if (catalog.hasError) {
      body = _ErrorView(
        error: catalog.error!,
        onRetry: () => ref.invalidate(adhkarCatalogProvider(category.id)),
      );
    } else if (catalog.value == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = _PlayerBody(category: category);
    }
    return Scaffold(
      key: ValueKey<String>('adhkar-player-${category.id}'),
      body: SafeArea(child: body),
    );
  }
}

class _PlayerBody extends ConsumerStatefulWidget {
  const _PlayerBody({required this.category});

  final AdhkarCategory category;

  @override
  ConsumerState<_PlayerBody> createState() => _PlayerBodyState();
}

class _PlayerBodyState extends ConsumerState<_PlayerBody> {
  late final PageController _pages;
  Timer? _secondPulse;

  /// صحيح وقت انزلاق الصفحات برمجياً؛ تمرّ الصفحات الوسيطة فلا تُعامل اختياراً.
  bool _sliding = false;

  /// رقم آخر انزلاق برمجي: انزلاق أحدث يُبطل خاتمة ما قبله.
  int _slideToken = 0;

  String get _id => widget.category.id;

  @override
  void initState() {
    super.initState();
    final int total = ref.read(adhkarItemsProvider(_id)).length;
    final int start = ref.read(adhkarWirdProvider(_id)).index;
    _pages = PageController(initialPage: total == 0 ? 0 : start.clamp(0, total - 1).toInt());
  }

  @override
  void dispose() {
    _secondPulse?.cancel();
    _pages.dispose();
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

  void _onTap() {
    final DhikrTapResult result = ref.read(adhkarWirdProvider(_id).notifier).tap();
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

  /// استقرت صفحة بسحب المستخدم: الذكر المختار هو الذكر الحالي.
  void _onPageChanged(int page) {
    if (_sliding) {
      return;
    }
    ref.read(adhkarWirdProvider(_id).notifier).select(page);
  }

  /// تغيّر الذكر الحالي من المتحكم (انتقال تلقائي أو وِرد جديد): تتبعه الصفحة.
  void _followIndex(int? previous, int next) {
    if (!_pages.hasClients) {
      return;
    }
    final int shown = _pages.page?.round() ?? _pages.initialPage;
    if (shown == next && !_sliding) {
      return;
    }
    final bool still = MediaQuery.disableAnimationsOf(context);
    if (still) {
      _slideToken++;
      _sliding = false;
      _pages.jumpToPage(next);
      return;
    }
    final bool adjacent = !_sliding && next == shown + 1;
    final int token = ++_slideToken;
    _sliding = true;
    final Future<void> slide = adjacent
        ? _pages.nextPage(duration: _pageSlide, curve: Curves.easeInOutCubic)
        : _pages.animateToPage(next, duration: _pageSlide, curve: Curves.easeInOutCubic);
    unawaited(
      slide.whenComplete(() {
        if (token == _slideToken) {
          _sliding = false;
        }
      }),
    );
  }

  void _showInfo(DhikrItem item, SourceCatalog? sources) {
    unawaited(showDhikrInfoSheet(context: context, item: item, sources: sources));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(adhkarWirdProvider(_id).select((AdhkarWirdState s) => s.index), _followIndex);
    final List<DhikrItem> items = ref.watch(adhkarItemsProvider(_id));
    final AdhkarWirdState wird = ref.watch(adhkarWirdProvider(_id));
    final SourceCatalog? sources = ref.watch(sourceCatalogProvider).value;
    if (items.isEmpty || wird.counts.length != items.length) {
      return const Center(child: CircularProgressIndicator());
    }
    final int index = wird.index.clamp(0, items.length - 1).toInt();
    final DhikrItem item = items[index];
    final bool complete = wird.isComplete(items);
    return Column(
      children: <Widget>[
        _Header(
          categoryTitle: widget.category.title,
          item: item,
          position: index + 1,
          total: items.length,
          onInfo: () => _showInfo(item, sources),
        ),
        if (complete)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: _WirdCompleteBadge(
              total: items.length,
              onRestart: ref.read(adhkarWirdProvider(_id).notifier).restart,
            ),
          ),
        Expanded(
          child: PageView.builder(
            key: const ValueKey<String>('adhkar-pages'),
            controller: _pages,
            itemCount: items.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (BuildContext context, int i) {
              return DhikrPage(
                key: ValueKey<String>('dhikr-page-${items[i].id}'),
                item: items[i],
                count: wird.countOf(i),
                onTap: _onTap,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// الرأس: رجوع، واسم الفئة وعنوان الذكر الحالي، وزر المعلومات، وتحتها شريط التقدم الرفيع.
class _Header extends StatelessWidget {
  const _Header({
    required this.categoryTitle,
    required this.item,
    required this.position,
    required this.total,
    required this.onInfo,
  });

  final String categoryTitle;
  final DhikrItem item;

  /// رقم الذكر الحالي من ١.
  final int position;
  final int total;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final String where = '${arabicDigits(position)} / ${arabicDigits(total)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                key: const ValueKey<String>('adhkar-back'),
                tooltip: 'الرجوع إلى مركز الأذكار',
                onPressed: () => Navigator.of(context).maybePop(),
                color: palette.inkSoft,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      categoryTitle,
                      key: const ValueKey<String>('adhkar-category-title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelMedium?.copyWith(color: palette.inkSoft, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      item.title,
                      key: const ValueKey<String>('adhkar-title'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.heritageTitle(color: palette.ink, fontSize: 24),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                key: const ValueKey<String>('adhkar-info'),
                tooltip: 'التخريج والفضل والمصدر',
                onPressed: onInfo,
                visualDensity: VisualDensity.compact,
                iconSize: 22,
                color: palette.inkSoft,
                style: IconButton.styleFrom(
                  side: BorderSide(color: palette.line),
                  shape: const CircleBorder(),
                ),
                icon: const Icon(Icons.info_outline),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8),
            child: Semantics(
              label: 'الذكر ${arabicDigits(position)} من ${arabicDigits(total)}',
              child: ExcludeSemantics(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          key: const ValueKey<String>('adhkar-progress-bar'),
                          value: position / total,
                          minHeight: 3,
                          backgroundColor: palette.line,
                          color: palette.amber,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        where,
                        key: const ValueKey<String>('adhkar-progress'),
                        style: text.labelMedium?.copyWith(
                          color: palette.inkSoft,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: <Widget>[
          Icon(Icons.workspace_premium_rounded, size: 28, color: palette.emeraldText),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'أتممتَ هذا الوِرد',
                  style: text.titleSmall?.copyWith(color: palette.emeraldText, fontWeight: FontWeight.w700),
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
              'تعذّر تجهيز هذه الفئة',
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
            const SizedBox(height: 8),
            TextButton(
              key: const ValueKey<String>('adhkar-error-back'),
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('الرجوع'),
            ),
          ],
        ),
      ),
    );
  }
}
