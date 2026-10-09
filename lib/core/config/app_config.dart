// ملف إعدادات التطبيق: رقم الإصدار، وقالب رابط التسجيلات الصوتية على شبكة
// توزيع المحتوى (CDN)، ومهلة جلب المقطع.
//
// قالب الصوت قابل للتخصيص دون تعديل الكود عند البناء:
//   flutter build apk --dart-define=AUDIO_CDN_TEMPLATE=https://example.org/audio/hadith_{id}.mp3
// و{id} يُستبدل بمعرّف الحديث، مثل nawawi40_001.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// إعدادات التطبيق.
@immutable
class AppConfig {
  const AppConfig({
    required this.version,
    required this.audioUrlTemplate,
    required this.audioLoadTimeout,
  });

  /// الإعدادات المعتمدة في هذا الإصدار.
  static const AppConfig standard = AppConfig(
    version: appVersion,
    audioUrlTemplate: String.fromEnvironment(
      'AUDIO_CDN_TEMPLATE',
      defaultValue: defaultAudioUrlTemplate,
    ),
    audioLoadTimeout: Duration(seconds: 20),
  );

  /// رقم الإصدار المعروض في الإعدادات، ويطابق version في pubspec.yaml.
  static const String appVersion = '2.2.0';

  /// القالب التجريبي الافتراضي.
  static const String defaultAudioUrlTemplate =
      'https://cdn.hadithplatform.app/audio/hadith_{id}.mp3';

  /// العلامة التي تُستبدل بمعرّف الحديث.
  static const String idPlaceholder = '{id}';

  /// رقم الإصدار.
  final String version;

  /// قالب رابط التلاوة.
  final String audioUrlTemplate;

  /// أقصى انتظار لجلب المقطع قبل إعلان انتهاء المهلة.
  final Duration audioLoadTimeout;

  /// رابط تلاوة حديث بعينه.
  Uri audioUrlFor(String hadithId) {
    return Uri.parse(audioUrlTemplate.replaceAll(idPlaceholder, Uri.encodeComponent(hadithId)));
  }
}

/// إعدادات التطبيق؛ تستبدلها الاختبارات عند الحاجة.
final Provider<AppConfig> appConfigProvider = Provider<AppConfig>(
  (Ref ref) => AppConfig.standard,
);
