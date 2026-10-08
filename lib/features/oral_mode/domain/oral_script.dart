// نصوص مجلس السماع: تُبنى حصراً من حقول السرد والمأزق المكتوبة للمنصة
// (السياق والدافع والموقف والخيارات والتغذية والعلة)، ولا يدخلها متن ولا
// نص منقول من رواية، فهي وحدها ما يُقرأ بالصوت الآلي.

import '../../../core/text/arabic_digits.dart';
import '../../hadith/data/models/models.dart';

/// يهيئ النص للصوت الآلي: يكتب الصلاة على النبي ﷺ كاملة ويزيل علامات التنصيص.
String speechSafe(String text) {
  return text
      .replaceAll('ﷺ', 'صلى الله عليه وسلم')
      .replaceAll(RegExp(r'[«»"]'), '')
      .replaceAll('…', '، ')
      .trim();
}

/// يقسم الفقرة إلى جمل قصيرة تناسب السرد والعرض المكبّر.
List<String> splitSentences(String text) {
  return text
      .split(RegExp(r'(?<=[.؟!؛])\s+'))
      .map((String sentence) => sentence.trim())
      .where((String sentence) => sentence.isNotEmpty)
      .toList();
}

const List<String> _ordinals = <String>['الأول', 'الثاني', 'الثالث', 'الرابع', 'الخامس', 'السادس'];

/// ترتيب الخيار بالكلمة.
String optionOrdinal(int index) {
  return index >= 0 && index < _ordinals.length ? _ordinals[index] : arabicDigits(index + 1);
}

/// سطور السرد القصصي.
List<String> storyLines(HadithDailyModel hadith) {
  return <String>[
    ...splitSentences(hadith.context.narrative),
    'والدافع البشري في القصة: ${hadith.context.humanMotive}',
  ];
}

/// سطور عرض المأزق وخياراته.
List<String> dilemmaLines(Scenario scenario) {
  return <String>[
    ...splitSentences(scenario.situation),
    scenario.question,
    for (int i = 0; i < scenario.options.length; i++)
      'الخيار ${optionOrdinal(i)}: ${scenario.options[i].text}',
  ];
}

/// سطور التغذية بعد الاختيار.
List<String> feedbackLines(ScenarioOption option, Scenario scenario) {
  return <String>[
    option.feedback,
    'والعلّة التربوية: ${scenario.takeaway}',
  ];
}

/// نص مقطع الحفظ للعرض المكبّر (يُعرض ولا يُقرأ بالصوت الآلي).
String chunkDisplayText(HadithDailyModel hadith, PracticeChunk chunk) {
  final MatnSegment? segment = hadith.matn.segmentById(chunk.segmentId);
  if (segment == null) {
    return '';
  }
  final List<MatnToken> tokens = segment.tokens;
  if (chunk.startToken < 0 || chunk.endToken >= tokens.length || chunk.endToken < chunk.startToken) {
    return '';
  }
  return tokens
      .sublist(chunk.startToken, chunk.endToken + 1)
      .map((MatnToken token) => token.raw)
      .join(' ');
}
