// بطاقة قسم في شاشة الإعدادات: أيقونة وعنوان تراثي ثم محتوى القسم.

import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/smooth_surface.dart';

/// بطاقة قسم.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.title, required this.icon, required this.children});

  /// عنوان القسم.
  final String title;

  /// أيقونة القسم.
  final IconData icon;

  /// محتوى القسم.
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
              Expanded(
                child: Text(title, style: AppTypography.heritageTitle(color: palette.ink, fontSize: 22)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
