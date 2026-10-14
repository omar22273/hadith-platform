// شريط حجم الخط: منزلق مربوط بإعداد «حجم خط المتن» نفسه الذي في شاشة الإعدادات،
// فتحريكه في أي موضع يغيّر الحجم في المواضع كلها. يشترك فيه قسم الرواية التاريخية
// في السيرة وورقة «شرح الحديث» في الحديث.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../preferences/reading_preferences.dart';
import '../text/arabic_digits.dart';
import '../theme/app_palette.dart';
import 'app_shapes.dart';
import 'smooth_surface.dart';

/// مفتاح منزلق الرواية التاريخية في السيرة (تعتمد عليه اختباراتها).
const ValueKey<String> narrativeFontSliderKey = ValueKey<String>('narrative-font-slider');

/// شريط حجم الخط.
class ReadingSizeBar extends ConsumerWidget {
  const ReadingSizeBar({super.key, this.sliderKey = narrativeFontSliderKey});

  /// مفتاح المنزلق؛ يختلف باختلاف الموضع كي لا يتعارض في الاختبارات.
  final Key sliderKey;

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
              key: sliderKey,
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
