// تحويل الأرقام إلى الأرقام العربية المشرقية للعرض في الواجهة.
//
// النصوص المنقولة من المصادر لا تمر بهذه الدالة، فتبقى أرقامها كما وردت.

const String _easternDigits = '٠١٢٣٤٥٦٧٨٩';

/// يعيد النص نفسه بعد استبدال كل رقم غربي بنظيره المشرقي.
String arabicDigits(Object value) {
  final StringBuffer buffer = StringBuffer();
  for (final int rune in value.toString().runes) {
    if (rune >= 0x30 && rune <= 0x39) {
      buffer.write(_easternDigits[rune - 0x30]);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// نسبة مئوية مقربة للعرض، مثل «٤٪».
String arabicPercent(double fraction) {
  final int value = (fraction.clamp(0.0, 1.0) * 100).round();
  return '${arabicDigits(value)}٪';
}

/// مدة متبقية بصيغة قصيرة، مثل «٧ س ١٢ د» أو «٤٥ د».
String arabicCountdown(Duration remaining) {
  if (remaining.isNegative || remaining == Duration.zero) {
    return 'لحظات';
  }
  final int totalMinutes = (remaining.inSeconds + 59) ~/ 60;
  final int hours = totalMinutes ~/ 60;
  final int minutes = totalMinutes % 60;
  if (hours == 0) {
    return '${arabicDigits(minutes)} د';
  }
  return '${arabicDigits(hours)} س ${arabicDigits(minutes)} د';
}
