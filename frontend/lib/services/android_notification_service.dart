import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class AndroidNotificationService {
  AndroidNotificationService._();
  static final AndroidNotificationService instance = AndroidNotificationService._();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  AndroidNotificationChannel? _analysisReadyChannel;
  AndroidNotificationChannel? _generalChannel;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (defaultTargetPlatform == TargetPlatform.android) {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      final InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: null,
        onDidReceiveBackgroundNotificationResponse: null,
      );

// Create the dedicated channel for analysis ready notifications
       _analysisReadyChannel = AndroidNotificationChannel(
         'analysis_ready',
         'Análisis listo',
         description: 'Notificación cuando un análisis está listo',
         importance: Importance.high,
         enableVibration: true,
         vibrationPattern: Int64List.fromList(<int>[0, 500, 500, 500]),
         playSound: false,
       );

// Create the dedicated channel for general system notifications
       _generalChannel = AndroidNotificationChannel(
         'general_notifications',
         'Notificaciones generales',
         description: 'Notificaciones del sistema de Lichen Dreams',
         importance: Importance.high,
         enableVibration: true,
         vibrationPattern: Int64List.fromList(<int>[0, 500, 500, 500]),
         playSound: true,
       );

// Request POST_NOTIFICATIONS permission on Android 13+
       try {
         final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
             _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
                 AndroidFlutterLocalNotificationsPlugin>();
         if (androidImplementation != null) {
           await androidImplementation.requestNotificationsPermission();
         }
       } catch (e) {
         // ignore errors
       }
    }
  }

  Future<void> showAnalysisReady(int analysisId, String resultTitle) async {
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    if (!_initialized) {
      await initialize();
    }
    if (_analysisReadyChannel == null) return;

    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      _analysisReadyChannel!.id,
      _analysisReadyChannel!.name,
      channelDescription: _analysisReadyChannel!.description,
      importance: _analysisReadyChannel!.importance,
      enableVibration: _analysisReadyChannel!.enableVibration,
      vibrationPattern: _analysisReadyChannel!.vibrationPattern,
      playSound: _analysisReadyChannel!.playSound,
    );

    final platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

await _flutterLocalNotificationsPlugin.show(
       id: analysisId,
       title: 'Tu análisis está listo',
       body: resultTitle,
       notificationDetails: platformChannelSpecifics,
       payload: analysisId.toString(),
     );
  }

  Future<void> showSystemNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) {
      await initialize();
    }
    if (_generalChannel == null) return;

    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      _generalChannel!.id,
      _generalChannel!.name,
      channelDescription: _generalChannel!.description,
      importance: _generalChannel!.importance,
      enableVibration: _generalChannel!.enableVibration,
      vibrationPattern: _generalChannel!.vibrationPattern,
      playSound: _generalChannel!.playSound,
      icon: '@mipmap/ic_launcher',
    );

    final platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: payload,
    );
  }
}