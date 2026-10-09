// غلاف التطبيق (AppShellScreen): شريط تنقل سفلي بأربعة تبويبات، وIndexedStack
// يحفظ حالة كل تبويب أثناء التنقل فلا تُعاد تهيئة الواجهات. يُبنى التبويب أول
// مرة عند زيارته ثم يبقى حياً.
//
// زر الرجوع في غير التبويب الأول يعيد إليه بدل إغلاق التطبيق، وعودة التطبيق
// من الخلفية تقدّم الساعة المرجعية فيُعاد حساب قفل الفجر والاستمرارية.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/diagnostics/diagnostic_views.dart';
import '../core/navigation/app_tab.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_typography.dart';
import '../core/time/clock.dart';
import '../core/ui/app_shapes.dart';
import '../features/journey/presentation/arbaeen_path_screen.dart';
import '../features/review/presentation/review_arena_screen.dart';
import '../features/seerah/presentation/seerah_journey_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

/// الغلاف.
class AppShellScreen extends ConsumerStatefulWidget {
  const AppShellScreen({super.key});

  @override
  ConsumerState<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends ConsumerState<AppShellScreen> {
  final Set<AppTab> _built = <AppTab>{AppTab.arbaeen};
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(nowProvider.notifier).tick(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  static Widget _screenFor(AppTab tab) {
    switch (tab) {
      case AppTab.arbaeen:
        return const ArbaeenPathScreen();
      case AppTab.seerah:
        return const SeerahJourneyScreen();
      case AppTab.review:
        return const ReviewArenaScreen();
      case AppTab.settings:
        return const SettingsScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppTab current = ref.watch(appTabProvider);
    _built.add(current);
    return PopScope(
      canPop: current == AppTab.arbaeen,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          ref.read(appTabProvider.notifier).select(AppTab.arbaeen);
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: current.index,
          sizing: StackFit.expand,
          children: <Widget>[
            for (final AppTab tab in AppTab.values)
              _built.contains(tab)
                  ? TickerMode(
                      enabled: tab == current,
                      child: KeyedSubtree(
                        key: PageStorageKey<AppTab>(tab),
                        child: SizedBox.expand(child: _screenFor(tab)),
                      ),
                    )
                  : const DiagnosticLoadingView(),
          ],
        ),
        bottomNavigationBar: AppBottomBar(
          current: current,
          onSelect: (AppTab tab) => ref.read(appTabProvider.notifier).select(tab),
        ),
      ),
    );
  }
}

/// شريط التنقل السفلي.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({super.key, required this.current, required this.onSelect});

  /// التبويب الحالي.
  final AppTab current;

  /// اختيار تبويب.
  final ValueChanged<AppTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.line)),
        boxShadow: <BoxShadow>[
          BoxShadow(color: palette.shadow, blurRadius: 18, offset: const Offset(0, -4), spreadRadius: -10),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final AppTab tab in AppTab.values)
                Expanded(
                  child: _NavItem(
                    tab: tab,
                    selected: tab == current,
                    onTap: () => onSelect(tab),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.tab, required this.selected, required this.onTap});

  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Duration duration =
        MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 240);
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          shape: AppShapes.rounded(AppShapes.radiusMedium),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: Column(
                  // بدون min يمتد العمود إلى ارتفاع الشاشة كله فيستهلك الشريط
                  // مساحة المحتوى ويصير جسم الصفحة صفري الارتفاع.
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    AnimatedContainer(
                      duration: duration,
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.symmetric(horizontal: selected ? 18 : 10, vertical: 4),
                      decoration: ShapeDecoration(
                        color: selected ? palette.amberSoft : Colors.transparent,
                        shape: AppShapes.rounded(AppShapes.radiusSmall),
                      ),
                      child: Icon(
                        selected ? tab.selectedIcon : tab.icon,
                        size: 24,
                        color: selected ? palette.amberText : palette.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        tab.label,
                        maxLines: 1,
                        style: AppTypography.ui(
                          color: selected ? palette.ink : palette.inkSoft,
                          fontSize: 11.5,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          height: 1.3,
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
