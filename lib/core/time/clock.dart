// مصدر الوقت الحالي، قابل للاستبدال في الاختبارات.
//
// nowProvider لحظة «مجمّدة» تعيد المزودات المعتمدة عليها حسابها كلما تقدمت:
// عند عودة التطبيق من الخلفية، وعند حلول وقت فتح الوِرد التالي.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// دالة تعيد الوقت المحلي الحالي.
typedef Clock = DateTime Function();

/// الساعة المستعملة في التطبيق.
final Provider<Clock> clockProvider = Provider<Clock>((Ref ref) => DateTime.now);

/// متحكم اللحظة المرجعية لحسابات القفل والاستمرارية.
class NowController extends Notifier<DateTime> {
  @override
  DateTime build() => ref.watch(clockProvider)();

  /// يقدّم اللحظة إلى الوقت الحالي، فتُعاد الحسابات المعتمدة عليها.
  void tick() {
    state = ref.read(clockProvider)();
  }
}

/// اللحظة المرجعية.
final NotifierProvider<NowController, DateTime> nowProvider =
    NotifierProvider<NowController, DateTime>(NowController.new);
