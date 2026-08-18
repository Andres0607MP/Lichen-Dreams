import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsState extends ChangeNotifier {
  static const String _keyTextScale = 'app_text_scale_factor';
  static const double defaultScale = 1.0;

  double _textScaleFactor = defaultScale;

  double get textScaleFactor => _textScaleFactor;

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble(_keyTextScale);
      if (saved != null) {
        _textScaleFactor = saved.clamp(0.85, 1.30);
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
}
