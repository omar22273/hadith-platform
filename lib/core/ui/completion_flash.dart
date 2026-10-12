// وميض النجاح الهادئ: سطح يلتف حول محتوى تمرين، فإذا اكتمل التمرين ارتفع فيه
// لون أخضر هادئ ثم استقر على أخضر فاتح بحد أخضر. لا حمرة ولا توبيخ في الحالة
// المقابلة، وبلا حركة إن طلب النظام تقليلها.

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/feedback_colors.dart';
import 'smooth_surface.dart';

/// سطح يومض بالأخضر الهادئ عند اكتمال محتواه.
class CompletionFlash extends StatefulWidget {
  const CompletionFlash({
    super.key,
    required this.completed,
    required this.child,
    this.minHeight = 0,
    this.padding = const EdgeInsets.all(14),
    this.idleColor,
    this.idleBorderColor,
    this.idleBorderWidth = 1,
  });

  /// هل اكتمل التمرين.
  final bool completed;

  /// المحتوى.
  final Widget child;

  /// أدنى ارتفاع للسطح.
  final double minHeight;

  /// الحشوة الداخلية.
  final EdgeInsetsGeometry padding;

  /// لون السطح قبل الاكتمال؛ الافتراضي لون البطاقات.
  final Color? idleColor;

  /// لون الحد قبل الاكتمال؛ الافتراضي لون الخطوط.
  final Color? idleBorderColor;

  /// سماكة الحد قبل الاكتمال.
  final double idleBorderWidth;

  @override
  State<CompletionFlash> createState() => _CompletionFlashState();
}

class _CompletionFlashState extends State<CompletionFlash> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: widget.completed ? 1 : 0,
  );

  @override
  void didUpdateWidget(CompletionFlash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.completed && !oldWidget.completed) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    } else if (!widget.completed) {
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final FeedbackColors feedback = FeedbackColors.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        // وميض: يرتفع اللون الأخضر سريعاً ثم يهدأ إلى الأخضر الفاتح.
        final double pulse = widget.completed ? (1 - Curves.easeOut.transform(_controller.value)) : 0;
        final Color fill = widget.completed
            ? Color.lerp(palette.emeraldSoft, feedback.rightBorder.withValues(alpha: 0.55), pulse)!
            : (widget.idleColor ?? palette.surface);
        return SmoothSurface(
          color: fill,
          borderColor: widget.completed ? feedback.rightBorder : (widget.idleBorderColor ?? palette.line),
          borderWidth: widget.completed ? 2 : widget.idleBorderWidth,
          padding: widget.padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: widget.minHeight),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
