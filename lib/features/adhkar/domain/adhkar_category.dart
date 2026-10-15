// فئات مركز الأذكار: كل بطاقة في المركز تقابل ملف بيانات واحداً في assets/data/adhkar/.
//
// الفئات الست ملفات بيانات مشكولة مقتطعة حرفياً من المصادر المعتمدة (انظر
// tools/content/build_adhkar_matrix.py)؛ والسبحة الذكية السابعة شاشة عدّ حر لا ملف لها.

import 'package:flutter/material.dart';

/// مسار من مسارات الفئة ذات التبديل: معرّفه في حقل tracks من البيانات، وتسميته على زر التبديل.
@immutable
class AdhkarTrack {
  const AdhkarTrack({required this.id, required this.label});

  /// المعرّف، وهو القيمة الواردة في حقل tracks من بيانات الأذكار.
  final String id;

  /// التسمية على زر التبديل بالرمز التعبيري كما حددها مالك المشروع.
  final String label;

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is AdhkarTrack && other.id == id && other.label == label;
  }

  @override
  int get hashCode => Object.hash(id, label);
}

/// نطاق وِرد: فئة بكاملها، أو مسار واحد من فئة ذات تبديل («الفئة#المسار»).
/// هو مفتاح مزودات الأذكار والوِرد، فلكل مسار وِرده وعدّاده المستقلان.
@immutable
class AdhkarScope {
  const AdhkarScope._(this.categoryId, this.trackId);

  /// نطاق فئة بكاملها.
  const AdhkarScope.category(String categoryId) : this._(categoryId, null);

  /// نطاق مسار من فئة.
  const AdhkarScope.track(String categoryId, String trackId) : this._(categoryId, trackId);

  /// يقرأ المفتاح النصي.
  factory AdhkarScope.parse(String key) {
    final int cut = key.indexOf('#');
    if (cut < 0) {
      return AdhkarScope._(key, null);
    }
    return AdhkarScope._(key.substring(0, cut), key.substring(cut + 1));
  }

  /// معرّف الفئة.
  final String categoryId;

  /// معرّف المسار، أو null لنطاق الفئة بكاملها.
  final String? trackId;

  /// المفتاح النصي.
  String get key => trackId == null ? categoryId : '$categoryId#$trackId';

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is AdhkarScope && other.key == key;
  }

  @override
  int get hashCode => key.hashCode;
}

/// فئة من الأذكار أو السنن: عنوانها في المركز وملف بياناتها.
@immutable
class AdhkarCategory {
  const AdhkarCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.assetPath,
    this.tracks = const <AdhkarTrack>[],
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

  /// مسارات التبديل إن كانت للفئة (زرّان بتسميتَي المالك)؛ فارغة للفئة بلا تبديل.
  final List<AdhkarTrack> tracks;

  /// هل للفئة تبديل بين مسارين.
  bool get hasTracks => tracks.isNotEmpty;

  /// نطاق الوِرد للمسار [trackId]، أو للفئة كلها إن لم تكن ذات مسارات.
  AdhkarScope scopeFor(String? trackId) {
    if (!hasTracks || trackId == null) {
      return AdhkarScope.category(id);
    }
    return AdhkarScope.track(id, trackId);
  }

  /// المسار الذي يُفتح عليه المشغّل أول مرة.
  AdhkarTrack? get firstTrack => hasTracks ? tracks.first : null;

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
    tracks: <AdhkarTrack>[
      AdhkarTrack(id: 'morning', label: '☀️ أذكار الصباح'),
      AdhkarTrack(id: 'evening', label: '🌙 أذكار المساء'),
    ],
  );

  /// أذكار النوم والاستيقاظ.
  static const AdhkarCategory sleep = AdhkarCategory(
    id: 'adhkar_sleep',
    title: 'أذكار النوم والاستيقاظ',
    subtitle: 'عند الاضطجاع وعند الانتباه من النوم',
    icon: Icons.bedtime_outlined,
    assetPath: '$_folder/adhkar_sleep.json',
    tracks: <AdhkarTrack>[
      AdhkarTrack(id: 'sleep', label: '🛌 أذكار النوم'),
      AdhkarTrack(id: 'wake', label: '🌅 أذكار الاستيقاظ'),
    ],
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
    tracks: <AdhkarTrack>[
      AdhkarTrack(id: 'home', label: '🏠 أذكار المنزل (دخول وخروج)'),
      AdhkarTrack(id: 'masjid', label: '🕌 أذكار المسجد (ذهاب ودخول وخروج)'),
    ],
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
