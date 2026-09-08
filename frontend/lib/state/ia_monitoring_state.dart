import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/ia_diagnostic.dart';
import '../models/ia_event.dart';
import '../models/ia_health.dart';
import '../models/ia_metrics.dart';
import '../services/ia_monitoring_service.dart';

class IaMonitoringState extends ChangeNotifier {
  final IaMonitoringService _monitoringService;

  IaMonitoringState(this._monitoringService);

  IaHealth? _health;
  IaMetrics? _metrics;
  IaDiagnostic? _diagnostics;
  final List<IaEvent> _events = [];

  bool _loadingHealth = false;
  bool _loadingMetrics = false;
  bool _loadingDiagnostics = false;
  String? _healthError;
  String? _metricsError;
  String? _diagnosticsError;

  bool _sseConnected = false;
  bool _sseReconnecting = false;
  bool _sseRunning = false;
  String? _sseError;
  Timer? _refreshTimer;
  Timer? _reconnectTimer;
  StreamSubscription<IaEvent>? _eventSubscription;
  int _reconnectAttempts = 0;
  bool _disposed = false;

  // Ciclo único de actualización (polling) con guarda de concurrencia.
  bool _refreshInProgress = false;
  bool _lastRefreshOk = true;
  DateTime? _lastUpdatedAt;

  static const Duration _refreshInterval = Duration(seconds: 15);
  static const int _maxReconnectAttempts = 5;
  static const int _maxEvents = 50;

  IaHealth? get health => _health;
  IaMetrics? get metrics => _metrics;
  IaDiagnostic? get diagnostics => _diagnostics;
  List<IaEvent> get events => List.unmodifiable(_events);
  bool get loadingHealth => _loadingHealth;
  bool get loadingMetrics => _loadingMetrics;
  bool get loadingDiagnostics => _loadingDiagnostics;
  String? get healthError => _healthError;
  String? get metricsError => _metricsError;
  String? get diagnosticsError => _diagnosticsError;
  bool get sseConnected => _sseConnected;

  /// La última carga de /ia/health fue exitosa. Si es `false`, los paneles NO
  /// deben presentar el `health` anterior (posiblemente obsoleto/cacheado)
  /// como si fuera el estado actual.
  bool get healthDisplayValid => _healthError == null;

  /// La última carga de /ia/metrics fue exitosa.
  bool get metricsDisplayValid => _metricsError == null;

  /// La última carga de /ia/diagnostics fue exitosa. En `false` no deben
  /// mostrarse los checks antiguos como si fueran el diagnóstico actual.
  bool get diagnosticsDisplayValid => _diagnosticsError == null;
  bool get sseReconnecting => _sseReconnecting;
  bool get sseDisconnected => !_sseConnected && !_sseReconnecting && _sseRunning && _sseError == null;
  String? get sseError => _sseError;
  bool get hasSseError => _sseError != null && !_sseReconnecting && !_sseConnected;

  /// Última actualización exitosa (health+metrics+diagnostics).
  DateTime? get lastUpdatedAt => _lastUpdatedAt;
  bool get refreshInProgress => _refreshInProgress;
  bool get lastRefreshOk => _lastRefreshOk;

  /// Datos considerados vivos: hubo actualización exitosa en los últimos 20 s.
  bool get isLive {
    final last = _lastUpdatedAt;
    if (last == null) return false;
    return DateTime.now().difference(last) < const Duration(seconds: 20);
  }

  /// Hay datos pero hace tiempo que no se actualizan (más de 45 s).
  bool get dataStale {
    if (_lastUpdatedAt == null) return false;
    return !DateTime.now().isBefore(_lastUpdatedAt!.add(const Duration(seconds: 45)));
  }

  /// Sin datos disponibles (aún no hubo ninguna actualización exitosa).
  bool get hasData => _health != null || _metrics != null;

  /// Whether there is an active analysis in progress.
  bool get hasActiveAnalysis => _activeAnalysis != null;
  IaEvent? get activeAnalysis => _activeAnalysis;
  IaEvent? _activeAnalysis;

  Future<void> loadHealth() async {
    if (_loadingHealth) return;
    _loadingHealth = true;
    _healthError = null;
    notifyListeners();
    try {
      _health = await _monitoringService.getHealth();
    } catch (e) {
      _healthError = e.toString();
    } finally {
      _loadingHealth = false;
      notifyListeners();
    }
  }

