// التبويب الرابع: الإعدادات. السمة (النهاري التراثي أو الداكن)، والخطوط
// والحجم، ووتيرة الأوراد، وطريقة التلقي، ورقم الإصدار الذي تفتح النقرات
// الخمس المتتالية عليه بوابة الإدخال المحلية.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/preferences/reading_preferences.dart';
import '../../../core/preferences/reception_mode.dart';
import '../../../core/preferences/theme_preference.dart';
import '../../../core/text/arabic_digits.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/ui/app_shapes.dart';
import '../../../core/ui/smooth_surface.dart';
import '../../admin/presentation/admin_export_screen.dart';
import '../../journey/application/pacing_notifier.dart';
import '../../journey/domain/pacing.dart';
import '../../journey/presentation/widgets/wird_labels.dart';

/// شاشة الإعدادات.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4, bottom: 12),
              child: Text(
                'الإعدادات',
                style: AppTypography.heritageTitle(color: palette.ink, fontSize: 34),
              ),
            ),
            const _ThemeSection(),
            const SizedBox(height: 14),
            const _ReadingSection(),
            const SizedBox(height: 14),
            const _PacingSection(),
            const SizedBox(height: 14),
            const _ReceptionSection(),
            const SizedBox(height: 14),
            const _AboutSection(),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.icon, required this.children});

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return SmoothSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: palette.amberText),
              const SizedBox(width: 8),
              Text(title, style: AppTypography.heritageTitle(color: palette.ink, fontSize: 22)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

/// اختيار بين عناصر متنافية بمظهر الحواف الناعمة.
class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.iconOf,
    this.enabledOf,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;
  final IconData Function(T value)? iconOf;
  final bool Function(T value)? enabledOf;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: palette.surfaceMuted,
        shape: AppShapes.rounded(AppShapes.radiusMedium, side: BorderSide(color: palette.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          children: <Widget>[
            for (int i = 0; i < values.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 6),
              Expanded(child: _option(context, palette, values[i])),
            ],
          ],
        ),
      ),
    );
  }

  Widget _option(BuildContext context, AppPalette palette, T value) {
    final bool isSelected = value == selected;
    final bool enabled = enabledOf?.call(value) ?? true;
    final Color foreground = isSelected ? palette.paper : (enabled ? palette.inkSoft : palette.locked);
    final IconData? icon = iconOf?.call(value);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: isSelected,
      button: true,
      enabled: enabled,
      label: labelOf(value),
      child: Material(
        color: isSelected ? palette.ink : Colors.transparent,
        shape: AppShapes.rounded(AppShapes.radiusSmall),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? () => onSelected(value) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 50),
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (icon != null) Icon(icon, size: 20, color: foreground),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        labelOf(value),
                        maxLines: 1,
                        style: AppTypography.ui(
                          color: foreground,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
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

class _ThemeSection extends ConsumerWidget {
  const _ThemeSection();

  static IconData _icon(ThemePreference preference) {
    switch (preference) {
      case ThemePreference.system:
        return Icons.brightness_auto_rounded;
      case ThemePreference.parchment:
        return Icons.wb_sunny_outlined;
      case ThemePreference.dark:
        return Icons.dark_mode_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final ThemePreference preference = ref.watch(themePreferenceProvider);
    return _Card(
      title: 'السمة',
      icon: Icons.palette_outlined,
      children: <Widget>[
        _ChoiceRow<ThemePreference>(
          values: ThemePreference.values,
          selected: preference,
          labelOf: (ThemePreference value) => value.label,
          iconOf: _icon,
          onSelected: (ThemePreference value) => ref.read(themePreferenceProvider.notifier).select(value),
        ),
        const SizedBox(height: 10),
        Text(
          'النهاري التراثي: كتان عاجي مريح للعين وحبر فحمي ولمسات كهرمانية وزمردية هادئة. '
          'الداكن: كحلي فاحم بالذهبي والزمردي.',
          style: text.bodySmall?.copyWith(color: palette.inkSoft, height: 1.7),
        ),
      ],
    );
  }
}

class _ReadingSection extends ConsumerWidget {
  const _ReadingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final ReadingPreferences reading = ref.watch(readingPreferencesProvider);
    final ReadingPreferencesController controller = ref.read(readingPreferencesProvider.notifier);
    return _Card(
      title: 'الخطوط والحجم',
      icon: Icons.text_fields_rounded,
      children: <Widget>[
        Text('خط المتن', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _ChoiceRow<MatnFont>(
          values: MatnFont.values,
          selected: reading.matnFont,
          labelOf: (MatnFont value) => '${value.label} · ${value.caption}',
          onSelected: controller.setMatnFont,
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: Text('حجم خط المتن', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ),
            Text(
              arabicDigits(reading.matnFontSize.round()),
              style: text.titleSmall?.copyWith(color: palette.amberText, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        Slider(
          value: reading.matnFontSize,
          min: ReadingPreferences.minMatnFontSize,
          max: ReadingPreferences.maxMatnFontSize,
          divisions: (ReadingPreferences.maxMatnFontSize - ReadingPreferences.minMatnFontSize).round(),
          label: arabicDigits(reading.matnFontSize.round()),
          onChanged: controller.setMatnFontSize,
        ),
        SmoothSurface(
          color: palette.surfaceMuted,
          radius: AppShapes.radiusSmall,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text(
            'نَمُوذَجٌ لِحَجْمِ خَطِّ الْمَتْنِ وَضَبْطِهِ',
            textAlign: TextAlign.center,
            style: AppTypography.matn(
              color: palette.ink,
              fontSize: reading.matnFontSize,
            ).copyWith(fontFamily: reading.matnFont.family),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: Text('حجم نصوص الواجهة', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ),
            Text(
              arabicPercent(reading.textScale),
              style: text.titleSmall?.copyWith(color: palette.amberText, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        Slider(
          value: reading.textScale,
          min: ReadingPreferences.minTextScale,
          max: ReadingPreferences.maxTextScale,
          divisions: 8,
          label: arabicPercent(reading.textScale),
          onChanged: controller.setTextScale,
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: controller.reset,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('استعادة الأحجام الأصلية'),
          ),
        ),
      ],
    );
  }
}

class _PacingSection extends ConsumerWidget {
  const _PacingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final AsyncValue<PacingState> pacingValue = ref.watch(pacingProvider);
    final PacingState? pacing = pacingValue.value;
    if (pacing == null) {
      return _Card(
        title: 'وتيرة الأوراد',
        icon: Icons.speed_rounded,
        children: <Widget>[
          if (pacingValue.hasError)
            Text('تعذّر حساب الوتيرة.', style: text.bodySmall?.copyWith(color: palette.inkSoft))
          else
            const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    final PacingNotifier notifier = ref.read(pacingProvider.notifier);
    return _Card(
      title: 'وتيرة الأوراد',
      icon: Icons.speed_rounded,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _StatTile(
                icon: Icons.local_fire_department_rounded,
                value: arabicDigits(pacing.streakDays),
                label: 'أيام متتالية',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                icon: Icons.emoji_events_outlined,
                value: arabicDigits(pacing.bestStreak),
                label: 'أفضل استمرارية',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('الأحاديث الجديدة يومياً', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final PaceTier tier in PacePolicy.tiers)
          _TierTile(
            tier: tier,
            selected: pacing.dailyQuota == tier.perDay,
            unlocked: pacing.isTierUnlocked(tier),
            remaining: tier.requiredStreak - pacing.streakDays,
            onSelect: () => unawaited(notifier.selectQuota(tier.perDay)),
          ),
        const SizedBox(height: 6),
        Text(
          'تبدأ الوتيرة بحديث واحد يومياً لمنع التشتت؛ ويُتاح «حديثان» بعد سبعة أيام متتالية، و«ثلاثة» بعد أربعة عشر يوماً. '
          'ما يُفتح لا يُسلب بانقطاع يوم.',
          style: text.bodySmall?.copyWith(color: palette.inkSoft, height: 1.7),
        ),
        const Divider(height: 28),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: pacing.settings.alwaysBypassLock,
          onChanged: (bool value) => unawaited(notifier.setAlwaysBypass(value)),
          title: const Text('تخطي قفل الفجر دائماً'),
          subtitle: const Text('لأغراض التجربة فقط: تُفتح الأحاديث الجديدة دون انتظار الفجر.'),
          secondary: Icon(Icons.science_outlined, color: palette.amberText),
        ),
        if (!pacing.settings.alwaysBypassLock && pacing.locked)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => unawaited(notifier.bypassTodayLock()),
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('تخطي قفل اليوم مرة واحدة'),
            ),
          ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return SmoothSurface(
      color: palette.amberSoft,
      borderColor: palette.amber.withValues(alpha: 0.3),
      radius: AppShapes.radiusMedium,
      padding: const EdgeInsets.all(12),
      semanticLabel: '$label: $value',
      child: Row(
        children: <Widget>[
          Icon(icon, color: palette.amberText),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(value, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.2)),
                Text(label, style: text.labelSmall?.copyWith(color: palette.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TierTile extends StatelessWidget {
  const _TierTile({
    required this.tier,
    required this.selected,
    required this.unlocked,
    required this.remaining,
    required this.onSelect,
  });

  final PaceTier tier;
  final bool selected;
  final bool unlocked;
  final int remaining;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final String caption = unlocked
        ? (tier.requiredStreak == 0 ? 'الوتيرة الأساسية' : 'فُتحت بالاستمرارية')
        : 'تُفتح بعد ${daysLabel(tier.requiredStreak)} متتالية · بقي ${daysLabel(remaining < 1 ? 1 : remaining)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        checked: selected,
        enabled: unlocked,
        button: true,
        child: SmoothSurface(
          onTap: unlocked ? onSelect : null,
          color: selected ? palette.emeraldSoft : (unlocked ? palette.surface : palette.surfaceMuted),
          borderColor: selected ? palette.emerald : palette.line,
          borderWidth: selected ? 1.6 : 1,
          radius: AppShapes.radiusMedium,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Icon(
                unlocked
                    ? (selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded)
                    : Icons.lock_outline_rounded,
                color: unlocked ? (selected ? palette.emeraldText : palette.inkSoft) : palette.locked,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${hadithCountLabel(tier.perDay)} يومياً',
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: unlocked ? palette.ink : palette.inkSoft,
                      ),
                    ),
                    Text(caption, style: text.labelSmall?.copyWith(color: palette.inkSoft)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceptionSection extends ConsumerWidget {
  const _ReceptionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ReceptionMode mode = ref.watch(receptionModeProvider);
    return _Card(
      title: 'طريقة التلقي المفضلة',
      icon: Icons.hearing_rounded,
      children: <Widget>[
        _ChoiceRow<ReceptionMode>(
          values: ReceptionMode.values,
          selected: mode,
          labelOf: (ReceptionMode value) => value == ReceptionMode.touch ? 'القراءة واللمس' : 'السماع والمشافهة',
          iconOf: (ReceptionMode value) =>
              value == ReceptionMode.touch ? Icons.touch_app_rounded : Icons.headphones_rounded,
          onSelected: (ReceptionMode value) => ref.read(receptionModeProvider.notifier).select(value),
        ),
      ],
    );
  }
}

class _AboutSection extends ConsumerStatefulWidget {
  const _AboutSection();

  @override
  ConsumerState<_AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends ConsumerState<_AboutSection> {
  static const int _requiredTaps = 5;
  static const Duration _tapWindow = Duration(milliseconds: 1200);

  int _taps = 0;
  DateTime? _lastTap;

  void _onVersionTap() {
    final DateTime now = DateTime.now();
    final DateTime? last = _lastTap;
    _taps = last != null && now.difference(last) <= _tapWindow ? _taps + 1 : 1;
    _lastTap = now;
    if (_taps < _requiredTaps) {
      return;
    }
    _taps = 0;
    _lastTap = null;
    unawaited(HapticFeedback.mediumImpact());
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (BuildContext routeContext) => const AdminExportScreen()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final AppConfig config = ref.watch(appConfigProvider);
    return _Card(
      title: 'حول المنصة',
      icon: Icons.info_outline_rounded,
      children: <Widget>[
        Text(
          'منصة الحديث النبوي والتاريخ الإسلامي: الأربعون النووية وِرداً يومياً، ورحلة السيرة بمشاهدها الثلاثة. '
          'كل متن وشاهد يُقرأ من ملفات البيانات الموثقة بنصه وضبطه، ولا يولّد التطبيق نصاً ولا حكماً.',
          style: text.bodySmall?.copyWith(color: palette.inkSoft, height: 1.8),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'منصة الحديث النبوي',
              applicationVersion: config.version,
            ),
            icon: const Icon(Icons.description_outlined),
            label: const Text('التراخيص والخطوط'),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Semantics(
            label: 'رقم الإصدار ${config.version}',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onVersionTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Text(
                  'Version ${config.version}',
                  textDirection: TextDirection.ltr,
                  style: text.labelMedium?.copyWith(color: palette.locked, letterSpacing: 0.4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
