import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/models/ia_event.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/ia_monitoring_service.dart';
import 'package:frontend/state/ia_monitoring_state.dart';
import 'package:frontend/widgets/app_theme.dart';
import 'package:frontend/widgets/ia_monitor_status.dart';

class MockApiService extends ApiService {
  Map<String, dynamic>? healthResponse;
  Map<String, dynamic>? metricsResponse;
  Map<String, dynamic>? diagnosticsResponse;
  Exception? healthError;
  Exception? metricsError;
  Exception? diagnosticsError;

  MockApiService({
    this.healthResponse,
    this.metricsResponse,
    this.diagnosticsResponse,
    this.healthError,
    this.metricsError,
    this.diagnosticsError,
  });

  @override
  Future<String?> getToken() async => 'test_token';

  @override
  Future<Map<String, dynamic>> getProtectedJson(String path) async {
    if (path == '/ia/health') {
      if (healthError != null) throw healthError!;
      return healthResponse ??
          {'status': 'healthy', 'model_loaded': true, 'database_healthy': true, 'uptime_seconds': 100.0, 'reload_count': 0, 'classes': []};
    }
    if (path == '/ia/metrics') {
      if (metricsError != null) throw metricsError!;
      return metricsResponse ??
          {'total_inferences': 0, 'successful_inferences': 0, 'failed_inferences': 0, 'active_inferences': 0, 'error_rate': 0.0};
    }
    if (path == '/ia/diagnostics') {
      if (diagnosticsError != null) throw diagnosticsError!;
      return diagnosticsResponse ??
          {'status': 'healthy', 'score': 100.0, 'checks': [], 'recommended_actions': []};
    }
    throw Exception('Unknown path: $path');
  }
}

class MockIaMonitoringService extends IaMonitoringService {
  final List<IaEvent> eventsToEmit;
  final bool shouldError;
  final Completer<void> _disconnectCompleter = Completer<void>();

  MockIaMonitoringService({
    required ApiService mockApiService,
    this.eventsToEmit = const [],
    this.shouldError = false,
  }) : super(mockApiService);

  @override
  Stream<IaEvent> connectEvents({onError, onComplete}) {
    final controller = StreamController<IaEvent>.broadcast(
      onCancel: () {
        if (!_disconnectCompleter.isCompleted) {
          _disconnectCompleter.complete();
        }
      },
    );

    Future.microtask(() {
      if (shouldError) {
        if (!controller.isClosed) controller.addError('SSE error');
      } else {
        for (final event in eventsToEmit) {
          if (!controller.isClosed) controller.add(event);
        }
        if (!controller.isClosed) controller.close();
      }
    });

    return controller.stream;
  }

  @override
  void disconnect() {
    if (!_disconnectCompleter.isCompleted) {
      _disconnectCompleter.complete();
    }
  }

  Future<void> waitUntilDisconnected() => _disconnectCompleter.future;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('IaMonitoringState - Health', () {
    test('initial state has no health', () {
      final mockApi = MockApiService();
      final mockService = MockIaMonitoringService(mockApiService: mockApi);
      final state = IaMonitoringState(mockService);

      expect(state.health, isNull);
      expect(state.loadingHealth, isFalse);
    });

    test('loadHealth sets health on success', () async {
      final mockApi = MockApiService(
        healthResponse: {
          'status': 'healthy',
          'model_loaded': true,
          'uptime_seconds': 3600.0,
          'reload_count': 2,
          'classes': ['class_a'],
        },
      );
      final mockService = MockIaMonitoringService(mockApiService: mockApi);
      final state = IaMonitoringState(mockService);

      await state.loadHealth();

      expect(state.health, isNotNull);
      expect(state.health!.status, 'healthy');
      expect(state.health!.modelLoaded, isTrue);
      expect(state.health!.classes, ['class_a']);
      expect(state.loadingHealth, isFalse);
      expect(state.healthError, isNull);
    });

    test('loadHealth sets error on failure', () async {
      final mockApi = MockApiService(healthError: Exception('Connection failed'));
      final mockService = MockIaMonitoringService(mockApiService: mockApi);
      final state = IaMonitoringState(mockService);

      await state.loadHealth();

      expect(state.health, isNull);
      expect(state.healthError, isNotNull);
      expect(state.loadingHealth, isFalse);
    });
  });

