// خدمة تشغيل التلاوات المسجلة من شبكة توزيع المحتوى (CDN) فوق just_audio.
//
// يُبث المقطع من رابطه عبر LockCachingAudioSource، فيُحفظ في الذاكرة المؤقتة
// على الجهاز أثناء التشغيل الأول ويُقرأ منها بعد ذلك دون اتصال. وعلى الويب،
// حيث لا نظام ملفات للتخزين المؤقت، يُبث الرابط مباشرة.
//
// متطلبات المنصات (انظر README):
// - أندرويد: إذن INTERNET، والسماح بالاتصال غير المشفر إلى 127.0.0.1 وحده؛
//   لأن just_audio يمرر البث المخزَّن عبر خادم وكيل محلي على الجهاز.
// - iOS: NSAllowsLocalNetworking في NSAppTransportSecurity للسبب نفسه.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// مرحلة المشغل كما تظهر للمستخدم.
enum AudioPhase {
  /// لا مقطع محمّل.
  idle,

  /// جلب المقطع من الشبكة.
  loading,

  /// تخزين مؤقت أثناء التشغيل.
  buffering,

  /// جاهز للتشغيل.
  ready,

  /// يُشغَّل الآن.
  playing,

  /// انتهى المقطع.
  completed,
}

/// سبب تعذر الجلب.
enum AudioFailureKind {
  /// انتهت مهلة الاتصال قبل وصول المقطع.
  timeout,

  /// تعذر الوصول إلى الخادم أو قراءة المقطع.
  network,
}

/// خطأ جلب المقطع.
class AudioLoadException implements Exception {
  const AudioLoadException(this.kind, [this.detail]);

  /// السبب.
  final AudioFailureKind kind;

  /// تفاصيل تقنية للسجل.
  final String? detail;

  @override
  String toString() => 'AudioLoadException(${kind.name}${detail == null ? '' : ': $detail'})';
}

/// عقد خدمة التشغيل؛ تستبدلها الاختبارات بتنفيذ وهمي.
abstract interface class AudioPlayerService {
  /// مراحل المشغل.
  Stream<AudioPhase> get phaseStream;

  /// موضع التشغيل المطلق داخل المقطع.
  Stream<Duration> get positionStream;

  /// يجلب المقطع ويخزنه مؤقتاً، ويرمي [AudioLoadException] عند الفشل.
  Future<Duration?> load(Uri url, {required Duration timeout});

  /// يشغل المقطع كاملاً وينتهي عند آخره.
  Future<void> playAll();

  /// يشغل مدى من المقطع.
  Future<void> playRange({required Duration start, required Duration end});

  /// يوقف التشغيل.
  Future<void> stop();

  /// يحرر المشغل.
  Future<void> dispose();
}

/// التنفيذ الإنتاجي.
class JustAudioPlayerService implements AudioPlayerService {
  JustAudioPlayerService() : _player = AudioPlayer();

  final AudioPlayer _player;
  Uri? _loaded;

  @override
  Stream<AudioPhase> get phaseStream => _player.playerStateStream.map(_phaseOf);

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  static AudioPhase _phaseOf(PlayerState state) {
    switch (state.processingState) {
      case ProcessingState.idle:
        return AudioPhase.idle;
      case ProcessingState.loading:
        return AudioPhase.loading;
      case ProcessingState.buffering:
        return AudioPhase.buffering;
      case ProcessingState.ready:
        return state.playing ? AudioPhase.playing : AudioPhase.ready;
      case ProcessingState.completed:
        return AudioPhase.completed;
    }
  }

  @override
  Future<Duration?> load(Uri url, {required Duration timeout}) async {
    if (_loaded == url) {
      return _player.duration;
    }
    _loaded = null;
    // LockCachingAudioSource معلَّم «تجريبياً» في just_audio، وهو المطلوب صراحة
    // للبث مع التخزين المؤقت؛ وتُثبَّت نسخة الحزمة في pubspec.lock.
    final AudioSource source =
        // ignore: experimental_member_use
        kIsWeb ? AudioSource.uri(url) : LockCachingAudioSource(url);
    try {
      final Duration? duration = await _player.setAudioSource(source).timeout(timeout);
      _loaded = url;
      return duration;
    } on TimeoutException {
      await _player.stop();
      throw const AudioLoadException(AudioFailureKind.timeout);
    } on PlayerInterruptedException catch (error) {
      throw AudioLoadException(AudioFailureKind.network, error.message);
    } on PlayerException catch (error) {
      throw AudioLoadException(AudioFailureKind.network, '${error.code}: ${error.message}');
    } on Exception catch (error) {
      throw AudioLoadException(AudioFailureKind.network, error.toString());
    }
  }

  // لا يُستعمل setClip هنا: يقبل just_audio القصاصة مع UriAudioSource وحده،
  // والمصدر المخزَّن مؤقتاً StreamAudioSource. فيُشغَّل المدى بالانتقال إلى
  // بدايته ثم الإيقاف عند نهايته من مجرى الموضع، والمواضع كلها مطلقة.

  @override
  Future<void> playAll() async {
    await _player.seek(Duration.zero);
    await _player.play();
    await _player.pause();
  }

  @override
  Future<void> playRange({required Duration start, required Duration end}) async {
    await _player.seek(start);
    final StreamSubscription<Duration> watch = _player.positionStream.listen((Duration position) {
      if (position >= end && _player.playing) {
        unawaited(_player.pause());
      }
    });
    try {
      await _player.play();
    } finally {
      await watch.cancel();
    }
    await _player.pause();
  }

  @override
  Future<void> stop() => _player.pause();

  @override
  Future<void> dispose() => _player.dispose();
}

/// مصنع المشغلات: مشغل مستقل لكل حديث مفتوح.
final Provider<AudioPlayerService Function()> audioPlayerFactoryProvider =
    Provider<AudioPlayerService Function()>(
  (Ref ref) => JustAudioPlayerService.new,
);
