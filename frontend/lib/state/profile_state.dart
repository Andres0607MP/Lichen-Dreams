import 'package:flutter/foundation.dart';
import 'dart:io';
import '../services/api_service.dart';

class ProfileState extends ChangeNotifier {
  final ApiService _apiService;
  ProfileState({ApiService? apiService}) : _apiService = apiService ?? ApiService();
  Map<String, dynamic>? _profile;
  bool _loading = false;
  String? _error;
  File? _pendingImage;
  DateTime? _lastLoadedAt;
  static const Duration _cacheDuration = Duration(seconds: 60);

  Map<String, dynamic>? get profile => _profile;
  bool get loading => _loading;
  String? get error => _error;
  File? get pendingImage => _pendingImage;
  bool get hasFreshData => _lastLoadedAt != null && DateTime.now().difference(_lastLoadedAt!) < _cacheDuration;

  Future<void> loadProfile({bool force = false}) async {
    if (_loading) return;
    if (!force && hasFreshData) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _profile = await _apiService.getProfile();
      _lastLoadedAt = DateTime.now();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      String? imageUrl;
      if (_pendingImage != null) {
        final url = await _apiService.uploadImage(_pendingImage!, imageType: 'profile');
        if (url.isEmpty) {
          throw ApiException('URL de imagen vacía');
        }
        imageUrl = url;
      }

      final payload = Map<String, dynamic>.from(data);
      if (imageUrl != null) {
        payload['foto_perfil'] = imageUrl;
      }

      final updated = await _apiService.updateProfile(payload);
      _profile = updated;
      _pendingImage = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setPendingImage(File? file) {
    _pendingImage = file;
    notifyListeners();
  }

  void discardChanges() {
    _pendingImage = null;
    _error = null;
    notifyListeners();
  }

  Future<void> reset() {
    _profile = null;
    _error = null;
    _loading = false;
    _pendingImage = null;
    _lastLoadedAt = null;
    notifyListeners();
    return Future.value();
  }

  void setState(bool Function() fn) {
    final changed = fn();
    if (changed) notifyListeners();
  }
}
