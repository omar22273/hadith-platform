// مصدر الوقت الحالي، قابل للاستبدال في الاختبارات.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// دالة تعيد الوقت المحلي الحالي.
typedef Clock = DateTime Function();

/// الساعة المستعملة في التطبيق.
final Provider<Clock> clockProvider = Provider<Clock>((Ref ref) => DateTime.now);
