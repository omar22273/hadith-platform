// ورقة سفلية موحدة: قابلة للتمرير، بحواف ناعمة ومقبض سحب.

import 'package:flutter/material.dart';

/// يعرض ورقة سفلية قابلة للتمرير لا تتجاوز ٩٠٪ من ارتفاع الشاشة.
Future<T?> showSmoothSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      final double maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.9;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: EdgeInsetsDirectional.fromSTEB(
            20,
            0,
            20,
            24 + MediaQuery.paddingOf(sheetContext).bottom,
          ),
          child: builder(sheetContext),
        ),
      );
    },
  );
}
