import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class NotificationsState extends ChangeNotifier {
  NotificationsState._();
  static final NotificationsState instance = NotificationsState._();
  final List<Map<String, dynamic>> _notifications = [];
  bool _loading = false;
  String? _error;
  DateTime? _lastLoadedAt;
  static const Duration _cacheDuration = Duration(seconds: 30);

  List<Map<String, dynamic>> get notifications => List.unmodifiable(_notifications);
  bool get loading => _loading;
  String? get error => _error;
  int get unreadCount => _notifications.where((n) => n['leida'] != true).length;
  bool get hasFreshData => _lastLoadedAt != null && DateTime.now().difference(_lastLoadedAt!) < _cacheDuration;

  Future<void> loadNotifications({ApiService? apiService, bool force = false}) async {
    if (_loading) return;
    if (!force && hasFreshData) return;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final service = apiService ?? ApiService();
      debugPrint('NOTIFICATIONS: cargando notificaciones...');
      final remote = await service.getNotifications();
      debugPrint('NOTIFICATIONS: respuesta recibida, cantidad=${remote.length}');

      _notifications.clear();
      for (final item in remote) {
        _notifications.add(_mapBackendNotification(item));
      }
      _notifications.sort((a, b) {
        final dateA = DateTime.tryParse(a['fecha']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = DateTime.tryParse(b['fecha']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });
      _lastLoadedAt = DateTime.now();
      debugPrint('NOTIFICATIONS: procesadas, total=${_notifications.length}, unreadCount=$unreadCount');
    } catch (e) {
      _error = e.toString();
      debugPrint('NOTIFICATIONS ERROR: $e');
    } finally {
      _loading = false;
      notifyListeners();
      debugPrint('NOTIFICATIONS: notifyListeners ejecutado');
    }
  }

  Map<String, dynamic> _mapBackendNotification(Map<String, dynamic> item) {
    final tipo = (item['tipo_notificacion']?.toString() ?? 'general').toLowerCase();
    final estado = (item['estado_notificacion']?.toString() ?? 'pendiente').toLowerCase();
    String mappedEstado = 'general';
    if (estado == 'leida') {
      mappedEstado = 'leida';
    } else if (tipo == 'analysis') {
      if (estado == 'completada' || estado == 'completed') {
        mappedEstado = 'completed';
      } else if (estado == 'procesando' || estado == 'processing' || estado == 'pendiente') {
        mappedEstado = 'processing';
      } else if (estado == 'fallida' || estado == 'failed' || estado == 'error') {
        mappedEstado = 'failed';
      } else {
        mappedEstado = estado;
      }
    }

    final mensajeRaw = item['mensaje']?.toString() ?? '';
    final analysisId = _extractAnalysisIdFromMensaje(mensajeRaw);
    var mensaje = mensajeRaw;
    if (analysisId != null) {
      final prefix = 'analysis_id=$analysisId|';
      if (mensaje.startsWith(prefix)) {
        mensaje = mensaje.substring(prefix.length);
      }
    }

    return {
      'id': item['id']?.toString() ?? '',
      'id_notificacion': item['id'],
      'id_usuario': item['id_usuario'],
      'titulo': item['titulo'] ?? 'Notificación',
      'mensaje': mensaje,
      'tipo': tipo,
      'estado': mappedEstado,
      'tipo_notificacion': item['tipo_notificacion'],
      'estado_notificacion': item['estado_notificacion'],
      'fecha': item['fecha']?.toString() ?? DateTime.now().toIso8601String(),
      'leida': mappedEstado == 'leida',
      'analysis_id': analysisId,
    };
  }

  int? _extractAnalysisIdFromMensaje(dynamic mensaje) {
    if (mensaje is! String) return null;
    final prefix = 'analysis_id=';
    final start = mensaje.indexOf(prefix);
    if (start < 0) return null;
    final rawStart = start + prefix.length;
    final end = mensaje.indexOf('|', rawStart);
    final numberPart = end >= 0 ? mensaje.substring(rawStart, end) : mensaje.substring(rawStart);
    return int.tryParse(numberPart.trim());
  }

  Future<void> markAsRead(String id) async {
    var index = _notifications.indexWhere((n) => n['id'] == id);
    if (index < 0 && id.startsWith('analysis_')) {
      final analysisId = int.tryParse(id.substring('analysis_'.length));
      if (analysisId != null) {
        index = _notifications.indexWhere((n) => n['analysis_id'] == analysisId);
      }
    }

    if (index >= 0) {
      _notifications[index] = Map<String, dynamic>.from(_notifications[index]);
      _notifications[index]['leida'] = true;
      _notifications[index]['estado'] = 'leida';
      notifyListeners();
    }

    final backendId = index >= 0 ? _notifications[index]['id_notificacion'] : null;
    final effectiveId = backendId is int ? backendId.toString() : id;
    final intId = int.tryParse(effectiveId);
    if (intId != null) {
      await markAsReadBackend(intId.toString());
    }
  }

  Future<void> markAsReadBackend(String id, {ApiService? apiService}) async {
    final intId = int.tryParse(id);
    if (intId == null) return;
    try {
      final service = apiService ?? ApiService();
      await service.markNotificationRead(intId);
    } catch (_) {
      // no bloquear UI por error de sync
    }
  }

  Future<void> markAllAsRead({ApiService? apiService}) async {
    final service = apiService ?? ApiService();
    for (final notification in _notifications) {
      final estado = notification['estado']?.toString() ?? 'leida';
      if (estado != 'leida') {
        final index = _notifications.indexOf(notification);
        if (index >= 0) {
          _notifications[index] = Map<String, dynamic>.from(_notifications[index]);
          _notifications[index]['estado'] = 'leida';
          _notifications[index]['leida'] = true;
        }
        final id = notification['id']?.toString() ?? '';
        final intId = int.tryParse(id);
        if (intId != null) {
          try {
            await service.markNotificationRead(intId);
          } catch (_) {
            // no bloquear UI por error de sync
          }
        }
      }
    }
    notifyListeners();
  }

  Future<void> clearAll({ApiService? apiService}) async {
    _notifications.clear();
    notifyListeners();
  }

  Future<void> clearAllFromBackend({ApiService? apiService}) async {
    try {
      final service = apiService ?? ApiService();
      await service.clearNotifications();
      await clearAll();
      _error = null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> reset() {
      _notifications.clear();
      _error = null;
      _loading = false;
      _lastLoadedAt = null;
      notifyListeners();
      return Future.value();
  }

  void trackAnalysis(int analysisId, String title) {
    final existing = _notifications.indexWhere((n) => n['analysis_id'] == analysisId);
    if (existing >= 0) {
      _notifications[existing] = Map<String, dynamic>.from(_notifications[existing]);
      _notifications[existing]['leida'] = false;
      notifyListeners();
      return;
    }

    final existingByMessage = _notifications.indexWhere(
      (n) => (n['mensaje']?.toString() ?? '').startsWith('analysis_id=$analysisId|'),
    );
    if (existingByMessage >= 0) {
      _notifications[existingByMessage] = Map<String, dynamic>.from(_notifications[existingByMessage]);
      _notifications[existingByMessage]['leida'] = false;
      notifyListeners();
      return;
    }

    _notifications.insert(0, {
      'id': 'analysis_$analysisId',
      'analysis_id': analysisId,
      'titulo': 'Análisis en proceso',
      'mensaje': title,
      'tipo': 'analysis',
      'estado': 'processing',
      'leida': false,
      'fecha': DateTime.now().toIso8601String(),
    });
    notifyListeners();
  }

  void completeAnalysis(int analysisId, String resultTitle) {
    final index = _notifications.indexWhere((n) => n['analysis_id'] == analysisId);
    if (index >= 0) {
      _notifications[index] = Map<String, dynamic>.from(_notifications[index]);
      _notifications[index]['titulo'] = 'Tu análisis está listo';
      _notifications[index]['mensaje'] = resultTitle;
      _notifications[index]['estado'] = 'completed';
      _notifications[index]['leida'] = false;
      notifyListeners();
      return;
    }

    final indexByMessage = _notifications.indexWhere(
      (n) => (n['mensaje']?.toString() ?? '').startsWith('analysis_id=$analysisId|'),
    );
    if (indexByMessage >= 0) {
      _notifications[indexByMessage] = Map<String, dynamic>.from(_notifications[indexByMessage]);
      _notifications[indexByMessage]['titulo'] = 'Tu análisis está listo';
      _notifications[indexByMessage]['mensaje'] = resultTitle;
      _notifications[indexByMessage]['estado'] = 'completed';
      _notifications[indexByMessage]['leida'] = false;
      notifyListeners();
    }
  }

  void failAnalysis(int analysisId) {
    final index = _notifications.indexWhere((n) => n['analysis_id'] == analysisId);
    if (index >= 0) {
      _notifications[index] = Map<String, dynamic>.from(_notifications[index]);
      _notifications[index]['titulo'] = 'Análisis fallido';
      _notifications[index]['mensaje'] = 'No se pudo completar el análisis. Intenta nuevamente.';
      _notifications[index]['estado'] = 'failed';
      _notifications[index]['leida'] = false;
      notifyListeners();
      return;
    }

    final indexByMessage = _notifications.indexWhere(
      (n) => (n['mensaje']?.toString() ?? '').startsWith('analysis_id=$analysisId|'),
    );
    if (indexByMessage >= 0) {
      _notifications[indexByMessage] = Map<String, dynamic>.from(_notifications[indexByMessage]);
      _notifications[indexByMessage]['titulo'] = 'Análisis fallido';
      _notifications[indexByMessage]['mensaje'] = 'No se pudo completar el análisis. Intenta nuevamente.';
      _notifications[indexByMessage]['estado'] = 'failed';
      _notifications[indexByMessage]['leida'] = false;
      notifyListeners();
    }
  }
}
