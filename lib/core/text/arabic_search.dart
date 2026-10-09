// تطبيع النص العربي للبحث: إسقاط التشكيل والتطويل وتوحيد صور الألف والياء
// والهاء، ليجد المستخدم «الاعمال» إذا كُتب في المتن «الْأَعْمَالُ».
//
// يُستعمل للمطابقة فقط؛ لا يُعرض النص المطبَّع ولا يُحفظ، فلا يمس التشكيل
// الأصلي في المتون.

/// أدوات البحث العربي.
abstract final class ArabicSearch {
  static final RegExp _marks = RegExp('[ً-ٰٟۖ-ۭـ]');
  static final RegExp _spaces = RegExp(r'\s+');

  /// يطبّع النص: بلا تشكيل، وألف واحدة، وياء واحدة، وبأرقام لاتينية.
  static String normalize(String input) {
    final StringBuffer out = StringBuffer();
    for (final int rune in input.replaceAll(_marks, '').runes) {
      switch (rune) {
        case 0x0623: // أ
        case 0x0625: // إ
        case 0x0622: // آ
        case 0x0671: // ٱ
          out.write('ا');
        case 0x0649: // ى
        case 0x06CC: // ی
          out.write('ي');
        case 0x0629: // ة
          out.write('ه');
        case >= 0x0660 && <= 0x0669:
          out.write(rune - 0x0660);
        case >= 0x06F0 && <= 0x06F9:
          out.write(rune - 0x06F0);
        default:
          out.writeCharCode(rune);
      }
    }
    return out.toString().replaceAll(_spaces, ' ').trim();
  }

  /// هل يحتوي [haystack] كل كلمات [query] (بلا اعتبار للترتيب)؟
  /// الاستعلام الفارغ يطابق كل شيء.
  static bool matches(String haystack, String query) {
    final String needle = normalize(query);
    if (needle.isEmpty) {
      return true;
    }
    final String hay = normalize(haystack);
    for (final String word in needle.split(' ')) {
      if (!hay.contains(word)) {
        return false;
      }
    }
    return true;
  }
}
