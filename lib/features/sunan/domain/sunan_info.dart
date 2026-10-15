// معلومات السنن المهجورة الثابتة: معرّف ملفها ومساره وعنوانها في المركز وتسميات أبوابها في الشريط العلوي.
//
// التسميات واجهة فقط (لا نص نبوي)؛ أما بطاقات السنن وأدلتها فتُقرأ من
// assets/data/sunan/sunan_mahjoorah.json وحده.

import '../data/models/sunan.dart';

/// ثوابت ميزة السنن المهجورة.
abstract final class SunanInfo {
  /// معرّف الملف في البيانات (حقل id في SunanCatalog).
  static const String id = 'sunan_mahjoorah';

  /// مسار الملف في الأصول.
  static const String assetPath = 'assets/data/sunan/sunan_mahjoorah.json';

  /// العنوان على بطاقة المركز وفي رأس الشاشة.
  static const String title = 'السنن النبوية المهجورة';

  /// السطر التعريفي على بطاقة المركز.
  static const String subtitle = 'بطاقات مستقلة بأدلتها المشكولة: ركعتا الوضوء، لعق الأصابع، الابتداء باليمين…';

  /// تسمية خانة «كل الأبواب» في الشريط العلوي.
  static const String allLabel = 'الكل';
}

/// تسمية الباب في شريط التصفية، كما حددها مالك المشروع.
extension SunnahBabLabel on SunnahBab {
  /// التسمية المعروضة.
  String get label => switch (this) {
        SunnahBab.purityPrayer => 'الطهارة والصلاة',
        SunnahBab.foodDrink => 'الطعام والشراب',
        SunnahBab.homeGoingOut => 'المنزل والخروج',
        SunnahBab.sleepClothing => 'النوم واللباس',
        SunnahBab.gatheringsManners => 'المجالس والآداب',
      };
}

/// السنن المرئية تحت الباب المختار؛ null يعني «الكل». الترتيب ترتيب الملف.
List<SunnahItem> filterSunan(List<SunnahItem> items, SunnahBab? bab) {
  if (bab == null) {
    return items;
  }
  return List<SunnahItem>.unmodifiable(items.where((SunnahItem item) => item.bab == bab));
}
