// تخزين محلي بسيط للتقدم والتفضيلات (Offline-First).
//
// الواجهة مجردة لتسهيل الاختبار، والتنفيذ الإنتاجي فوق SharedPreferencesWithCache.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// مفاتيح التخزين المسموح بها.
abstract final class StorageKeys {
  /// تقدم المستخدم في مسار القوافل.
  static const String journeyProgress = 'journey.progress.v1';

  /// نسخة احتياطية من تقدم تعذرت قراءته، لا تُحذف تلقائياً.
  static const String journeyProgressUnreadable = 'journey.progress.unreadable.v1';

  /// طريقة التلقي المفضلة: القراءة واللمس أو السماع.
  static const String receptionMode = 'settings.reception_mode.v1';

  /// سرعة السرد في وضع السماع.
  static const String oralPace = 'settings.oral_pace.v1';

  /// ملح عشوائي ثابت للجهاز، تُبنى منه بعثرة الترصيع الخاصة بكل مستخدم.
  static const String installSalt = 'device.install_salt.v1';

  /// نمط السمة: تلقائي، أو النهاري التراثي، أو الداكن.
  static const String themeMode = 'settings.theme_mode.v1';

  /// إعدادات الخطوط والحجم.
  static const String readingPreferences = 'settings.reading.v1';

  /// إعدادات وتيرة الأوراد: الحصة المختارة، وتخطي القفل للتجربة، وأفضل استمرارية مسجلة.
  static const String pacing = 'pacing.settings.v1';

  /// محطات رحلة السيرة التي فتحها المستخدم.
  static const String seerahVisited = 'seerah.visited.v1';

  /// إعدادات تذكير الورد اليومي: التفعيل والوقت.
  static const String reminder = 'settings.reminder.v1';

  /// كل المفاتيح.
  static const Set<String> all = <String>{
    journeyProgress,
    journeyProgressUnreadable,
    receptionMode,
    oralPace,
    installSalt,
    themeMode,
    readingPreferences,
    pacing,
    seerahVisited,
    reminder,
  };
}

/// مخزن نصي بمفاتيح.
abstract interface class KeyValueStore {
  /// يقرأ القيمة، أو null إن لم توجد.
  String? readString(String key);

  /// يكتب القيمة.
  Future<void> writeString(String key, String value);

  /// يحذف القيمة.
  Future<void> remove(String key);
}

/// التنفيذ الإنتاجي.
class SharedPreferencesStore implements KeyValueStore {
  SharedPreferencesStore(this._preferences);

  final SharedPreferencesWithCache _preferences;

  /// يفتح المخزن ويحمّل ذاكرته المؤقتة.
  static Future<SharedPreferencesStore> open() async {
    final SharedPreferencesWithCache preferences =
        await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: StorageKeys.all,
      ),
    );
    return SharedPreferencesStore(preferences);
  }

  @override
  String? readString(String key) => _preferences.getString(key);

  @override
  Future<void> writeString(String key, String value) {
    return _preferences.setString(key, value);
  }

  @override
  Future<void> remove(String key) => _preferences.remove(key);
}

/// مخزن في الذاكرة للاختبارات والمعاينة.
class InMemoryKeyValueStore implements KeyValueStore {
  InMemoryKeyValueStore([Map<String, String>? initial])
      : _values = <String, String>{...?initial};

  final Map<String, String> _values;

  @override
  String? readString(String key) => _values[key];

  @override
  Future<void> writeString(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}

/// المخزن المستعمل في التطبيق؛ يُستبدل في main بالمخزن الإنتاجي.
final Provider<KeyValueStore> keyValueStoreProvider = Provider<KeyValueStore>(
  (Ref ref) => InMemoryKeyValueStore(),
);
