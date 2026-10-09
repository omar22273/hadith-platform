// قارئ ملفات JSON من حزمة الأصول، مشترك بين مستودعي الحديث والسيرة.
//
// تُعطّل إعادة المحاولة التلقائية في مزودات المحتوى: خطأ في ملف أصول لن
// يُصلحه التكرار، والأولى إظهاره فوراً.

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../json/json_reader.dart';

/// قارئ JSON من حزمة الأصول.
class AssetJsonSource {
  const AssetJsonSource(this._bundle);

  final AssetBundle _bundle;

  /// يقرأ الملف ويحوّله إلى خريطة، ويرمي [JsonParseException] إن لم يكن كائناً.
  Future<JsonMap> load(String path) async {
    final String text = await _bundle.loadString(path);
    return asJsonMap(jsonDecode(text), path);
  }
}

/// القارئ المشترك؛ تستبدله الاختبارات بحزمة أصول وهمية عند الحاجة.
final Provider<AssetJsonSource> assetJsonSourceProvider = Provider<AssetJsonSource>(
  (Ref ref) => AssetJsonSource(rootBundle),
);

/// سياسة إعادة المحاولة لمزودات المحتوى: لا إعادة.
Duration? contentNoRetry(int retryCount, Object error) => null;
