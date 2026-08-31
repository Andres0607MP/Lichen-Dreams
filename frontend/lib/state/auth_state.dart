import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/google_auth_service.dart';
import '../services/navigation_service.dart';
import 'notifications_state.dart';
import 'dashboard_state.dart';
import 'history_state.dart';
import 'map_state.dart';
import 'profile_state.dart';
import 'articles_state.dart';

class AuthState extends ChangeNotifier {
  final ApiService _apiService;
  final GoogleAuthService _googleAuth;
  String? _token;
  String? _refreshToken;
  String? _role;
  String? _userName;
  int? _userId;
  String? _proveedor;
  bool _loading = false;

  static const String _userNameKey = 'user_name';
  static const String _userIdKey = 'user_id';
  static const String _proveedorKey = 'user_proveedor';

  AuthState({ApiService? apiService, GoogleAuthService? googleAuth})
      : _apiService = apiService ?? ApiService(),
        _googleAuth = googleAuth ?? GoogleAuthService();

  String? get token => _token;
  String? get refreshToken => _refreshToken;
  String? get role => _role;
  String? get userName => _userName;
  int? get userId => _userId;
  String? get proveedor => _proveedor;
  bool get isGoogleAccount => _proveedor == 'google';
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  bool get isAdmin => _role == 'admin';
  bool get loading => _loading;

  Future<void> initialize() async {
    _token = await _apiService.getToken();
    _refreshToken = await _apiService.getRefreshToken();
    _role = await _apiService.getSavedRole();
    await _loadPersistedUserInfo();
    notifyListeners();
  }

  Future<void> _loadPersistedUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    _userName = prefs.getString(_userNameKey);
    _proveedor = prefs.getString(_proveedorKey);
    final userIdStr = prefs.getString(_userIdKey);
    if (userIdStr != null && userIdStr.isNotEmpty) {
      _userId = int.tryParse(userIdStr);
    }
  }

  Future<void> _persistUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (_userName != null) {
      await prefs.setString(_userNameKey, _userName!);
    } else {
      await prefs.remove(_userNameKey);
    }
    if (_proveedor != null) {
      await prefs.setString(_proveedorKey, _proveedor!);
    } else {
      await prefs.remove(_proveedorKey);
    }
    if (_userId != null) {
      await prefs.setString(_userIdKey, _userId.toString());
    } else {
      await prefs.remove(_userIdKey);
    }
  }

  Future<void> _clearPersistedUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userNameKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_proveedorKey);
  }

  /// Refresca la información canónica de la cuenta (/auth/me) de forma
  /// best-effort: rol, nombre, id de usuario y proveedor ('local' | 'google').
  Future<void> syncProvider() async {
    if (_token == null || _token!.isEmpty) return;
    try {
      final me = await _apiService.getMe();
      final rol = me['rol']?.toString();
      final nombre = me['nombre']?.toString();
      final id = _parseUserId(me['id_usuario']);
      final proveedor = me['proveedor']?.toString();
      if (rol != null) _role = rol;
      if (nombre != null) _userName = nombre;
      if (id != null) _userId = id;
      if (proveedor != null) _proveedor = proveedor;
      await _persistUserInfo();
      notifyListeners();
    } catch (_) {
      // best-effort: si la red falla se conserva la información local.
    }
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
        _proveedor = user['proveedor']?.toString();
      }
      await _persistUserInfo();
      notifyListeners();
      await NotificationsState.instance.loadNotifications();
      return true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> loginWithGoogle() async {
    await clearAuthState();
    setState(() => _loading = true);
    try {
      final idToken = await _googleAuth.signInAndGetIdToken();
      if (idToken == null) {
        // El usuario canceló Google Sign-In: continuar en la pantalla de login.
        return false;
      }

      final data = await _apiService.loginWithGoogle(idToken);
      _token = data['access_token'] as String?;
      _refreshToken = data['refresh_token'] as String?;
      if (data['user'] is Map) {
        final user = data['user'] as Map<String, dynamic>;
        _role = user['rol']?.toString();
        _userName = user['nombre']?.toString();
        _userId = _parseUserId(user['id_usuario'] ?? user['id']);
        _proveedor = user['proveedor']?.toString();
      }
      await _persistUserInfo();
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
      await _persistUserInfo();
      notifyListeners();
    } catch (_) {
      // silently fail
    }
  }

  void updateUserFromProfile(Map<String, dynamic> profile) {
    _userName = profile['nombre']?.toString() ?? _userName;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> register({
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
          _proveedor = user['proveedor']?.toString();
        }
        await _persistUserInfo();
        notifyListeners();
        await NotificationsState.instance.loadNotifications();
      }
      return data;
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
    _proveedor = null;
    await _clearPersistedUserInfo();
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
    _proveedor = null;
    await _clearPersistedUserInfo();
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

  Future<void> forgotPassword(String email) async {
    await _apiService.forgotPassword(email);
  }

  Future<void> resetPassword(String token, String newPassword) async {
    await _apiService.resetPassword(token, newPassword);
  }

  Future<void> recoverWithCode(String code, String newPassword) async {
    await _apiService.recoverWithCode(code, newPassword);
  }

  Future<Map<String, dynamic>> regenerateRecoveryCode() async {
    return _apiService.regenerateRecoveryCode();
  }

  Future<void> verifyEmail(String token) async {
    await _apiService.verifyEmail(token);
  }

  Future<void> resendVerification(String email) async {
    await _apiService.resendVerification(email);
  }

  void setState(bool Function() fn) {
    final changed = fn();
    if (changed) notifyListeners();
  }
}
