// جذر التطبيق: لغة عربية واتجاه من اليمين، وسمتان (النهاري التراثي والداكن)
// تتبدلان بانتقال ناعم وتُحفظان في SharedPreferences، وإعدادات الخطوط والحجم،
// والشاشة الرئيسية غلاف التبويبات الأربعة.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/diagnostics/diagnostic_views.dart';
import '../core/preferences/reading_preferences.dart';
import '../core/preferences/theme_preference.dart';
import '../core/theme/app_theme.dart';
import 'app_shell_screen.dart';

/// التطبيق.
class HadithApp extends ConsumerWidget {
  const HadithApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemePreference theme = ref.watch(themePreferenceProvider);
    final ReadingPreferences reading = ref.watch(readingPreferencesProvider);
    return MaterialApp(
      title: 'منصة الحديث النبوي',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(reading: reading.readingTheme),
      darkTheme: AppTheme.dark(reading: reading.readingTheme),
      themeMode: theme.themeMode,
      themeAnimationDuration: const Duration(milliseconds: 450),
      themeAnimationCurve: Curves.easeInOutCubic,
      locale: const Locale('ar'),
      supportedLocales: const <Locale>[Locale('ar')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData media = MediaQuery.of(context);
        final double systemScale = media.textScaler.scale(14) / 14;
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(systemScale * reading.textScale)),
          child: child ?? const DiagnosticLoadingView(),
        );
      },
      home: const AppShellScreen(),
    );
  }
}
