// حفظ إعدادات الوتيرة محلياً. الإعدادات التالفة تعود إلى إعدادات المستخدم
// الجديد دون أن تمس سجل الإتمام.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/key_value_store.dart';
import '../domain/pacing.dart';

/// مخزن إعدادات الوتيرة.
class PacingSettingsStore {
  const PacingSettingsStore(this._store);

  final KeyValueStore _store;

  /// يقرأ الإعدادات.
  PacingSettings read() {
    final String? raw = _store.readString(StorageKeys.pacing);
    if (raw == null || raw.isEmpty) {
      return PacingSettings.initial;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return PacingSettings.fromJson(decoded);
      }
    } on FormatException {
      return PacingSettings.initial;
    }
    return PacingSettings.initial;
  }

  /// يحفظ الإعدادات.
  Future<void> write(PacingSettings settings) {
    return _store.writeString(StorageKeys.pacing, jsonEncode(settings.toJson()));
  }
}

/// المخزن.
final Provider<PacingSettingsStore> pacingSettingsStoreProvider = Provider<PacingSettingsStore>(
  (Ref ref) => PacingSettingsStore(ref.watch(keyValueStoreProvider)),
);
