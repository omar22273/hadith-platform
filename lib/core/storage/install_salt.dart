// ملح عشوائي ثابت لكل تثبيت، تُبنى منه بعثرة الترصيع «لكل مستخدم في كل يوم».

import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'key_value_store.dart';

/// الملح المحفوظ، ويُولَّد مرة واحدة عند أول طلب.
final Provider<String> installSaltProvider = Provider<String>((Ref ref) {
  final KeyValueStore store = ref.watch(keyValueStoreProvider);
  final String? existing = store.readString(StorageKeys.installSalt);
  if (existing != null && existing.isNotEmpty) {
    return existing;
  }
  final Random random = Random.secure();
  final String salt = List<String>.generate(
    16,
    (int _) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  unawaited(store.writeString(StorageKeys.installSalt, salt));
  return salt;
});
