import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class AndroidNotificationService {
  AndroidNotificationService._();
  static final AndroidNotificationService instance = AndroidNotificationService._();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  AndroidNotificationChannel? _analysisReadyChannel;
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
}