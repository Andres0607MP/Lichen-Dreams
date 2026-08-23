import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class NotificationSoundService {
  NotificationSoundService._();
  static final NotificationSoundService instance = NotificationSoundService._();

  static const String _notificationAsset = 'audio/notification.mp3';
  static const String _analysisCompleteAsset = 'audio/analysis_complete.mp3';
  static const String _analysisFailedAsset = 'audio/analysis_failed.mp3';

  final AudioPlayer _player = AudioPlayer();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationSoundService] Init error: $e');
      }
    }
  }

  Future<void> _playAsset(String assetPath, bool soundEnabled) async {
    if (!soundEnabled) return;

    try {
      await _player.stop();
      await _player.play(AssetSource(assetPath));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationSoundService] Asset not found or play error: $e');
        debugPrint('[NotificationSoundService] Expected asset: $assetPath');
        debugPrint('[NotificationSoundService] Please add the audio file to assets/audio/');
      }
    }
  }

  Future<void> playNotificationSound(bool soundEnabled) async {
    await _playAsset(_notificationAsset, soundEnabled);
  }

  Future<void> playAnalysisCompleteSound(bool soundEnabled) async {
    await _playAsset(_analysisCompleteAsset, soundEnabled);
  }

  Future<void> playAnalysisFailedSound(bool soundEnabled) async {
    await _playAsset(_analysisFailedAsset, soundEnabled);
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (_) {}
  }

  void reset() {
    _initialized = false;
  }
}
