import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../services/navigation_service.dart';
import 'notifications_state.dart';
import 'dashboard_state.dart';
import 'history_state.dart';
import 'map_state.dart';
import 'profile_state.dart';
import 'articles_state.dart';

class AuthState extends ChangeNotifier {
  final ApiService _apiService;
  String? _token;
  String? _refreshToken;
  String? _role;
  String? _userName;
  int? _userId;
  bool _loading = false;

  AuthState({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  String? get token => _token;
  String? get refreshToken => _refreshToken;
  String? get role => _role;
  String? get userName => _userName;
  int? get userId => _userId;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  bool get isAdmin => _role == 'admin';
  bool get loading => _loading;

  Future<void> initialize() async {
    _token = await _apiService.getToken();
    _refreshToken = await _apiService.getRefreshToken();
    _role = await _apiService.getSavedRole();
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    await clearAuthState();
    setState(() => _loading = true);
    try {
      final data = await _apiService.login(email, password);
      _token = data['access_token'] as String?;
      _refreshToken = data['refresh_token'] as String?;
      if (data['user'] is Map) {
        final user = data['user'] as Map<String, dynamic>;
        _role = user['rol']?.toString();
        _userName = user['nombre']?.toString();
        _userId = _parseUserId(user['id_usuario'] ?? user['id']);
      }
      notifyListeners();
      await NotificationsState.instance.loadNotifications();
      return true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadProfile() async {
    try {
      final profile = await _apiService.getProfile();
      _userName = profile['nombre']?.toString();
      notifyListeners();
    } catch (_) {
      // silently fail
    }
  }

  void updateUserFromProfile(Map<String, dynamic> profile) {
    _userName = profile['nombre']?.toString() ?? _userName;
    notifyListeners();
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    String? apellido,
    String? phone,
    String? tipoDocumento,
    String? numeroDocumento,
    String? fechaNacimiento,
  }) async {
    await clearAuthState();
    setState(() => _loading = true);
    try {
      final data = await _apiService.register(
        name,
        email,
        password,
        apellido: apellido,
        phone: phone,
        tipoDocumento: tipoDocumento,
        numeroDocumento: numeroDocumento,
        fechaNacimiento: fechaNacimiento,
      );
      if (data['access_token'] != null) {
        _token = data['access_token'] as String?;
        _refreshToken = data['refresh_token'] as String?;
        if (data['user'] is Map<String, dynamic>) {
          final user = data['user'] as Map<String, dynamic>;
          _role = user['rol']?.toString();
          _userName = user['nombre']?.toString();
          _userId = _parseUserId(user['id_usuario'] ?? user['id']);
        }
        notifyListeners();
        await NotificationsState.instance.loadNotifications();
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> logout([BuildContext? context]) async {
    await _apiService.logout();
    _token = null;
    _refreshToken = null;
    _role = null;
    _userName = null;
    _userId = null;
    LichenNavigation.instance.reset();
    NotificationsState.instance.reset();
    if (context != null) {
      unawaited(context.read<DashboardState>().reset());
      unawaited(context.read<HistoryState>().reset());
      unawaited(context.read<MapState>().reset());
      unawaited(context.read<ProfileState>().reset());
      unawaited(context.read<ArticlesState>().reset());
    }
    notifyListeners();
  }

  Future<void> clearAuthState([BuildContext? context]) async {
    await _apiService.clearAuth();
    _token = null;
    _refreshToken = null;
    _role = null;
    _userName = null;
    _userId = null;
    LichenNavigation.instance.reset();
    NotificationsState.instance.reset();
    if (context != null) {
      unawaited(context.read<DashboardState>().reset());
      unawaited(context.read<HistoryState>().reset());
      unawaited(context.read<MapState>().reset());
      unawaited(context.read<ProfileState>().reset());
      unawaited(context.read<ArticlesState>().reset());
    }
    notifyListeners();
  }

  int? _parseUserId(dynamic value) {
    if (value is int) return value;
    if (value is String && value.isNotEmpty) return int.tryParse(value);
    return null;
  }

  void setState(bool Function() fn) {
    final changed = fn();
    if (changed) notifyListeners();
  }
}
