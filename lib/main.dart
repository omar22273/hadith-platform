// نقطة الدخول: تهيئة التخزين المحلي وتسجيل تراخيص الخطوط المضمنة، ثم تشغيل
// التطبيق داخل ProviderScope مع المخزن الإنتاجي.
//
// محرك الرسم Impeller هو الافتراضي على iOS وAndroid في إصدارات Flutter الحالية،
// ولا يحتاج التطبيق إلى إعداد إضافي لتفعيله.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/hadith_app.dart';
import 'core/diagnostics/diagnostic_views.dart';
import 'core/storage/key_value_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // الاتجاه الرأسي وحده: يمنع تشوه التخطيط عند تدوير الجهاز.
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // أي خطأ في البناء يُعرض نصاً مقروءاً بدل مساحة فارغة صامتة.
  ErrorWidget.builder = buildVisibleErrorWidget;
  FlutterError.onError = (FlutterErrorDetails details) {
    recordRuntimeError(details.exception, details.stack);
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    recordRuntimeError(error, stack);
    return true;
  };

  // خطا Amiri وReadex Pro من Google Fonts مضمنان برخصة SIL OFL، وتظهر
  // رخصتاهما في صفحة التراخيص.
  LicenseRegistry.addLicense(() async* {
    for (final String family in const <String>['Amiri', 'ReadexPro']) {
      final String license = await rootBundle.loadString('assets/fonts/OFL-$family.txt');
      yield LicenseEntryWithLineBreaks(<String>[family], license);
    }
  });

  // فشل فتح التخزين لا يجوز أن يمنع التطبيق من العمل: نسقط إلى مخزن الذاكرة
  // ونُبقي السبب ظاهراً في شريط التشخيص.
  KeyValueStore store;
  try {
    store = await SharedPreferencesStore.open();
  } on Object catch (error, stack) {
    recordRuntimeError('تعذر فتح التخزين المحلي: $error', stack);
    store = InMemoryKeyValueStore();
  }

  runApp(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
      ],
      child: const HadithApp(),
    ),
  );
}
