// نص مشاركة الحديث: المتن المشكول كما هو في ملف البيانات حرفاً بحرف، يليه
// التخريج الموثق. لا يُضاف إليه شرح ولا حكم من خارج الملف.

import '../../../core/text/arabic_digits.dart';
import 'hadith_bundle.dart';

/// يبني نص المشاركة.
String buildHadithShareText(HadithBundle bundle) {
  final StringBuffer out = StringBuffer()
    ..writeln(bundle.hadith.matn.fullText)
    ..writeln()
    ..writeln('${bundle.hadith.collection.title} · الحديث ${arabicDigits(bundle.hadith.collection.numberInCollection)}')
    ..writeln('التخريج: ${bundle.hadith.matn.takhrij.displayLabel}');
  for (final reference in bundle.hadith.matn.takhrij.references) {
    out.writeln('• ${bundle.sourceTitle(reference.sourceId)} · رقم ${arabicDigits(reference.hadithNumber)}');
  }
  out
    ..writeln()
    ..write('— منصة الحديث النبوي');
  return out.toString();
}