  group('IaMonitoringState - Metrics', () {
    test('loadMetrics sets metrics on success', () async {
      final mockApi = MockApiService(
        metricsResponse: {
          'total_inferences': 142,
          'successful_inferences': 130,
          'failed_inferences': 12,
          'active_inferences': 1,
          'average_inference_time_ms': 280.5,
          'error_rate': 0.0845,
          'average_confidence': 0.87,
        },
      );
      final mockService = MockIaMonitoringService(mockApiService: mockApi);
      final state = IaMonitoringState(mockService);

      await state.loadMetrics();

      expect(state.metrics, isNotNull);
      expect(state.metrics!.totalInferences, 142);
      expect(state.metrics!.successfulInferences, 130);
      expect(state.metrics!.errorRate, 0.0845);
      expect(state.loadingMetrics, isFalse);
    });

    test('loadMetrics sets error on failure', () async {
      final mockApi = MockApiService(metricsError: Exception('Server error'));
      final mockService = MockIaMonitoringService(mockApiService: mockApi);
      final state = IaMonitoringState(mockService);

      await state.loadMetrics();

      expect(state.metrics, isNull);
      expect(state.metricsError, isNotNull);
    });
  });

  group('IaMonitoringState - SSE Events', () {
    test('connectSse receives events', () async {
      final mockApi = MockApiService();
      final events = [
        IaEvent.fromSse('analysis_started', '{"active_inferences": 1}'),
        IaEvent.fromSse('analysis_completed', '{"analysis_id": 1}'),
      ];
      final mockService = MockIaMonitoringService(
        mockApiService: mockApi,
        eventsToEmit: events,
      );
      final state = IaMonitoringState(mockService);

      state.connectSse();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(state.events.length, 2);
      expect(state.events[0].type, 'analysis_completed');
      expect(state.events[1].type, 'analysis_started');
    });

    test('events are prepended (newest first)', () async {
      final mockApi = MockApiService();
      final events = [
        IaEvent.fromSse('analysis_started', '{"active_inferences": 1}'),
        IaEvent.fromSse('analysis_completed', '{"analysis_id": 1}'),
        IaEvent.fromSse('analysis_failed', '{"analysis_id": 2}'),
      ];
      final mockService = MockIaMonitoringService(
        mockApiService: mockApi,
        eventsToEmit: events,
      );
      final state = IaMonitoringState(mockService);

      state.connectSse();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(state.events.first.type, 'analysis_failed');
      expect(state.events.last.type, 'analysis_started');
    });

    test('events are capped at 50', () async {
      final mockApi = MockApiService();
      final events = List.generate(
        60,
        (i) => IaEvent.fromSse('analysis_started', '{"active_inferences": 1}'),
      );
      final mockService = MockIaMonitoringService(
        mockApiService: mockApi,
        eventsToEmit: events,
      );
      final state = IaMonitoringState(mockService);

      state.connectSse();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(state.events.length, 50);
    });

    test('disconnect clears events and stops SSE', () async {
      final mockApi = MockApiService();
      final events = [
        IaEvent.fromSse('analysis_started', '{"active_inferences": 1}'),
      ];
      final mockService = MockIaMonitoringService(
        mockApiService: mockApi,
        eventsToEmit: events,
      );
      final state = IaMonitoringState(mockService);

      state.connectSse();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(state.events.length, 1);

      state.disconnectSse();
      expect(state.sseConnected, isFalse);
      expect(state.loadingHealth, isFalse);
    });

    test('dispose clears everything without errors', () async {
      final mockApi = MockApiService();
      final mockService = MockIaMonitoringService(mockApiService: mockApi);
      final state = IaMonitoringState(mockService);

      state.connectSse();
      state.startPeriodicRefresh();
      state.dispose();

      expect(state.sseConnected, isFalse);
    });

    test('heartbeat events are filtered from the visible timeline', () async {
      final mockApi = MockApiService();
      final events = [
        IaEvent.fromSse('heartbeat', '{"ts": "2024-01-15T10:30:00+00:00"}'),
        IaEvent.fromSse('analysis_started', '{"active_inferences": 1}'),
        IaEvent.fromSse('heartbeat', '{"ts": "2024-01-15T10:30:01+00:00"}'),
        IaEvent.fromSse('analysis_failed', '{"analysis_id": 1}'),
        IaEvent.fromSse('heartbeat', '{"ts": "2024-01-15T10:30:02+00:00"}'),
      ];
      final mockService = MockIaMonitoringService(
        mockApiService: mockApi,
        eventsToEmit: events,
      );
      final state = IaMonitoringState(mockService);

      state.connectSse();
      await Future.delayed(const Duration(milliseconds: 200));

      expect(state.events.length, 2);
      expect(state.events.any((e) => e.type == 'heartbeat'), isFalse);
    });

    test('active analysis tracks analysis_started then clears on completed', () async {
      final mockApi = MockApiService();
      final events = [
        IaEvent.fromSse('analysis_started', '{"active_inferences": 1}'),
        IaEvent.fromSse('analysis_completed', '{"analysis_id": 42}'),
      ];
      final mockService = MockIaMonitoringService(
        mockApiService: mockApi,
        eventsToEmit: events,
      );
      final state = IaMonitoringState(mockService);

      state.connectSse();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(state.hasActiveAnalysis, isFalse);
      expect(state.events.first.type, 'analysis_completed');
    });

    test('active analysis set when only started received', () async {
      final mockApi = MockApiService();
      final events = [
        IaEvent.fromSse('analysis_started', '{"active_inferences": 1}'),
      ];
      final mockService = MockIaMonitoringService(
        mockApiService: mockApi,
        eventsToEmit: events,
      );
      final state = IaMonitoringState(mockService);

      state.connectSse();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(state.hasActiveAnalysis, isTrue);
      expect(state.activeAnalysis?.type, 'analysis_started');
    });

    test('active analysis cleared on analysis_failed', () async {
      final mockApi = MockApiService();
      final events = [
        IaEvent.fromSse('analysis_started', '{"active_inferences": 1}'),
        IaEvent.fromSse('analysis_failed', '{"analysis_id": 99}'),
      ];
      final mockService = MockIaMonitoringService(
        mockApiService: mockApi,
        eventsToEmit: events,
      );
      final state = IaMonitoringState(mockService);

      state.connectSse();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(state.hasActiveAnalysis, isFalse);
      expect(state.events.first.type, 'analysis_failed');
    });
  });

