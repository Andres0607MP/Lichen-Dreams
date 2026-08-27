import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsState extends ChangeNotifier {
  static const String _keyTextScale = 'app_text_scale_factor';
  static const String _keySoundEnabled = 'app_sound_enabled';
  static const String _keyDarkMode = 'app_dark_mode';
  static const double defaultScale = 1.0;
  static const bool defaultSoundEnabled = true;
  static const bool defaultDarkMode = false;

  double _textScaleFactor = defaultScale;
  bool _soundEnabled = defaultSoundEnabled;
  bool _darkMode = defaultDarkMode;

  double get textScaleFactor => _textScaleFactor;
  bool get soundEnabled => _soundEnabled;
  bool get darkMode => _darkMode;

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble(_keyTextScale);
      if (saved != null) {
        _textScaleFactor = saved.clamp(0.85, 1.30);
      }
      final savedSound = prefs.getBool(_keySoundEnabled);
      if (savedSound != null) {
        _soundEnabled = savedSound;
      }
      final savedDarkMode = prefs.getBool(_keyDarkMode);
      if (savedDarkMode != null) {
        _darkMode = savedDarkMode;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading app settings: $e');
      }
    }
    notifyListeners();
  }

  Future<void> setTextScaleFactor(double value) async {
    _textScaleFactor = value.clamp(0.85, 1.30);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyTextScale, _textScaleFactor);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving app settings: $e');
      }
    }
  }

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keySoundEnabled, _soundEnabled);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving sound setting: $e');
      }
    }
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyDarkMode, _darkMode);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving dark mode setting: $e');
      }
    }
  }
}
