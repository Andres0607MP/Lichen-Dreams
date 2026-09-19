import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../routes/route_names.dart';
import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../services/device_info_service.dart';
import '../services/google_auth_service.dart';
import '../services/navigation_service.dart';
import 'notifications_state.dart';
import 'dashboard_state.dart';
import 'history_state.dart';
import 'map_state.dart';
import 'profile_state.dart';
import 'articles_state.dart';

enum BootstrapStatus { loading, retrying, error }

class AuthState extends ChangeNotifier {
  final ApiService _apiService;
  final GoogleAuthService _googleAuth;
  final ConnectivityService _connectivityService;
  String? _token;
  String? _refreshToken;
  String? _role;
  String? _userName;
  int? _userId;
  String? _proveedor;
  bool _loading = false;
  BootstrapStatus _bootstrapStatus = BootstrapStatus.loading;
  bool _isBootstrapping = false;
  WidgetsBindingObserver? _lifecycleObserver;

  static const String _userNameKey = 'user_name';
  static const String _userIdKey = 'user_id';
  static const String _proveedorKey = 'user_proveedor';

AuthState({ApiService? apiService, GoogleAuthService? googleAuth, ConnectivityService? connectivityService})
       : _apiService = apiService ?? ApiService(),
         _googleAuth = googleAuth ?? GoogleAuthService(),
         _connectivityService = connectivityService ?? ConnectivityService(startMonitoring: false) {
     _apiService.setUnauthorizedHandler(() => clearAuthState());
   }

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
  BootstrapStatus get bootstrapStatus => _bootstrapStatus;
  bool get isBootstrapping => _isBootstrapping;

  String get bootstrapMessage {
    if (_bootstrapStatus == BootstrapStatus.retrying) {
      return 'El servidor se está iniciando...';
    }
    if (_bootstrapStatus == BootstrapStatus.error) {
      return 'No pudimos conectar con el servidor.';
    }
    return 'Preparando tu sesión...';
  }

  Future<void> initialize() async {
    _token = await _apiService.getToken();
    _refreshToken = await _apiService.getRefreshToken();
    _role = await _apiService.getSavedRole();
    await _loadPersistedUserInfo();
    notifyListeners();
    _startSessionCheckTimer();
  }

  Future<void> bootstrapAndDecide(BuildContext context) async {
    if (_isBootstrapping) return;
    _isBootstrapping = true;
    _setBootstrapStatus(
      _bootstrapStatus == BootstrapStatus.error
          ? BootstrapStatus.retrying
          : BootstrapStatus.loading,
    );

    final navigator = Navigator.of(context);

    try {
      final backendAvailable = await _connectivityService.checkBackendWithRetry(
        onProgress: (attempt, maxAttempts, retrying) {
          if (retrying) {
            _setBootstrapStatus(BootstrapStatus.retrying);
          }
        },
      );

      if (!backendAvailable) {
        _setBootstrapStatus(BootstrapStatus.error);
        return;
      }

      if (!isAuthenticated) {
        await clearAuthState(null, false);
        _replaceRoute(navigator, AppRoutes.login);
        return;
      }

      _setBootstrapStatus(BootstrapStatus.loading);
      await validateSession();

      if (!isAuthenticated) {
        _replaceRoute(navigator, AppRoutes.login);
        return;
      }

      _replaceRoute(navigator, AppRoutes.dashboard);
    } catch (_) {
      _setBootstrapStatus(BootstrapStatus.error);
    } finally {
      _isBootstrapping = false;
    }
  }

  void _setBootstrapStatus(BootstrapStatus status) {
    if (_bootstrapStatus == status) return;
    _bootstrapStatus = status;
    notifyListeners();
  }