  group('IaMonitoringState - Diagnostics y ciclo único de polling', () {
    test('loadDiagnostics sets diagnostics on success', () async {
      final mockApi = MockApiService(
        diagnosticsResponse: {
          'status': 'degraded',
          'score': 72.0,
          'checks': [
            {'id': 'model', 'status': 'warn', 'message': 'Modelo por cargar'},
          ],
          'recommended_actions': ['Revisar modelo'],
        },
      );
      final mockService = MockIaMonitoringService(mockApiService: mockApi);
      final state = IaMonitoringState(mockService);

      await state.loadDiagnostics();

      expect(state.diagnostics, isNotNull);
      expect(state.diagnostics!.status, 'degraded');
      expect(state.diagnostics!.score, 72.0);
      expect(state.diagnostics!.checks.single.isWarning, isTrue);
    });

    test('loadDiagnostics sets error on failure', () async {
      final mockApi = MockApiService(diagnosticsError: Exception('boom'));
      final mockService = MockIaMonitoringService(mockApiService: mockApi);
      final state = IaMonitoringState(mockService);

      await state.loadDiagnostics();

      expect(state.diagnostics, isNull);
      expect(state.diagnosticsError, isNotNull);
    });

    test('refreshData updates lastUpdatedAt y lastRefreshOk', () async {
      final mockApi = MockApiService();
      final mockService = MockIaMonitoringService(mockApiService: mockApi);
      final state = IaMonitoringState(mockService);

      expect(state.isLive, isFalse);
      await state.refreshData();

      expect(state.lastRefreshOk, isTrue);
      expect(state.lastUpdatedAt, isNotNull);
      expect(state.isLive, isTrue);
      expect(state.hasData, isTrue);
    });

    test('refreshData con errores no marca live y conserva offline', () async {
      final mockApi = MockApiService(
        healthError: Exception('conn'),
        metricsError: Exception('conn'),
        diagnosticsError: Exception('conn'),
      );
      final mockService = MockIaMonitoringService(mockApiService: mockApi);
      final state = IaMonitoringState(mockService);

      await state.refreshData();

      expect(state.lastRefreshOk, isFalse);
      expect(state.lastUpdatedAt, isNull);
      expect(state.hasData, isFalse);
    });

    test('refreshData no ejecuta dos ciclos en paralelo', () async {
      final mockApi = MockApiService();
      final mockService = MockIaMonitoringService(mockApiService: mockApi);
      final state = IaMonitoringState(mockService);

      final first = state.refreshData();
      final second = state.refreshData(); // debe retornar sin iniciar otro ciclo
      await Future.wait([first, second]);

      expect(state.lastUpdatedAt, isNotNull);
      expect(state.refreshInProgress, isFalse);
    });

    test('healthDisplayValid=true tras éxito y false tras fallo (sin usar caché)', () async {
      final mockApi = MockApiService();
      final mockService = MockIaMonitoringService(mockApiService: mockApi);
      final state = IaMonitoringState(mockService);

      await state.refreshData();
      expect(state.healthDisplayValid, isTrue);
      expect(state.diagnosticsDisplayValid, isTrue);
      expect(state.health, isNotNull);

      // Segundo ciclo fallido: el payload anterior NO debe mostrarse como válido.
      mockApi.healthError = Exception('sin conexión DB');
      mockApi.diagnosticsError = Exception('sin conexión DB');
      await state.refreshData();

      expect(state.lastRefreshOk, isFalse);
      expect(state.healthDisplayValid, isFalse, reason: 'No debe usarse el último estado exitoso');
      expect(state.diagnosticsDisplayValid, isFalse);
      // El valor STALE queda disponible pero marcado como no válido para mostrar.
      expect(state.health, isNotNull);
    });
  });

