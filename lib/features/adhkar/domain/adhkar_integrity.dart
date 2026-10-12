// فحص سلامة ملف الأذكار قبل عرضه: معرّفات وترتيب فريدان، وعنوان ونص غير
// فارغين، وعدد مسنون موجب، وشاهد لكل ذكر بموضعه ونصه الحرفي ومصدره المعروف،
// ونص الذكر نفسه (وفضله إن وُجد) جزء من نص أحد شواهده فلا يُعرض لفظ بلا أصل منقول.

import '../../../core/content/models/source_catalog.dart';
import '../../../core/content/models/source_ref.dart';
import '../data/models/adhkar.dart';

/// يعيد قائمة المشكلات؛ الفارغة تعني أن الملف سليم.
List<String> checkAdhkarCatalog(AdhkarCatalog catalog, {SourceCatalog? sources}) {
  final List<String> issues = <String>[];
  final Set<String> ids = <String>{};
  final Set<int> orders = <int>{};
  for (int index = 0; index < catalog.items.length; index++) {
    final DhikrItem item = catalog.items[index];
    final String path = 'items[$index]';
    if (!ids.add(item.id)) {
      issues.add('$path: Duplicate dhikr id "${item.id}".');
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
    if (item.count < 1) {
      issues.add('$path.count: must be at least 1.');
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
      issues.add('$path.text: The dhikr text must be a verbatim part of one of its evidence quotes.');
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
  return issues;
}
