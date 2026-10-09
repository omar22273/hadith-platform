// سجل الإتمام: المصدر الوحيد للأوراد المكتملة وأوقاتها، يقرؤه المسار
// ومحرك الوتيرة وميدان المراجعة. لا يُصفَّر ولا يُنقص.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../data/journey_progress_store.dart';
import '../domain/journey_progress.dart';

/// متحكم سجل الإتمام.
class JourneyProgressController extends AsyncNotifier<JourneyProgress> {
  @override
  Future<JourneyProgress> build() {
    return ref.watch(journeyProgressStoreProvider).read();
  }

  /// يسجل إتمام وِرد ويحفظه. التسجيل المكرر للحديث نفسه لا يغير شيئاً.
  Future<JourneyProgress> complete(String hadithId) async {
    final JourneyProgress current = await future;
    final JourneyProgress updated = current.withCompletion(
      hadithId,
      ref.read(clockProvider)(),
    );
    if (identical(updated, current)) {
      return current;
    }
    await ref.read(journeyProgressStoreProvider).write(updated);
    if (ref.mounted) {
      state = AsyncData<JourneyProgress>(updated);
    }
    return updated;
  }
}

/// سجل الإتمام.
final AsyncNotifierProvider<JourneyProgressController, JourneyProgress> journeyProgressProvider =
    AsyncNotifierProvider<JourneyProgressController, JourneyProgress>(
  JourneyProgressController.new,
);
