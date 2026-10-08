// قارئات JSON آمنة الأنواع تُستعمل في جميع توابع fromJson.
//
// Hadith Platform — data model v1.0.0.

/// خريطة JSON كما يعيدها jsonDecode.
typedef JsonMap = Map<String, dynamic>;

/// خطأ في بنية ملف البيانات، يحدد المفتاح والنوع المتوقع.
class JsonParseException implements Exception {
  const JsonParseException(this.message);

  /// وصف الخطأ.
  final String message;

  @override
  String toString() => 'JsonParseException: $message';
}

Object? _required(JsonMap json, String key) {
  if (!json.containsKey(key)) {
    throw JsonParseException('Missing required key "$key".');
  }
  return json[key];
}

Never _wrongType(String key, String expected, Object? value) {
  throw JsonParseException(
    'Key "$key" must be $expected but was ${value.runtimeType}.',
  );
}

/// يحوّل قيمة إلى [JsonMap] أو يرمي خطأ يحدد موضعها.
JsonMap asJsonMap(Object? value, String context) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return _wrongType(context, 'an object', value);
}

/// نص إلزامي غير فارغ.
String readString(JsonMap json, String key) {
  final Object? value = _required(json, key);
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return _wrongType(key, 'a non-empty string', value);
}

/// نص اختياري؛ الغياب وnull سواء.
String? readStringOrNull(JsonMap json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  return _wrongType(key, 'a string or null', value);
}

/// عدد صحيح إلزامي.
int readInt(JsonMap json, String key) {
  final Object? value = _required(json, key);
  if (value is int) {
    return value;
  }
  return _wrongType(key, 'an integer', value);
}

/// عدد صحيح اختياري.
int? readIntOrNull(JsonMap json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  return _wrongType(key, 'an integer or null', value);
}

/// عدد عشري إلزامي (يقبل الصحيح أيضاً).
double readDouble(JsonMap json, String key) {
  final Object? value = _required(json, key);
  if (value is num) {
    return value.toDouble();
  }
  return _wrongType(key, 'a number', value);
}

/// عدد عشري اختياري.
double? readDoubleOrNull(JsonMap json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  return _wrongType(key, 'a number or null', value);
}

/// قيمة منطقية إلزامية.
bool readBool(JsonMap json, String key) {
  final Object? value = _required(json, key);
  if (value is bool) {
    return value;
  }
  return _wrongType(key, 'a boolean', value);
}

/// عنصر تعداد إلزامي من قيمته النصية.
T readEnum<T>(JsonMap json, String key, T Function(String wire) fromWire) {
  return fromWire(readString(json, key));
}

/// عنصر تعداد اختياري.
T? readEnumOrNull<T>(
  JsonMap json,
  String key,
  T Function(String wire) fromWire,
) {
  final String? wire = readStringOrNull(json, key);
  if (wire == null) {
    return null;
  }
  return fromWire(wire);
}

/// كائن متداخل إلزامي.
T readModel<T>(JsonMap json, String key, T Function(JsonMap json) parse) {
  return parse(asJsonMap(_required(json, key), key));
}

/// كائن متداخل اختياري.
T? readModelOrNull<T>(
  JsonMap json,
  String key,
  T Function(JsonMap json) parse,
) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  return parse(asJsonMap(value, key));
}

/// قائمة كائنات إلزامية (قد تكون فارغة)، تُعاد غير قابلة للتعديل.
List<T> readModelList<T>(
  JsonMap json,
  String key,
  T Function(JsonMap json) parse,
) {
  final Object? value = _required(json, key);
  if (value is! List) {
    return _wrongType(key, 'an array', value);
  }
  final List<T> result = <T>[];
  for (int index = 0; index < value.length; index++) {
    result.add(parse(asJsonMap(value[index], '$key[$index]')));
  }
  return List<T>.unmodifiable(result);
}

/// قائمة نصوص إلزامية (قد تكون فارغة)، تُعاد غير قابلة للتعديل.
List<String> readStringList(JsonMap json, String key) {
  final Object? value = _required(json, key);
  if (value is! List) {
    return _wrongType(key, 'an array', value);
  }
  final List<String> result = <String>[];
  for (int index = 0; index < value.length; index++) {
    final Object? item = value[index];
    if (item is! String || item.isEmpty) {
      return _wrongType('$key[$index]', 'a non-empty string', item);
    }
    result.add(item);
  }
  return List<String>.unmodifiable(result);
}
