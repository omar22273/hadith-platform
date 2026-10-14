// عناصر مضمّنة (WidgetSpan) آمنة الاتجاه داخل نص عربي.
//
// خوارزمية الاتجاه تعامل العنصر المضمّن حرفاً محايداً، فإذا تجاور عنصران أو أكثر تفصل بينها
// مسافات كوّنت سلسلة محايدة تُرسم من اليسار إلى اليمين فتنعكس. إحاطة كل عنصر بعلامة اليمين
// إلى اليسار (RLM) تجعله بين حرفين قويين من اتجاه العربية فيلتزم ترتيب القراءة.

import 'package:flutter/widgets.dart';

/// علامة اليمين إلى اليسار (لا تظهر ولا تشغل عرضاً).
const String rightToLeftMark = '‏';

/// يضيف [placeholder] إلى [spans] محاطاً بعلامتي RTL.
void addRtlSafePlaceholder(List<InlineSpan> spans, WidgetSpan placeholder, {TextStyle? style}) {
  spans
    ..add(TextSpan(text: rightToLeftMark, style: style))
    ..add(placeholder)
    ..add(TextSpan(text: rightToLeftMark, style: style));
}
