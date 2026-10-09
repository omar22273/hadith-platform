// صياغة الإحالات المقروءة إلى المصادر، مشتركة بين الحديث والسيرة.

import '../text/arabic_digits.dart';
import 'models/source_catalog.dart';
import 'models/source_ref.dart';

/// يبني إحالة مقروءة: «جامع العلوم والحكم · ج١ ص٧٣» أو «صحيح البخاري · رقم ٣٩٠٦».
String formatCitation(SourceWork? source, SourceRef ref) {
  final String title = source?.title ?? ref.sourceId;
  final String? locator = ref.locator;
  if (locator == null || locator.isEmpty) {
    return title;
  }
  final bool numeric = RegExp(r'^\d+$').hasMatch(locator);
  final String place = numeric ? 'رقم ${arabicDigits(locator)}' : arabicDigits(locator);
  return '$title · $place';
}

/// اسم المؤلف مع العنوان إن لم يكن العنوان دالاً عليه.
String formatSourceByline(SourceWork? source) {
  if (source == null) {
    return '';
  }
  if (source.title.contains(source.author)) {
    return source.title;
  }
  return '${source.author}، ${source.title}';
}
