// حفظ التقدم محلياً. إن تعذرت قراءة سجل محفوظ لا يُحذف: يُنقل إلى مفتاح
// احتياطي كما هو، حتى لا يضيع تقدم المستخدم بصمت.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/json/json_reader.dart';
import '../../../core/storage/key_value_store.dart';
import '../domain/journey_progress.dart';

/// مخزن التقدم.
class JourneyProgressStore {
  const JourneyProgressStore(this._store);

  final KeyValueStore _store;

  /// يقرأ التقدم المحفوظ.
  Future<JourneyProgress> read() async {
    final String? raw = _store.readString(StorageKeys.journeyProgress);
    if (raw == null || raw.isEmpty) {
      return JourneyProgress.empty;
    }
    try {
      return JourneyProgress.fromJson(asJsonMap(jsonDecode(raw), 'journeyProgress'));
    } on FormatException {
      await _preserveUnreadable(raw);
    } on JsonParseException {
      await _preserveUnreadable(raw);
    }
    return JourneyProgress.empty;
  }

  /// يحفظ التقدم.
  Future<void> write(JourneyProgress progress) {
    return _store.writeString(StorageKeys.journeyProgress, jsonEncode(progress.toJson()));
  }

  Future<void> _preserveUnreadable(String raw) async {
    if (_store.readString(StorageKeys.journeyProgressUnreadable) == null) {
      await _store.writeString(StorageKeys.journeyProgressUnreadable, raw);
    }
  }
}

/// المخزن المستعمل.
final Provider<JourneyProgressStore> journeyProgressStoreProvider =
    Provider<JourneyProgressStore>(
  (Ref ref) => JourneyProgressStore(ref.watch(keyValueStoreProvider)),
);
