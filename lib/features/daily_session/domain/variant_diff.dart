// مقارنة الروايات: تمييز ألفاظ الرواية التي لا تقابلها ألفاظ المتن المعروض.
// المقارنة على الرسم (بلا حركات) حتى لا يُعد اختلاف الضبط فرقاً في اللفظ.

import 'package:flutter/foundation.dart';

import '../../hadith/data/models/models.dart';

/// كلمة من الرواية مع وسم المشاركة.
@immutable
class DiffWord {
  const DiffWord({required this.text, required this.shared});

  /// الكلمة كما في الرواية.
  final String text;

  /// هل لها مقابل في المتن المعروض.
  final bool shared;
}

/// رسم الكلمة دون حركات ولا تطويل، مع توحيد صور الألف المهموزة.
String rasm(String word) {
  final StringBuffer buffer = StringBuffer();
  for (final int rune in word.runes) {
    final bool mark = (rune >= 0x064B && rune <= 0x065F) || rune == 0x0670 || rune == 0x0640;
    if (mark) {
      continue;
    }
    switch (rune) {
      case 0x0622:
      case 0x0623:
      case 0x0625:
      case 0x0671:
        buffer.writeCharCode(0x0627);
      default:
        buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// يقارن نص الرواية بالمتن، ويعيد كلمات الرواية موسومة.
List<DiffWord> diffVariant({required String variantText, required String baseText}) {
  final List<MatnToken> variant = MatnTokenizer.tokenize(variantText);
  final List<String> a = variant.map((MatnToken t) => rasm(t.core)).toList();
  final List<String> b = MatnTokenizer.tokenize(baseText).map((MatnToken t) => rasm(t.core)).toList();
  final int n = a.length;
  final int m = b.length;
  final List<List<int>> table = List<List<int>>.generate(n + 1, (int _) => List<int>.filled(m + 1, 0));
  for (int i = n - 1; i >= 0; i--) {
    for (int j = m - 1; j >= 0; j--) {
      table[i][j] = a[i] == b[j]
          ? table[i + 1][j + 1] + 1
          : (table[i + 1][j] >= table[i][j + 1] ? table[i + 1][j] : table[i][j + 1]);
    }
  }
  final List<bool> shared = List<bool>.filled(n, false);
  int i = 0;
  int j = 0;
  while (i < n && j < m) {
    if (a[i] == b[j]) {
      shared[i] = true;
      i++;
      j++;
    } else if (table[i + 1][j] >= table[i][j + 1]) {
      i++;
    } else {
      j++;
    }
  }
  return List<DiffWord>.unmodifiable(<DiffWord>[
    for (int k = 0; k < n; k++) DiffWord(text: variant[k].raw, shared: shared[k]),
  ]);
}
