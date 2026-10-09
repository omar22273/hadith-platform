// شاشات تشخيصية مرئية: بدل أن يختفي المحتوى بصمت عند أي خطأ تشغيلي، تُعرض
// رسالة واضحة بسبب التعثر، ومؤشر تحميل مرئي أثناء الانتظار. لا تعتمد هذه
// الشاشات على السمة ولا على أي مزود، فتعمل حتى لو تعطلت التهيئة نفسها.

import 'package:flutter/material.dart';

/// آخر خطأ التقطه التطبيق، يُعرض في شاشات التشخيص.
final ValueNotifier<String?> lastRuntimeError = ValueNotifier<String?>(null);

/// يسجل خطأً التقطه إطار العمل أو المنطقة المحروسة.
void recordRuntimeError(Object error, StackTrace? stack) {
  final String text = '$error';
  lastRuntimeError.value = text.length > 600 ? text.substring(0, 600) : text;
  debugPrint('Runtime error: $error\n${stack ?? ''}');
}

/// يستبدل ودجت الخطأ الافتراضي (الذي يظهر فارغاً في وضع الإصدار) بصندوق
/// مقروء يبين نص الخطأ.
Widget buildVisibleErrorWidget(FlutterErrorDetails details) {
  recordRuntimeError(details.exception, details.stack);
  return Directionality(
    textDirection: TextDirection.rtl,
    child: Container(
      color: const Color(0xFFFFF4E5),
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        child: Text(
          'تعذّر عرض هذا الجزء\n${details.exceptionAsString()}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF7C2D12),
            fontSize: 13,
            height: 1.6,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    ),
  );
}

/// مؤشر تحميل مرئي.
class DiagnosticLoadingView extends StatelessWidget {
  const DiagnosticLoadingView({super.key, this.message = 'جارٍ التحميل…'});

  /// النص المعروض.
  final String message;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ColoredBox(
        color: const Color(0xFFF8F6F0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircularProgressIndicator(color: Color(0xFFB45309)),
              const SizedBox(height: 14),
              Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 14,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// شاشة خطأ كاملة تبين السبب وتتيح إعادة المحاولة.
class DiagnosticErrorView extends StatelessWidget {
  const DiagnosticErrorView({super.key, required this.title, required this.details, this.onRetry});

  /// عنوان قصير.
  final String title;

  /// نص الخطأ.
  final String details;

  /// إعادة المحاولة، إن أمكنت.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ColoredBox(
        color: const Color(0xFFF8F6F0),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Icon(Icons.error_outline_rounded, size: 44, color: Color(0xFFB45309)),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    details,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 12.5,
                      height: 1.5,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  if (onRetry != null) ...<Widget>[
                    const SizedBox(height: 18),
                    Center(
                      child: FilledButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
