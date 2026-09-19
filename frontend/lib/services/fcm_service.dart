import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../routes/route_names.dart';
import '../services/navigation_service.dart';
import 'android_notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await AndroidNotificationService.instance.initialize();
    final data = message.data;
    final titulo = data['titulo'] ?? data['title'] ?? 'Notificación';
    final mensaje = data['mensaje'] ?? data['body'] ?? '';
    final idNotificacion = data['id_notificacion'] ?? '';
    final notifId = int.tryParse(idNotificacion) ??
        (90000 + idNotificacion.hashCode.abs() % 100000);

    await AndroidNotificationService.instance.showSystemNotification(
      id: notifId,
      title: titulo,
      body: mensaje,
      payload: idNotificacion,
    );
  } catch (e) {
    debugPrint('[FCM Background] Error showing notification: $e');
  }
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  String? _fcmToken;
  bool _initialized = false;
  String? Function()? _getAuthToken;
  StreamSubscription<String>? _tokenRefreshSubscription;
  RemoteMessage? _initialMessage;

  void setAuthTokenProvider(String? Function() provider) {
    _getAuthToken = provider;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await Firebase.initializeApp();
    await FirebaseMessaging.instance.requestPermission();

    _fcmToken = await FirebaseMessaging.instance.getToken();
    debugPrint('[FCM] Token inicial: ${_fcmToken?.substring(0, 20)}...');

    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) async {
        _fcmToken = token;
        debugPrint('[FCM] Token renovado: ${token.substring(0, 20)}...');
        final authToken = _getAuthToken?.call();
        if (authToken != null && authToken.isNotEmpty) {
          await registerToken(authToken);
        }
      },
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM] onMessage recibido: ${message.messageId}');
      _showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] onMessageOpenedApp recibido: ${message.messageId}');
      _navigateToActivityCenter(message);
    });

    _initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (_initialMessage != null) {
      debugPrint('[FCM] App abierta desde notificación (getInitialMessage)');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToActivityCenter(_initialMessage!);
      });
    }
  }

  Future<void> registerToken(String authToken) async {
    if (_fcmToken == null || _fcmToken!.isEmpty) return;

    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/auth/fcm-token');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'fcm_token': _fcmToken}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('[FCM] Token registrado exitosamente');
      } else {
        debugPrint(
            '[FCM] Error al registrar token: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[FCM] Error al registrar token: $e');
    }
  }

  Future<void> unregisterToken(String authToken) async {
    if (_fcmToken == null || _fcmToken!.isEmpty) return;

    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/auth/fcm-token');
      await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[FCM] Error al eliminar token: $e');
    }
  }

  String? get token => _fcmToken;

  bool get isInitialized => _initialized;

  void _showLocalNotification(RemoteMessage message) {
    final data = message.data;
    final titulo = data['titulo'] ?? data['title'] ?? 'Notificación';
    final mensaje = data['mensaje'] ?? data['body'] ?? '';
    final idNotificacion = data['id_notificacion'] ?? '';

    final notifId = int.tryParse(idNotificacion) ??
        (90000 + idNotificacion.hashCode.abs() % 100000);

    AndroidNotificationService.instance.showSystemNotification(
      id: notifId,
      title: titulo,
      body: mensaje,
      payload: idNotificacion,
    );
  }

  void _navigateToActivityCenter(RemoteMessage message) {
    debugPrint('[FCM] Navegando al Centro de Actividad');
    final navigator = LichenNavigation.navigatorKey.currentState;
    if (navigator != null) {
      navigator.pushNamed(AppRoutes.historial);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToActivityCenter(message);
      });
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _fcmToken = null;
    _getAuthToken = null;
    _initialized = false;
  }
}