  void _replaceRoute(NavigatorState navigator, String routeName) {
    if (!navigator.mounted) return;
    navigator.pushNamedAndRemoveUntil(routeName, (_) => false);
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

  /// Refresca la informaciÃ³n canÃ³nica de la cuenta (/auth/me) de forma
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
      // best-effort: si la red falla se conserva la informaciÃ³n local.
    }
  }

  Future<bool> login(String email, String password) async {
    await clearAuthState(null, false);
    final deviceInfo = DeviceInfoService();
    await deviceInfo.getOrCreateDeviceId();
    await DeviceInfoService.getDeviceName();
    setState(() => _loading = true);
    try {
      final data = await _apiService.login(email, password);
      _token = data['access_token'] as String?;
      _refreshToken = data['refresh_token'] as String?;
      if (data['access_token'] != null && data['refresh_token'] != null) {
        await _apiService.saveAuthTokens(
          data['access_token'] as String,
          data['refresh_token'] as String,
        );
      }
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
      _hasNavigatedToLogin = false;
      return true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> loginWithGoogle({bool registrar = false}) async {
    await clearAuthState();
    await DeviceInfoService().getOrCreateDeviceId();
    setState(() => _loading = true);
    try {
      final idToken = await _googleAuth.signInAndGetIdToken();
      if (idToken == null) {
        // El usuario cancelÃ³ Google Sign-In: continuar en la pantalla actual.
        return false;
      }

      final data = await _apiService.loginWithGoogle(
        idToken,
        modo: registrar ? 'registro' : 'login',
      );
      _token = data['access_token'] as String?;
      _refreshToken = data['refresh_token'] as String?;
      if (data['access_token'] != null && data['refresh_token'] != null) {
        await _apiService.saveAuthTokens(
          data['access_token'] as String,
          data['refresh_token'] as String,
        );
      }
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
      _hasNavigatedToLogin = false;
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
        _refreshToken = data['refreshToken'] as String?;
        if (data['access_token'] != null && data['refreshToken'] != null) {
          await _apiService.saveAuthTokens(
            data['access_token'] as String,
            data['refreshToken'] as String,
          );
        }
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
        _hasNavigatedToLogin = false;
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
    _stopSessionCheckTimer();
    _closeWebSocket();
    notifyListeners();
  }

  Future<void> clearAuthState([BuildContext? context, bool navigateToLogin = true]) async {
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
    _stopSessionCheckTimer();
    _closeWebSocket();
    notifyListeners();
    if (navigateToLogin && !_hasNavigatedToLogin) {
      _hasNavigatedToLogin = true;
      final navContext = LichenNavigation.navigatorKey.currentContext;
      if (navContext != null) {
        Navigator.of(navContext).pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false,
        );
      }
    }
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

  WebSocket? _sessionWebSocket;
  Timer? _reconnectTimer;
  int _reconnectDelay = 1;
  bool _isShowingSessionRevokedDialog = false;
  bool _isWebSocketConnected = false;
  bool _hasNavigatedToLogin = false;

  void _connectWebSocket() {
    if (_sessionWebSocket != null || _isWebSocketConnected) return;
    if (!isAuthenticated) return;
    final token = _token;
    if (token == null || token.isEmpty) return;
    _reconnectDelay = 1;
    final uri = AppConfig.buildWsUri('/ws/sessions').toString();
    WebSocket.connect(uri, headers: {
      'Authorization': 'Bearer $token',
    }).then((ws) {
      if (_token == null) {
        ws.close();
        return;
      }
      _sessionWebSocket = ws;
      _isWebSocketConnected = true;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _reconnectDelay = 1;
      ws.listen(
        (data) {
          try {
            final message = jsonDecode(data);
            if (message is Map<String, dynamic>) {
              final type = message['type']?.toString();
              if (type == 'SESSION_REVOKED') {
                _handleSessionRevoked();
              }
            }
          } catch (_) {}
        },
        onDone: () {
          _isWebSocketConnected = false;
          _sessionWebSocket = null;
          _scheduleReconnect();
        },
        onError: (error) {
          _isWebSocketConnected = false;
          _sessionWebSocket = null;
          _scheduleReconnect();
        },
      );
    }).catchError((error) {
      _scheduleReconnect();
    });
  }

  void _closeWebSocket() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    if (_sessionWebSocket != null) {
      try {
        _sessionWebSocket!.close();
      } catch (_) {}
      _sessionWebSocket = null;
    }
    _isWebSocketConnected = false;
  }

  void _scheduleReconnect() {
    if (_reconnectTimer != null) return;
    if (!_isInForeground) return;
    if (!isAuthenticated) return;
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelay), () {
      _reconnectTimer = null;
      if (!_isInForeground || !isAuthenticated) return;
      _reconnectDelay = (_reconnectDelay * 2 > 30) ? 30 : _reconnectDelay * 2;
      _connectWebSocket();
    });
  }

  void _handleSessionRevoked() {
    if (_isShowingSessionRevokedDialog) return;
    _isShowingSessionRevokedDialog = true;
    final context = LichenNavigation.navigatorKey.currentContext;
    if (context == null) {
      _isShowingSessionRevokedDialog = false;
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Tu sesión fue revocada'),
          content: const Text('Esta sesión fue cerrada desde otro dispositivo.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                clearAuthState();
              },
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    ).then((_) {
      _isShowingSessionRevokedDialog = false;
    });
  }

  // Session validation via polling
  Timer? _sessionCheckTimer;
  bool _isValidatingSession = false;
  bool _isInForeground = false;
  static const Duration _sessionCheckInterval = Duration(minutes: 2);

  /// Validates the current session by calling /auth/me
  /// If the session is invalid or revoked, clears the auth state
  /// Only responds to HTTP 401 (session revoked/invalid), ignores network errors
  Future<void> validateSession() async {
    if (!isAuthenticated) return;
    if (_isValidatingSession) return;
    _isValidatingSession = true;

    try {
      await _apiService.getMe();
      // Session is valid - nothing to do
    } on ApiException catch (e) {
      // Check if this is a 401 error (session revoked or invalid)
      if (e.statusCode == 401) {
        // Auth error - clear auth state
        // Note: AuthenticatedHttpClient may have already called handleUnauthorized()
        // which calls clearAuthState(). This is safe to call again as it's idempotent.
        if (isAuthenticated) {
          await clearAuthState();
        }
      }
      // Other API errors (5xx, etc.) - ignore
    } on TimeoutException {
      // Network timeout - ignore
    } on SocketException {
      // No connection - ignore
    } on ClientException {
      // Connection error - ignore
    } catch (_) {
      // Any other error - ignore (network issues, etc.)
    }

    _isValidatingSession = false;
  }

  void _startSessionCheckTimer() {
    _stopSessionCheckTimer();
    if (isAuthenticated && _isInForeground) {
      _sessionCheckTimer = Timer.periodic(
        _sessionCheckInterval,
        (_) => validateSession(),
      );
    }
  }

  void _stopSessionCheckTimer() {
    _sessionCheckTimer?.cancel();
    _sessionCheckTimer = null;
  }

  void _onAppLifecycleChanged(AppLifecycleState state) {
    final wasInForeground = _isInForeground;
    _isInForeground = state == AppLifecycleState.resumed;

    if (_isInForeground && !wasInForeground) {
      validateSession().then((_) {
        if (isAuthenticated && _isInForeground) {
          _startSessionCheckTimer();
          _connectWebSocket();
        }
      });
    } else if (!_isInForeground && wasInForeground) {
      _stopSessionCheckTimer();
      _closeWebSocket();
    }
  }

  void initLifecycle() {
    _lifecycleObserver = _AppLifecycleObserver(this);
    WidgetsBinding.instance.addObserver(_lifecycleObserver!);
  }

  void disposeLifecycle() {
    if (_lifecycleObserver != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
      _lifecycleObserver = null;
    }
  }

  void dispose() {
    disposeLifecycle();
    _stopSessionCheckTimer();
  }
}

class _AppLifecycleObserver extends WidgetsBindingObserver {
  final AuthState _authState;

  _AppLifecycleObserver(this._authState);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _authState._onAppLifecycleChanged(state);
  }
}
