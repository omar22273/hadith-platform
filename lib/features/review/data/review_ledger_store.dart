// حفظ سجل المراجعة محلياً. السجل جدولة هادئة لا تقدّماً: إن تعذرت قراءته
// بدأ سجل جديد بلا إنذار، ولا يُنسخ احتياطياً مع تقدم المستخدم.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/json/json_reader.dart';
import '../../../core/storage/key_value_store.dart';
import '../domain/daily_review.dart';

/// مخزن سجل المراجعة.
class ReviewLedgerStore {
  const ReviewLedgerStore(this._store);

  final KeyValueStore _store;

  /// يقرأ السجل المحفوظ، أو الفارغ إن لم يوجد أو تعذرت قراءته.
  ReviewLedger read() {
    final String? raw = _store.readString(StorageKeys.reviewLedger);
    if (raw == null || raw.isEmpty) {
      return ReviewLedger.empty;
    }
    try {
      return ReviewLedger.fromJson(asJsonMap(jsonDecode(raw), 'reviewLedger'));
    } on FormatException {
      return ReviewLedger.empty;
    } on JsonParseException {
      return ReviewLedger.empty;
    }
  }

  /// يحفظ السجل.
  Future<void> write(ReviewLedger ledger) {
    return _store.writeString(StorageKeys.reviewLedger, jsonEncode(ledger.toJson()));
  }
}

/// المخزن المستعمل.
final Provider<ReviewLedgerStore> reviewLedgerStoreProvider = Provider<ReviewLedgerStore>(
  (Ref ref) => ReviewLedgerStore(ref.watch(keyValueStoreProvider)),
);