  Future<void> loadMetrics() async {
    if (_loadingMetrics) return;
    _loadingMetrics = true;
    _metricsError = null;
    notifyListeners();
    try {
      _metrics = await _monitoringService.getMetrics();
    } catch (e) {
      _metricsError = e.toString();
    } finally {
      _loadingMetrics = false;
      notifyListeners();
    }
  }

  Future<void> loadDiagnostics() async {
    if (_loadingDiagnostics) return;
    _loadingDiagnostics = true;
    _diagnosticsError = null;
    notifyListeners();
    try {
      _diagnostics = await _monitoringService.getDiagnostics();
    } catch (e) {
      _diagnosticsError = e.toString();
    } finally {
      _loadingDiagnostics = false;
      notifyListeners();
    }
  }

  Future<void> refreshAll() async {
    await Future.wait([
      loadHealth(),
      loadMetrics(),
      loadDiagnostics(),
    ]);
  }

  /// Ciclo único de actualización. Nunca lanza dos ciclos en paralelo y solo
  /// registra `lastUpdatedAt` cuando TODOS los servicios responden.
  Future<void> refreshData() async {
    if (_refreshInProgress || _disposed) return;
    _refreshInProgress = true;
    await refreshAll();
    _refreshInProgress = false;
    if (_disposed) return;
    final ok = _healthError == null && _metricsError == null && _diagnosticsError == null;
    _lastRefreshOk = ok;
    if (ok) {
      _lastUpdatedAt = DateTime.now();
    }
    notifyListeners();
  }

  void startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      refreshData();
    });
  }

  void stopPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void connectSse() {
    if (_eventSubscription != null && _sseRunning) return;

    _sseReconnecting = false;
    _sseError = null;
    _sseRunning = true;
    _reconnectAttempts = 0;
    notifyListeners();

    _eventSubscription = _monitoringService
        .connectEvents(
      onError: (error) {
        if (_disposed) return;
        _sseConnected = false;
        _sseError = error;
        _scheduleReconnect();
      },
      onComplete: () {
        if (_disposed) return;
        _sseConnected = false;
        _scheduleReconnect();
      },
    )
        .listen(
      (event) {
        if (_disposed) return;
        _sseConnected = true;
        _sseReconnecting = false;
        _sseError = null;
        _handleIncomingEvent(event);
      },
      onError: (e) {
        if (_disposed) return;
        _sseConnected = false;
        _sseError = e.toString();
        _scheduleReconnect();
      },
      onDone: () {
        if (_disposed) return;
        _sseConnected = false;
        _scheduleReconnect();
      },
    );
  }

  void _handleIncomingEvent(IaEvent event) {
    if (event.type == 'heartbeat') {
      return;
    }

    if (event.type == 'analysis_started') {
      _activeAnalysis = event;
    } else if (event.type == 'analysis_completed' || event.type == 'analysis_failed') {
      if (_activeAnalysis != null) {
        _activeAnalysis = null;
      }
    }

    _events.insert(0, event);
    if (_events.length > _maxEvents) {
      _events.removeLast();
    }
    notifyListeners();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _sseError = 'No se pudo reconectar después de $_maxReconnectAttempts intentos.';
      _sseReconnecting = false;
      notifyListeners();
      return;
    }

    _sseReconnecting = true;
    _sseConnected = false;
    _sseError = null;
    notifyListeners();

    _reconnectAttempts++;
    final delay = Duration(seconds: 2 * _reconnectAttempts);

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_disposed) return;
      _eventSubscription?.cancel();
      _eventSubscription = null;
      connectSse();
    });
  }

  void disconnectSse() {
    _sseRunning = false;
    _refreshTimer?.cancel();
    _reconnectTimer?.cancel();
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _sseConnected = false;
    _sseReconnecting = false;
    _monitoringService.disconnect();
    if (!_disposed) notifyListeners();
  }

  void clearSseError() {
    _sseError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    disconnectSse();
    _refreshTimer?.cancel();
    _reconnectTimer?.cancel();
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _monitoringService.dispose();
    super.dispose();
  }
}
