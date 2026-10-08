// تقسيم المتن إلى كلمات وفق عقد ثابت مشترك مع خط معالجة البيانات.
//
// العقد: يُقسم النص على المسافات، ثم تُفصل علامات الترقيم من أول الكلمة
// وآخرها. كل مرساة (TokenAnchor) أو توقيت صوتي يشير إلى رقم الكلمة الناتج
// عن هذا التقسيم، فأي تغيير هنا يجب أن يقابله تغيير في خط المعالجة.
//
// Hadith Platform — data model v1.1.0.

import 'package:flutter/foundation.dart';

/// كلمة واحدة من مقطع المتن.
@immutable
class MatnToken {
  const MatnToken({
    required this.index,
    required this.raw,
    required this.leading,
    required this.core,
    required this.trailing,
  });

  /// رقم الكلمة داخل المقطع (يبدأ من صفر).
  final int index;

  /// الكلمة كما في النص بعلامات ترقيمها.
  final String raw;

  /// علامات الترقيم قبل الكلمة.
  final String leading;

  /// الكلمة المشكولة دون علامات الترقيم.
  final String core;

  /// علامات الترقيم بعد الكلمة.
  final String trailing;

  /// هل الكلمة هي رمز الصلاة على النبي ﷺ.
  bool get isHonorific => core == MatnTokenizer.honorific;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MatnToken &&
        index == other.index &&
        raw == other.raw &&
        leading == other.leading &&
        core == other.core &&
        trailing == other.trailing;
  }

  @override
  int get hashCode => Object.hash(index, raw, leading, core, trailing);
}

/// مقسّم المتن.
class MatnTokenizer {
  MatnTokenizer._();

  /// رمز الصلاة على النبي ﷺ (U+FDFA).
  static const String honorific = 'ﷺ';

  /// علامات الترقيم التي تُفصل عن الكلمة.
  static const Set<String> punctuation = <String>{
    '"',
    "'",
    '«',
    '»',
    '(',
    ')',
    '[',
    ']',
    '{',
    '}',
    ':',
    '.',
    ',',
    '،',
    '؛',
    '؟',
    '!',
    '?',
    '…',
  };

  static final RegExp _whitespace = RegExp(r'\s+');

  /// يقسم النص إلى كلمات غير قابلة للتعديل.
  static List<MatnToken> tokenize(String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const <MatnToken>[];
    }
    final List<MatnToken> tokens = <MatnToken>[];
    for (final String raw in trimmed.split(_whitespace)) {
      if (raw.isEmpty) {
        continue;
      }
      int start = 0;
      int end = raw.length;
      while (start < end && punctuation.contains(raw[start])) {
        start++;
      }
      while (end > start && punctuation.contains(raw[end - 1])) {
        end--;
      }
      tokens.add(
        MatnToken(
          index: tokens.length,
          raw: raw,
          leading: raw.substring(0, start),
          core: raw.substring(start, end),
          trailing: raw.substring(end),
        ),
      );
    }
    return List<MatnToken>.unmodifiable(tokens);
  }

  /// يجمع الكلمات المشكولة لمدى معيّن بمسافة واحدة، لمطابقة حقل surface.
  static String surfaceOf(List<MatnToken> tokens, int start, int length) {
    return tokens
        .sublist(start, start + length)
        .map((MatnToken token) => token.core)
        .join(' ');
  }
}
