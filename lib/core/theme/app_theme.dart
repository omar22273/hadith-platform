// بناء ThemeData للوضعين النهاري التراثي والداكن من لوحة الألوان والخطوط
// والحواف الناعمة، مع امتداد إعدادات القراءة (حجم خط المتن وعائلته).

import 'package:flutter/material.dart';

import '../ui/app_shapes.dart';
import 'app_palette.dart';
import 'app_typography.dart';
import 'reading_theme.dart';

/// ثيمات التطبيق.
abstract final class AppTheme {
  /// الوضع النهاري التراثي (Warm Parchment): كتان عاجي وحبر فحمي.
  static ThemeData light({ReadingTheme reading = ReadingTheme.standard}) {
    return _build(Brightness.light, AppPalette.light, reading);
  }

  /// الوضع الداكن: خلفية #0F172A وبطاقات #1E293B.
  static ThemeData dark({ReadingTheme reading = ReadingTheme.standard}) {
    return _build(Brightness.dark, AppPalette.dark, reading);
  }

  static ThemeData _build(Brightness brightness, AppPalette palette, ReadingTheme reading) {
    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: palette.amber,
      onPrimary: palette.onAccent,
      secondary: palette.emerald,
      onSecondary: palette.onAccent,
      error: palette.amberDeep,
      onError: palette.onAccent,
      surface: palette.surface,
      onSurface: palette.ink,
      outline: palette.line,
      outlineVariant: palette.line,
    );
    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.paper,
      canvasColor: palette.paper,
      fontFamily: AppTypography.readexPro,
    );
    final TextTheme textTheme = AppTypography.textTheme(base.textTheme, palette);
    return base.copyWith(
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[palette, reading],
      appBarTheme: AppBarTheme(
        backgroundColor: palette.paper,
        foregroundColor: palette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.paper,
        modalBackgroundColor: palette.paper,
        surfaceTintColor: Colors.transparent,
        shape: AppShapes.sheetTop(),
        showDragHandle: true,
        dragHandleColor: palette.line,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll<Size>(Size(64, 52)),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            AppShapes.rounded(AppShapes.radiusMedium),
          ),
          backgroundColor: WidgetStateProperty.resolveWith<Color>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.disabled)) {
                return palette.lockedSoft;
              }
              return palette.ink;
            },
          ),
          foregroundColor: WidgetStateProperty.resolveWith<Color>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.disabled)) {
                return palette.locked;
              }
              return palette.paper;
            },
          ),
          textStyle: WidgetStatePropertyAll<TextStyle>(
            AppTypography.ui(
              color: palette.paper,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll<Size>(Size(64, 52)),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            AppShapes.rounded(AppShapes.radiusMedium),
          ),
          side: WidgetStatePropertyAll<BorderSide>(
            BorderSide(color: palette.line),
          ),
          foregroundColor: WidgetStatePropertyAll<Color>(palette.ink),
          textStyle: WidgetStatePropertyAll<TextStyle>(
            AppTypography.ui(
              color: palette.ink,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            AppShapes.rounded(AppShapes.radiusSmall),
          ),
          foregroundColor: WidgetStatePropertyAll<Color>(palette.amberText),
        ),
      ),
      dividerTheme: DividerThemeData(color: palette.line, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.ink,
        contentTextStyle: AppTypography.ui(color: palette.paper, fontSize: 14),
        shape: AppShapes.rounded(AppShapes.radiusMedium),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.amber,
        linearTrackColor: palette.line,
        circularTrackColor: palette.line,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: palette.ink,
        unselectedLabelColor: palette.inkSoft,
        indicatorColor: palette.amber,
        dividerColor: palette.line,
        labelStyle: AppTypography.ui(
          color: palette.ink,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: AppTypography.ui(color: palette.inkSoft, fontSize: 14),
      ),
      iconTheme: IconThemeData(color: palette.ink),
      sliderTheme: SliderThemeData(
        activeTrackColor: palette.amber,
        inactiveTrackColor: palette.line,
        thumbColor: palette.amber,
        overlayColor: palette.amber.withValues(alpha: 0.14),
        valueIndicatorColor: palette.ink,
        valueIndicatorTextStyle: AppTypography.ui(color: palette.paper, fontSize: 13),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return palette.onAccent;
            }
            return palette.locked;
          },
        ),
        trackColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return palette.emerald;
            }
            return palette.lockedSoft;
          },
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.transparent;
            }
            return palette.line;
          },
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: AppShapes.rounded(AppShapes.radiusLarge),
        titleTextStyle: AppTypography.heritageTitle(color: palette.ink, fontSize: 24),
        contentTextStyle: AppTypography.ui(color: palette.ink, fontSize: 15),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        labelStyle: AppTypography.ui(color: palette.inkSoft, fontSize: 14),
        hintStyle: AppTypography.ui(color: palette.locked, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
          borderSide: BorderSide(color: palette.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
          borderSide: BorderSide(color: palette.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
          borderSide: BorderSide(color: palette.amber, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
          borderSide: BorderSide(color: palette.amberDeep, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
          borderSide: BorderSide(color: palette.amberDeep, width: 1.6),
        ),
        errorStyle: AppTypography.ui(color: palette.amberText, fontSize: 12),
      ),
    );
  }
}
