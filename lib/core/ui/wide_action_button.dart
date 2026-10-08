// زر عريض بمساحة لمس كبيرة، بعنوان ووصف وأيقونة. النسخة العملاقة لوضع السماع.

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import 'app_shapes.dart';
import 'smooth_surface.dart';

/// درجة إبراز الزر.
enum WideActionTone {
  /// تدرج كهرماني: الفعل الأساسي.
  primary,

  /// سطح بحد كهرماني: فعل بديل مكافئ.
  secondary,

  /// سطح هادئ: فعل ثانوي.
  quiet,
}

/// زر عريض.
class WideActionButton extends StatelessWidget {
  const WideActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.subtitle,
    this.tone = WideActionTone.primary,
    this.giant = false,
  });

  /// عنوان الزر.
  final String label;

  /// الأيقونة.
  final IconData icon;

  /// الفعل؛ null يعطل الزر.
  final VoidCallback? onPressed;

  /// سطر وصفي تحت العنوان.
  final String? subtitle;

  /// درجة الإبراز.
  final WideActionTone tone;

  /// مساحة لمس عملاقة لكبار السن.
  final bool giant;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final bool enabled = onPressed != null;
    final TextTheme text = Theme.of(context).textTheme;

    Gradient? gradient;
    Color? background;
    Color? border;
    Color foreground;
    Color iconBackground;
    switch (tone) {
      case WideActionTone.primary:
        gradient = enabled ? palette.amberGradient : null;
        background = enabled ? null : palette.lockedSoft;
        foreground = enabled ? palette.onAccent : palette.locked;
        iconBackground = enabled
            ? palette.onAccent.withValues(alpha: 0.18)
            : palette.surface;
      case WideActionTone.secondary:
        background = enabled ? palette.surface : palette.lockedSoft;
        border = enabled ? palette.amber : palette.line;
        foreground = enabled ? palette.ink : palette.locked;
        iconBackground = enabled ? palette.amberSoft : palette.surface;
      case WideActionTone.quiet:
        background = enabled ? palette.surfaceMuted : palette.lockedSoft;
        border = palette.line;
        foreground = enabled ? palette.ink : palette.locked;
        iconBackground = palette.surface;
    }

    final double iconBox = giant ? 58 : 44;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: giant ? 96 : 68),
      child: SmoothSurface(
        gradient: gradient,
        color: background,
        borderColor: border,
        borderWidth: tone == WideActionTone.secondary ? 1.6 : 1,
        radius: giant ? AppShapes.radiusLarge : AppShapes.radiusMedium,
        padding: EdgeInsetsDirectional.fromSTEB(
          giant ? 18 : 14,
          giant ? 16 : 12,
          giant ? 20 : 16,
          giant ? 16 : 12,
        ),
        elevated: enabled && tone == WideActionTone.primary,
        onTap: onPressed,
        semanticLabel: subtitle == null ? label : '$label. $subtitle',
        child: ExcludeSemantics(
          child: Row(
            children: <Widget>[
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: iconBackground,
                  shape: AppShapes.rounded(AppShapes.radiusSmall),
                ),
                child: SizedBox(
                  width: iconBox,
                  height: iconBox,
                  child: Icon(
                    icon,
                    size: giant ? 32 : 24,
                    color: tone == WideActionTone.primary && enabled
                        ? palette.onAccent
                        : (enabled ? palette.amberText : palette.locked),
                  ),
                ),
              ),
              SizedBox(width: giant ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      label,
                      style: (giant ? text.titleLarge : text.titleMedium)
                          ?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: (giant ? text.bodyLarge : text.bodySmall)
                            ?.copyWith(
                          color: foreground.withValues(alpha: 0.82),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                size: giant ? 30 : 22,
                color: foreground.withValues(alpha: 0.9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
