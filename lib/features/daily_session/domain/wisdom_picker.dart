// اختيار عبارة عشوائية من بنك العبارات التراثية الموثقة.
// العشوائية مبذورة بتاريخ اليوم والحديث والجهاز، فتثبت العبارة إن أُعيد فتح
// شاشة الختام في اليوم نفسه، وتتغير في الأيام التالية.

import 'dart:math';

import '../../../core/text/stable_hash.dart';
import '../../hadith/data/models/models.dart';

/// يختار عبارة اليوم.
WisdomEntry pickWisdom(
  WisdomCatalog catalog, {
  required DateTime day,
  required String hadithId,
  required String installSalt,
}) {
  final Random random = Random(daySeed(day, '$hadithId|$installSalt'));
  return catalog.entries[random.nextInt(catalog.entries.length)];
}