  group('IaMonitorStatus - resolución central de estados', () {
    test('offline cuando no hay datos', () {
      final s = IaMonitorStatus.resolve(
        live: false,
        hasData: false,
        stale: false,
      );
      expect(s.level, IaMonitorLevel.offline);
      expect(s.label, 'OFFLINE');
    });

    test('healthy cuando hay datos vivos y salud ok', () {
      final s = IaMonitorStatus.resolve(
        live: true,
        hasData: true,
        stale: false,
        healthStatus: 'healthy',
        diagnosticStatus: 'healthy',
      );
      expect(s.level, IaMonitorLevel.healthy);
      expect(s.color, AppTheme.successColor);
    });

    test('degraded/warning ante estado degradado', () {
      final s = IaMonitorStatus.resolve(
        live: true,
        hasData: true,
        stale: false,
        healthStatus: 'degraded',
        diagnosticStatus: 'degraded',
      );
      expect(s.level, IaMonitorLevel.degraded);
    });

    test('critical ante health unhealthy o diagnostic crítico', () {
      final s = IaMonitorStatus.resolve(
        live: true,
        hasData: true,
        stale: false,
        healthStatus: 'unhealthy',
        diagnosticStatus: 'unhealthy',
      );
      expect(s.level, IaMonitorLevel.critical);
    });

    test('stale data marca datos desactualizados', () {
      final s = IaMonitorStatus.resolve(
        live: false,
        hasData: true,
        stale: true,
        healthStatus: 'healthy',
      );
      expect(s.label, 'DATOS DESACTUALIZADOS');
    });
  });
}
