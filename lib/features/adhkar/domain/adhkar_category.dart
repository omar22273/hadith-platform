// فئات مركز الأذكار: كل بطاقة في المركز تقابل ملف بيانات واحداً في assets/data/adhkar/.
//
// الفئات الست ملفات بيانات مشكولة مقتطعة حرفياً من المصادر المعتمدة (انظر
// tools/content/build_adhkar_matrix.py)؛ والسبحة الذكية السابعة شاشة عدّ حر لا ملف لها.

import 'package:flutter/material.dart';

/// فئة من الأذكار أو السنن: عنوانها في المركز وملف بياناتها.
@immutable
class AdhkarCategory {
  const AdhkarCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.assetPath,
  });

  /// المعرّف، وهو معرّف الملف داخل البيانات (حقل id في AdhkarCatalog).
  final String id;

  /// العنوان على البطاقة وفي رأس المشغّل.
  final String title;

  /// سطر يوضح ما تحويه البطاقة.
  final String subtitle;

  /// الأيقونة.
  final IconData icon;

  /// مسار ملف البيانات في الأصول.
  final String assetPath;

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is AdhkarCategory && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// فئات المركز بترتيب عرضها.
abstract final class AdhkarCategories {
  static const String _folder = 'assets/data/adhkar';

  /// أذكار الصباح والمساء.
  static const AdhkarCategory morningEvening = AdhkarCategory(
    id: 'adhkar_morning_evening',
    title: 'أذكار الصباح والمساء',
    subtitle: 'أوراد تفتتح بها يومك وتختمه',
    icon: Icons.wb_twilight_rounded,
    assetPath: '$_folder/adhkar_morning_evening.json',
  );

  /// أذكار النوم والاستيقاظ.
  static const AdhkarCategory sleep = AdhkarCategory(
    id: 'adhkar_sleep',
    title: 'أذكار النوم والاستيقاظ',
    subtitle: 'عند الاضطجاع وعند الانتباه من النوم',
    icon: Icons.bedtime_outlined,
    assetPath: '$_folder/adhkar_sleep.json',
  );

  /// أذكار أدبار الصلوات المكتوبة.
  static const AdhkarCategory afterPrayer = AdhkarCategory(
    id: 'adhkar_after_prayer',
    title: 'أذكار أدبار الصلوات المكتوبة',
    subtitle: 'بعد السلام من كل فريضة',
    icon: Icons.mosque_outlined,
    assetPath: '$_folder/adhkar_after_prayer.json',
  );

  /// أذكار دخول وخروج المنزل والمسجد.
  static const AdhkarCategory homeMasjid = AdhkarCategory(
    id: 'adhkar_home_masjid',
    title: 'أذكار دخول وخروج المنزل والمسجد',
    subtitle: 'عند الدخول وعند الخروج',
    icon: Icons.home_outlined,
    assetPath: '$_folder/adhkar_home_masjid.json',
  );

  /// السنن النبوية المهجورة.
  static const AdhkarCategory sunan = AdhkarCategory(
    id: 'sunan_mahjoorah',
    title: 'السنن النبوية المهجورة',
    subtitle: 'ركعتا الوضوء، لعق الأصابع، الابتداء باليمين…',
    icon: Icons.history_edu_outlined,
    assetPath: '$_folder/sunan_mahjoorah.json',
  );

  /// جامع الأدعية المأثورة.
  static const AdhkarCategory duas = AdhkarCategory(
    id: 'adhkar_daily_life',
    title: 'جامع الأدعية المأثورة',
    subtitle: 'الركوب، السفر، الكرب، نزول الغيث…',
    icon: Icons.front_hand_outlined,
    assetPath: '$_folder/adhkar_daily_life.json',
  );

  /// الفئات الست التي لها ملفات بيانات.
  static const List<AdhkarCategory> all = <AdhkarCategory>[
    morningEvening,
    sleep,
    afterPrayer,
    homeMasjid,
    sunan,
    duas,
  ];

  /// الفئة بمعرّفها، أو null إن لم توجد.
  static AdhkarCategory? byId(String id) {
    for (final AdhkarCategory category in all) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }
}
