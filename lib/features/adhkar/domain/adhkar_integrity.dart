// فحص سلامة ملف الأذكار قبل عرضه: معرّفات وترتيب فريدان، وعنوان ونص غير
// فارغين، وعدد مسنون موجب، وشاهد لكل ذكر بموضعه ونصه الحرفي ومصدره المعروف،
// ونص الذكر نفسه (وفضله إن وُجد) جزء من نص أحد شواهده فلا يُعرض لفظ بلا أصل منقول.
//
// الاستثناء الوحيد المسموح: ذكر له اشتقاق (derivation) هو إبدال كلمة واحدة بكلمة
// منقولة بتشكيلها حرفاً بحرف من شاهد آخر للذكر؛ فيُقبل نصه إذا رُدّت الكلمة المبدَّلة
// إلى أصلها فصار جزءاً حرفياً من أحد الشواهد.
//
// وكل ذكر ضعّفه الألباني في درجته المسجلة (grading) لا بد أن يحمل caution يُظهر التنبيه
// على بطاقته، والمسارات (tracks) إما على كل أذكار الملف أو على لا شيء منها.

import '../../../core/content/models/source_catalog.dart';
import '../../../core/content/models/source_ref.dart';
import '../data/models/adhkar.dart';

final RegExp _marks = RegExp('[\u064B-\u0670\u0640]');
final RegExp _alefs = RegExp('[\u0623\u0625\u0622\u0671]');
final RegExp _notLetters = RegExp('[^\u0621-\u064A]');
final RegExp _albaniWeak = RegExp('الألباني: (ضعيف|موضوع|منكر)');

/// الحروف العربية الأصلية وحدها بلا حركات ولا علامات، مع توحيد الهمزات والياء والتاء المربوطة.
String _skeleton(String value) {
  return value
      .replaceAll(_marks, '')
      .replaceAll(_alefs, '\u0627')
      .replaceAll('\u0649', '\u064A')
      .replaceAll('\u0629', '\u0647')
      .replaceAll(_notLetters, '');
}

List<String> _tokens(String value) => value.split(RegExp(r'\s+')).where((String t) => t.isNotEmpty).toList();

/// يتحقق من اشتقاق ذكر ويعيد المشكلات؛ الفارغة تعني أن النص مقبول.
List<String> _checkDerivation(DhikrItem item, String path) {
  final TextDerivation derivation = item.derivation!;
  final String to = _skeleton(derivation.toWord);
  final String from = _skeleton(derivation.fromWord);
  final List<String> tokens = _tokens(item.text);
  final List<String> swapped = tokens.where((String t) => _skeleton(t) == to).toList();
  if (swapped.length != 1) {
    return <String>['$path.derivation: The replaced word must occur exactly once in the text.'];
  }
  final List<String> quotes = item.evidence.map((SourceRef r) => r.quote ?? '').toList();
  if (!quotes.any((String q) => _tokens(q).contains(swapped.single))) {
    return <String>['$path.derivation: The replacement word must be taken with its vocalization from an evidence quote.'];
  }
  final String restored = tokens.map((String t) => _skeleton(t) == to ? from : _skeleton(t)).join();
  if (!quotes.any((String q) => _skeleton(q).contains(restored))) {
    return <String>['$path.derivation: The text with the original word restored must be a verbatim part of an evidence quote.'];
  }
  return const <String>[];
}

/// يعيد قائمة المشكلات؛ الفارغة تعني أن الملف سليم. [trackIds] مسارات الفئة المسموحة إن كانت ذات تبديل.
List<String> checkAdhkarCatalog(AdhkarCatalog catalog, {SourceCatalog? sources, Set<String>? trackIds}) {
  final List<String> issues = <String>[];
  final Set<String> ids = <String>{};
  final Set<int> orders = <int>{};
  final int tracked = catalog.items.where((DhikrItem i) => i.tracks != null).length;
  if (tracked != 0 && tracked != catalog.items.length) {
    issues.add('items: tracks must be set on every dhikr or on none.');
  }
  if (trackIds != null && trackIds.isNotEmpty && tracked != catalog.items.length) {
    issues.add('items: a category with a track toggle needs tracks on every dhikr.');
  }
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
    final List<String>? own = item.tracks;
    if (own != null) {
      if (own.isEmpty || own.toSet().length != own.length) {
        issues.add('$path.tracks: must be non-empty and without repeats.');
      }
      final Set<String>? allowed = trackIds;
      if (allowed != null && own.any((String t) => !allowed.contains(t))) {
        issues.add('$path.tracks: unknown track in $own.');
      }
    }
    final bool weak = _albaniWeak.hasMatch(item.grading ?? '');
    if (weak && (item.caution ?? '').trim().isEmpty) {
      issues.add('$path.caution: A dhikr graded weak by al-Albani must carry its caution banner.');
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
    if (item.derivation != null && item.text.trim().isNotEmpty) {
      final List<String> derived = _checkDerivation(item, path);
      issues.addAll(derived);
      grounded = derived.isEmpty;
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
