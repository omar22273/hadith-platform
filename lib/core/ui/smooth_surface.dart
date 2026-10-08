// سطح ناعم الحواف: البطاقة الأساسية في المنصة، تقبل لوناً أو تدرجاً وحداً ولمسة.

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import 'app_shapes.dart';

/// بطاقة بحواف Squircle، مع تفاعل لمسي اختياري.
class SmoothSurface extends StatelessWidget {
  const SmoothSurface({
    super.key,
    required this.child,
    this.color,
    this.gradient,
    this.borderColor,
    this.borderWidth = 1,
    this.radius = AppShapes.radiusLarge,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.elevated = false,
    this.semanticLabel,
  });

  /// المحتوى.
  final Widget child;

  /// لون السطح؛ الافتراضي لون البطاقات.
  final Color? color;

  /// تدرج بدل اللون.
  final Gradient? gradient;

  /// لون الحد؛ بلا حد إن كان null.
  final Color? borderColor;

  /// سماكة الحد.
  final double borderWidth;

  /// نصف قطر الانحناء.
  final double radius;

  /// الحشوة الداخلية.
  final EdgeInsetsGeometry padding;

  /// اللمس.
  final VoidCallback? onTap;

  /// ظل ناعم تحت السطح.
  final bool elevated;

  /// وصف لقارئ الشاشة عند كون السطح زراً.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final BorderSide side = borderColor == null
        ? BorderSide.none
        : BorderSide(color: borderColor!, width: borderWidth);
    final ShapeBorder shape = AppShapes.rounded(radius, side: side);
    Widget content = Padding(
      padding: padding,
      child: semanticLabel == null ? child : ExcludeSemantics(child: child),
    );
    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        customBorder: shape,
        child: content,
      );
    }
    Widget surface = DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        color: gradient == null ? (color ?? palette.surface) : null,
        gradient: gradient,
        shadows: elevated
            ? <BoxShadow>[
                BoxShadow(
                  color: palette.shadow,
                  blurRadius: 28,
                  spreadRadius: -16,
                  offset: const Offset(0, 14),
                ),
              ]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );
    if (onTap != null || semanticLabel != null) {
      surface = Semantics(
        button: onTap != null,
        label: semanticLabel,
        child: surface,
      );
    }
    return surface;
  }
}

/// رقاقة صغيرة للحالات والتصنيفات.
class SoftChip extends StatelessWidget {
  const SoftChip({
    super.key,
    required this.label,
    this.icon,
    this.background,
    this.foreground,
    this.borderColor,
  });

  /// النص.
  final String label;

  /// أيقونة اختيارية قبل النص.
  final IconData? icon;

  /// الخلفية.
  final Color? background;

  /// لون النص والأيقونة.
  final Color? foreground;

  /// لون الحد.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Color fg = foreground ?? palette.inkSoft;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: background ?? palette.surfaceMuted,
        shape: AppShapes.rounded(
          AppShapes.radiusSmall,
          side: BorderSide(color: borderColor ?? palette.line),
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 12, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// عنوان قسم صغير بلون كهرماني.
class SectionEyebrow extends StatelessWidget {
  const SectionEyebrow(this.text, {super.key, this.icon});

  /// النص.
  final String text;

  /// أيقونة اختيارية.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Row(
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 17, color: palette.amberText),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: palette.amberText,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
          ),
        ),
      ],
    );
  }
}
