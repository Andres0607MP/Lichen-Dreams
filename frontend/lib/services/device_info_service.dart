import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceInfoService {
  static const String _deviceIdKey = 'device_id';
  static Future<String>? _deviceNameFuture;
  static String? _cachedDeviceName;

  Future<String> get deviceName => getDeviceName();

  Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }

    final generated = _generateUuidV4();
    await prefs.setString(_deviceIdKey, generated);
    return generated;
  }

  static Future<String> getDeviceName() async {
    final cachedName = _cachedDeviceName;
    if (cachedName != null) {
      return cachedName;
    }

    final pendingName = _deviceNameFuture;
    if (pendingName != null) {
      return pendingName;
    }

    final nameFuture = _resolveDeviceName();
    _deviceNameFuture = nameFuture;
    try {
      final resolvedName = await nameFuture;
      _cachedDeviceName = resolvedName;
      return resolvedName;
    } finally {
      _deviceNameFuture = null;
    }
  }

  static Future<String> _resolveDeviceName() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        return _formatAndroidName(
          androidInfo.model,
          androidInfo.manufacturer,
        );
      }
    } catch (_) {
      // Keep login usable if native device information is unavailable.
    }

    return _platformDeviceName();
  }

  static String _formatAndroidName(String? model, String? manufacturer) {
    final cleanModel = _cleanValue(model);
    final cleanManufacturer = _capitalize(_cleanValue(manufacturer));

    if (cleanModel.isEmpty) {
      return 'Android';
    }

    if (cleanManufacturer.isEmpty ||
        _normalizedContains(cleanModel, cleanManufacturer)) {
      return '$cleanModel (Android)';
    }

    return '$cleanManufacturer $cleanModel (Android)';
  }

  static String _cleanValue(String? value) {
    return value
            ?.replaceAll(RegExp(r'[\r\n\t]+'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim() ??
        '';
  }

  static String _capitalize(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;

    return '${trimmed[0].toUpperCase()}${trimmed.substring(1).toLowerCase()}';
  }

  static bool _normalizedContains(String value, String candidate) {
    final normalizedValue = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    final normalizedCandidate = candidate
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    return normalizedCandidate.isNotEmpty &&
        normalizedValue.contains(normalizedCandidate);
  }

  static String _platformDeviceName() {
    if (Platform.isIOS) return 'iOS';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Dispositivo';
  }

  static String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return [
      hex.substring(0, 8),
      hex.substring(8, 12),
      hex.substring(12, 16),
      hex.substring(16, 20),
      hex.substring(20, 32),
    ].join('-');
  }
}
