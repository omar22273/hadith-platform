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
import 'core/storage/key_value_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // خطا Amiri وReadex Pro من Google Fonts مضمنان برخصة SIL OFL، وتظهر
  // رخصتاهما في صفحة التراخيص.
  LicenseRegistry.addLicense(() async* {
    for (final String family in const <String>['Amiri', 'ReadexPro']) {
      final String license = await rootBundle.loadString('assets/fonts/OFL-$family.txt');
      yield LicenseEntryWithLineBreaks(<String>[family], license);
    }
  });

  final SharedPreferencesStore store = await SharedPreferencesStore.open();

  runApp(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
      ],
      child: const HadithApp(),
    ),
  );
}
