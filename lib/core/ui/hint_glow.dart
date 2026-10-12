// تلميح بصري هادئ: توهج كهرماني ينبض حول عنصر واحد ليدل عليه، دون أن يفعل شيئاً
// عنه ولا يفك قفلاً. لا حمرة ولا اهتزاز؛ وبلا نبض إن طلب النظام تقليل الحركة.

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import 'app_shapes.dart';

/// يلف [child] بتوهج كهرماني نابض متى كان [active].
class HintGlow extends StatefulWidget {
  const HintGlow({
    super.key,
    required this.active,
    required this.child,
    this.radius = AppShapes.radiusMedium,
  });

  /// هل يُعرض التلميح.
  final bool active;

  /// العنصر المدلول عليه.
  final Widget child;

  /// نصف انحناء التوهج؛ يطابق انحناء العنصر.
  final double radius;

  @override
  State<HintGlow> createState() => _HintGlowState();
}

class _HintGlowState extends State<HintGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(HintGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  /// ينبض ما دام التلميح قائماً، ويثبت على أشد لمعانه إن قُلّلت الحركة.
  void _sync() {
    if (!widget.active) {
      _pulse
        ..stop()
        ..value = 0;
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse
        ..stop()
        ..value = 1;
      return;
    }
    if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return widget.child;
    }
    final AppPalette palette = AppPalette.of(context);
    return Stack(
      children: <Widget>[
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (BuildContext context, Widget? _) {
                final double t = Curves.easeInOut.transform(_pulse.value);
                return DecoratedBox(
                  key: const ValueKey<String>('hint-glow'),
                  decoration: ShapeDecoration(
                    color: palette.amber.withValues(alpha: 0.10 + 0.2 * t),
                    shape: AppShapes.rounded(
                      widget.radius,
                      side: BorderSide(color: palette.amber.withValues(alpha: 0.55 + 0.45 * t), width: 2),
                    ),
                    shadows: <BoxShadow>[
                      BoxShadow(
                        color: palette.amber.withValues(alpha: 0.4 * t),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
