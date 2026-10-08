// صوت آلي (TTS) للسرد القصصي والمأزق فقط.
//
// سياسة ثابتة: لا يُقرأ بهذا الصوت متن حديث ولا نص منقول من رواية. المتن
// يُسمع حصراً من تسجيل قارئ متقن عبر مشغل التلاوة.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// سرعة السرد.
enum SpeechPace {
  /// سرعة طبيعية.
  normal('normal', 0.46),

  /// سرعة متمهلة لكبار السن.
  slow('slow', 0.34);

  const SpeechPace(this.wire, this.rate);

  /// القيمة المخزنة.
  final String wire;

  /// معدل الكلام في محرك النظام (0 - 1).
  final double rate;

  /// يحوّل القيمة المخزنة.
  static SpeechPace fromWire(String? value) {
    return value == SpeechPace.slow.wire ? SpeechPace.slow : SpeechPace.normal;
  }
}

/// خدمة الكلام.
abstract interface class SpeechService {
  /// يجهز الصوت العربي، ويعيد false إن لم يتوفر على الجهاز.
  Future<bool> prepareArabic();

  /// ينطق النص وينتظر حتى ينتهي.
  Future<void> speak(String text, {required SpeechPace pace});

  /// يوقف الكلام فوراً.
  Future<void> stop();
}

/// التنفيذ فوق محرك الكلام في النظام.
class FlutterTtsSpeechService implements SpeechService {
  FlutterTtsSpeechService() : _tts = FlutterTts();

  final FlutterTts _tts;
  bool? _arabicReady;

  static const List<String> _arabicLocales = <String>['ar-SA', 'ar-EG', 'ar'];

  @override
  Future<bool> prepareArabic() async {
    if (_arabicReady == true) {
      return true;
    }
    bool ready = false;
    try {
      await _tts.awaitSpeakCompletion(true);
      for (final String locale in _arabicLocales) {
        final dynamic available = await _tts.isLanguageAvailable(locale);
        if (available == true || available == 1) {
          await _tts.setLanguage(locale);
          ready = true;
          break;
        }
      }
    } on Exception {
      ready = false;
    }
    // يُحفظ النجاح فقط؛ فإن لم يكن المحرك جاهزاً يُعاد الفحص في المرة التالية.
    _arabicReady = ready ? true : null;
    return ready;
  }

  @override
  Future<void> speak(String text, {required SpeechPace pace}) async {
    if (text.trim().isEmpty) {
      return;
    }
    await _tts.setSpeechRate(pace.rate);
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }
}

/// خدمة صامتة للاختبارات وللأجهزة بلا محرك كلام.
class SilentSpeechService implements SpeechService {
  const SilentSpeechService();

  @override
  Future<bool> prepareArabic() async => false;

  @override
  Future<void> speak(String text, {required SpeechPace pace}) async {}

  @override
  Future<void> stop() async {}
}

/// خدمة الكلام المستعملة في التطبيق.
final Provider<SpeechService> speechServiceProvider = Provider<SpeechService>(
  (Ref ref) {
    final FlutterTtsSpeechService service = FlutterTtsSpeechService();
    ref.onDispose(() {
      unawaited(service.stop());
    });
    return service;
  },
);
