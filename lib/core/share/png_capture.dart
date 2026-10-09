// التقاط عنصر مرسوم داخل RepaintBoundary صورةَ PNG عالية الدقة.

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// أكبر بُعد بالبكسل في الصورة الناتجة؛ يحمي من حدود نسيج المعالج الرسومي في
/// الأجهزة المتواضعة حين يكون المتن طويلاً.
const double maxCaptureDimension = 7000;

/// يلتقط ما رُسم تحت [boundaryKey] بدقة [pixelRatio] (تُخفَّض تلقائياً إن
/// تجاوزت الصورة [maxCaptureDimension]). يرمي [StateError] إن لم يكن المفتاح
/// على RepaintBoundary مرسوم.
Future<List<int>> captureBoundaryPng(GlobalKey boundaryKey, {double pixelRatio = 3}) async {
  final RenderObject? object = boundaryKey.currentContext?.findRenderObject();
  if (object is! RenderRepaintBoundary) {
    throw StateError('Capture key is not attached to a RepaintBoundary.');
  }
  final Size size = object.size;
  final double longest = size.longestSide <= 0 ? 1 : size.longestSide;
  final double ratio = pixelRatio * longest > maxCaptureDimension ? maxCaptureDimension / longest : pixelRatio;
  final ui.Image image = await object.toImage(pixelRatio: ratio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('Failed to encode the captured image.');
    }
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
  }
}
