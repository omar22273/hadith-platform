// طريقة التلقي المفضلة: القراءة واللمس أو السماع والمشافهة.
//
// لا تحجب الطريقتان شيئاً: كلتاهما متاحة دائماً من بطاقة المحطة، والتفضيل
// يحدد الزر المقدَّم ويكبّر المساحات في وضع السماع.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/key_value_store.dart';

/// طريقة التلقي.
enum ReceptionMode {
  /// القراءة واللمس.
  touch('touch'),

  /// السماع والمشافهة لكبار السن ومن يفضل التلقي الشفاهي.
  oral('oral');

  const ReceptionMode(this.wire);

  /// القيمة المخزنة.
  final String wire;

  /// يحوّل القيمة المخزنة، ويعيد القراءة واللمس عند غيابها.
  static ReceptionMode fromWire(String? value) {
    for (final ReceptionMode mode in ReceptionMode.values) {
      if (mode.wire == value) {
        return mode;
      }
    }
    return ReceptionMode.touch;
  }
}

/// متحكم التفضيل.
class ReceptionModeController extends Notifier<ReceptionMode> {
  @override
  ReceptionMode build() {
    final KeyValueStore store = ref.watch(keyValueStoreProvider);
    return ReceptionMode.fromWire(store.readString(StorageKeys.receptionMode));
  }

  /// يغيّر التفضيل ويحفظه.
  void select(ReceptionMode mode) {
    if (state == mode) {
      return;
    }
    state = mode;
    unawaited(
      ref
          .read(keyValueStoreProvider)
          .writeString(StorageKeys.receptionMode, mode.wire),
    );
  }
}

/// التفضيل الحالي.
final NotifierProvider<ReceptionModeController, ReceptionMode>
    receptionModeProvider =
    NotifierProvider<ReceptionModeController, ReceptionMode>(
  ReceptionModeController.new,
);
