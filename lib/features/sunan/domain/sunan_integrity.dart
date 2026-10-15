// فحص سلامة ملف السنن قبل عرضه: معرّفات وترتيب فريدان، وعنوان ونص غير فارغين،
// وشاهد لكل سنة بموضعه ونصه الحرفي ومصدره المعروف، ونص السنة (وفضلها إن وُجد) جزء حرفي
// من نص أحد شواهدها فلا يُعرض لفظ بلا أصل منقول. وكل سنة ضعّفها الألباني في درجتها المسجلة
// تحمل caution يُظهر التنبيه على بطاقتها. ولكل باب من أبواب الشريط بطاقة واحدة على الأقل،
// فلا يُفتح باب فارغ.

import '../../../core/content/models/source_catalog.dart';
import '../../../core/content/models/source_ref.dart';
import '../data/models/sunan.dart';

final RegExp _albaniWeak = RegExp('الألباني: (ضعيف|موضوع|منكر)');

/// يعيد قائمة المشكلات؛ الفارغة تعني أن الملف سليم.
List<String> checkSunanCatalog(SunanCatalog catalog, {SourceCatalog? sources}) {
  final List<String> issues = <String>[];
  final Set<String> ids = <String>{};
  final Set<int> orders = <int>{};
  final Set<SunnahBab> babs = <SunnahBab>{};
  for (int index = 0; index < catalog.items.length; index++) {
    final SunnahItem item = catalog.items[index];
    final String path = 'items[$index]';
    babs.add(item.bab);
    if (!ids.add(item.id)) {
      issues.add('$path: Duplicate sunnah id "${item.id}".');
    }
    if (!orders.add(item.order)) {
      issues.add('$path: Duplicate order ${item.order}.');
    }
    if (item.title.trim().isEmpty) {
      issues.add('$path.title: must not be blank.');
    }
    if (item.text.trim().isEmpty) {
      issues.add('$path.text: must not be blank.');
    }
    final bool weak = _albaniWeak.hasMatch(item.grading ?? '');
    if (weak && (item.caution ?? '').trim().isEmpty) {
      issues.add('$path.caution: A sunnah graded weak by al-Albani must carry its caution banner.');
    }
    if ((item.caution ?? '').trim().isNotEmpty && (item.grading ?? '').trim().isEmpty) {
      issues.add('$path.caution: A caution needs the recorded grading it comes from.');
    }
    bool grounded = false;
    for (int e = 0; e < item.evidence.length; e++) {
      final SourceRef source = item.evidence[e];
      final String quote = source.quote ?? '';
      if (quote.trim().isEmpty) {
        issues.add('$path.evidence[$e]: Evidence must carry its verbatim quote.');
      } else if (item.text.trim().isNotEmpty && quote.contains(item.text.trim())) {
        grounded = true;
      }
      if ((source.locator ?? '').trim().isEmpty) {
        issues.add('$path.evidence[$e]: Evidence must carry its locator.');
      }
      final SourceCatalog? known = sources;
      if (known != null && known.byId(source.sourceId) == null) {
        issues.add('$path.evidence[$e]: Unknown sourceId "${source.sourceId}".');
      }
    }
    if (!grounded) {
      issues.add('$path.text: The sunnah text must be a verbatim part of one of its evidence quotes.');
    }
    final String? virtue = item.virtue;
    if (virtue != null) {
      if (virtue.trim().isEmpty) {
        issues.add('$path.virtue: must not be blank when present.');
      } else if (!item.evidence.any((SourceRef r) => (r.quote ?? '').contains(virtue.trim()))) {
        issues.add('$path.virtue: The virtue must be a verbatim part of one of its evidence quotes.');
      }
    }
  }
  for (final SunnahBab bab in SunnahBab.values) {
    if (!babs.contains(bab)) {
      issues.add('items: The bab "${bab.wire}" has no sunnah.');
    }
  }
  return issues;
}
