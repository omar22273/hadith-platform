// مشغل تلاوة المتن المسجلة بصوت قارئ متقن (just_audio).
//
// هذا هو المصدر الوحيد لسماع المتن في التطبيق. إن لم يُسجَّل المتن بعد
// (AudioStatus.notRecorded) لا يُشغَّل شيء، ولا يُستبدل بصوت آلي.

import 'package:just_audio/just_audio.dart';

/// غلاف رقيق فوق AudioPlayer.
class RecitationPlayer {
  RecitationPlayer() : _player = AudioPlayer();

  final AudioPlayer _player;
  String? _loadedAsset;

  /// موضع التشغيل داخل المقطع الحالي.
  Stream<Duration> get positionStream => _player.positionStream;

  /// يحمّل ملف التلاوة من الأصول، ويعيد false إن تعذر.
  Future<bool> load(String assetPath) async {
    if (_loadedAsset == assetPath) {
      return true;
    }
    try {
      await _player.setAsset(assetPath);
      _loadedAsset = assetPath;
      return true;
    } catch (_) {
      _loadedAsset = null;
      return false;
    }
  }

  /// يشغّل التلاوة كاملة وينتظر انتهاءها.
  Future<void> playAll() async {
    await _player.setClip();
    await _player.seek(Duration.zero);
    await _player.play();
    await _player.pause();
  }

  /// يشغّل مدى زمنياً وينتظر انتهاءه.
  Future<void> playRange({required Duration start, required Duration end}) async {
    await _player.setClip(start: start, end: end);
    await _player.seek(Duration.zero);
    await _player.play();
    await _player.pause();
  }

  /// يوقف التشغيل.
  Future<void> stop() => _player.pause();

  /// يحرر الموارد.
  Future<void> dispose() => _player.dispose();
}
