// نمط السمة المحفوظ: تلقائي يتبع النظام، أو النهاري التراثي، أو الداكن.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/key_value_store.dart';

/// اختيار المستخدم للسمة.
enum ThemePreference {
  /// يتبع إعداد النظام.
  system('system', 'تلقائي', ThemeMode.system),

  /// الوضع النهاري التراثي (Warm Parchment).
  parchment('parchment', 'النهاري التراثي', ThemeMode.light),

  /// الوضع الداكن.
  dark('dark', 'الداكن', ThemeMode.dark);

  const ThemePreference(this.wire, this.label, this.themeMode);

  /// القيمة المخزنة.
  final String wire;

  /// الاسم المعروض.
  final String label;

  /// نمط Flutter المقابل.
  final ThemeMode themeMode;

  /// يحوّل القيمة المخزنة، والقيمة المجهولة تعني التلقائي.
  static ThemePreference fromWire(String? value) {
    for (final ThemePreference preference in ThemePreference.values) {
      if (preference.wire == value) {
        return preference;
      }
    }
    return ThemePreference.system;
  }
}

/// متحكم السمة: يقرأ الاختيار من المخزن ويحفظه عند التغيير.
class ThemePreferenceController extends Notifier<ThemePreference> {
  @override
  ThemePreference build() {
    final KeyValueStore store = ref.watch(keyValueStoreProvider);
    return ThemePreference.fromWire(store.readString(StorageKeys.themeMode));
  }

  /// يختار السمة ويحفظها.
  void select(ThemePreference preference) {
    if (state == preference) {
      return;
    }
    state = preference;
    unawaited(
      ref.read(keyValueStoreProvider).writeString(StorageKeys.themeMode, preference.wire),
    );
  }
}

/// السمة المختارة.
final NotifierProvider<ThemePreferenceController, ThemePreference> themePreferenceProvider =
    NotifierProvider<ThemePreferenceController, ThemePreference>(
  ThemePreferenceController.new,
);
