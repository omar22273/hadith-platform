// تجزئة ثابتة (FNV-1a بطول ٣٢ بت) لبناء بذور عشوائية متكررة النتيجة.
// لا يُعتمد String.hashCode لأنه غير مضمون الثبات بين الإصدارات.

/// يعيد تجزئة ثابتة للنص.
int stableHash(String value) {
  int hash = 0x811C9DC5;
  for (final int unit in value.codeUnits) {
    hash ^= unit;
    // ضرب في عدد FNV الأولي 0x01000193 = 2^24 + 0x193 دون تجاوز 2^42.
    hash = (((hash & 0xFF) << 24) + hash * 0x193) & 0xFFFFFFFF;
  }
  return hash;
}

/// بذرة من تاريخ اليوم المحلي ونص إضافي.
int daySeed(DateTime day, String salt) {
  final String stamp = '${day.year}-${day.month}-${day.day}';
  return stableHash('$stamp|$salt');
}
