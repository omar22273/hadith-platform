// اختبارات تطبيع البحث العربي: التشكيل والألف والياء والتاء المربوطة والأرقام.

import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/core/text/arabic_search.dart';

void main() {
  test('normalize drops tashkeel and unifies letter variants', () {
    expect(ArabicSearch.normalize('إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ'), 'انما الاعمال بالنيات');
    expect(ArabicSearch.normalize('مَدِينَة'), 'مدينه');
    expect(ArabicSearch.normalize('موسى'), 'موسي');
    expect(ArabicSearch.normalize('الحديث ٣'), 'الحديث 3');
  });

  test('matches requires every query word, in any order', () {
    const String text = 'إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ وَإِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى';
    expect(ArabicSearch.matches(text, 'الاعمال'), isTrue);
    expect(ArabicSearch.matches(text, 'نوى الاعمال'), isTrue);
    expect(ArabicSearch.matches(text, 'الأَعمَال بالنيات'), isTrue);
    expect(ArabicSearch.matches(text, 'الصلاة'), isFalse);
  });

  test('an empty query matches everything', () {
    expect(ArabicSearch.matches('أي نص', ''), isTrue);
    expect(ArabicSearch.matches('أي نص', '   '), isTrue);
  });
}
