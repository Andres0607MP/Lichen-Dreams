import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/models/ia_event.dart';
import 'package:frontend/screens/ia_monitoring_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/ia_monitoring_service.dart';
import 'package:frontend/state/auth_state.dart';
import 'package:frontend/state/ia_monitoring_state.dart';

class _AdminAuth extends AuthState {
  @override
  bool get isAdmin => true;
}

class _FakeApi extends ApiService {
  @override
  Future<String?> getToken() async => 't';

  @override
  Future<Map<String, dynamic>> getProtectedJson(String path) async {
    switch (path) {
      case '/ia/health':
        return {
          'status': 'healthy',
          'status_detail': 'Modelo cargado y operativo',
          'model_loaded': true,
          'model_name': 'Lichen Classifier',
          'model_version': 'v8',
          'classes': ['liquen saludable', 'liquen contaminado', 'liquen desconocido'],
          'device': 'CPU',
          'reload_count': 0,
          'database_healthy': true,
          'uptime_seconds': 100.0,
        };
      case '/ia/metrics':
        return {
          'total_inferences': 142,
          'successful_inferences': 130,
          'failed_inferences': 12,
          'active_inferences': 1,
          'average_inference_time_ms': 243.0,
          'p95_latency_ms': 421.0,
          'error_rate': 0.0845,
          'average_confidence': 0.87,
          'requests_per_minute': 12,
          'throughput_per_second': 1.8,
          'predictions': {'healthy': 82, 'critical': 13, 'unknown': 5},
          'series': [
            {
              'ts': '2026-09-07T10:00:00Z',
              'requests': 2,
              'success': 2,
              'failed': 0,
              'avg_latency_ms': 200.0,
              'p95_latency_ms': 300.0,
              'avg_confidence': 0.9,
              'healthy': 2,
              'critical': 0,
              'unknown': 0,
            },
            {
              'ts': '2026-09-07T10:01:00Z',
              'requests': 3,
              'success': 3,
              'failed': 0,
              'avg_latency_ms': 250.0,
              'p95_latency_ms': 400.0,
              'avg_confidence': 0.88,
              'healthy': 2,
              'critical': 1,
              'unknown': 0,
            },
          ],
        };
      case '/ia/diagnostics':
        return {
          'status': 'healthy',
          'score': 98.7,
          'checks': [
            {'id': 'api', 'status': 'ok', 'message': 'API respondiendo correctamente'},
            {'id': 'model', 'status': 'ok', 'message': 'Modelo cargado y operativo'},
            {'id': 'database', 'status': 'ok', 'message': 'Conexión a la base de datos saludable'},
            {'id': 'latency', 'status': 'ok', 'message': 'Latencia de inferencia normal'},
          ],
          'recommended_actions': ['No se requieren acciones correctivas.'],
        };
      default:
        throw Exception('unknown $path');
    }
  }
}

class _FakeMonitoringService extends IaMonitoringService {
  _FakeMonitoringService() : super(_FakeApi());

  @override
  Stream<IaEvent> connectEvents({onError, onComplete}) {
    return const Stream.empty();
  }
}

class _OfflineApi extends ApiService {
  @override
  Future<String?> getToken() async => 't';

  @override
  Future<Map<String, dynamic>> getProtectedJson(String path) async {
    throw Exception('backend sin conexión');
  }
}

class _OfflineMonitoringService extends IaMonitoringService {
  _OfflineMonitoringService() : super(_OfflineApi());

  @override
  Stream<IaEvent> connectEvents({onError, onComplete}) {
    return const Stream.empty();
  }
}

/// API que responde bien la primera vez y luego falla en /ia/health y
/// /ia/diagnostics (simula la caída de MySQL después de un estado saludable).
class _FlakyApi extends _FakeApi {
  int healthCalls = 0;
  int diagCalls = 0;

  @override
  Future<Map<String, dynamic>> getProtectedJson(String path) async {
    if (path == '/ia/health') {
      healthCalls++;
      // Falla a partir del 3er call: el refresh inicial de la pantalla (2º
      // call) sigue OK para poder verificar el estado saludable primero.
      if (healthCalls > 2) throw Exception('MySQL caída');
    }
    if (path == '/ia/diagnostics') {
      diagCalls++;
      if (diagCalls > 2) throw Exception('MySQL caída');
    }
    return super.getProtectedJson(path);
  }
}

class _FlakyMonitoringService extends IaMonitoringService {
  _FlakyMonitoringService() : super(_FlakyApi());

  @override
  Stream<IaEvent> connectEvents({onError, onComplete}) {
    return const Stream.empty();
  }
}

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final state = IaMonitoringState(_FakeMonitoringService());
  await state.refreshData();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthState>.value(value: _AdminAuth()),
        ChangeNotifierProvider<IaMonitoringState>.value(value: state),
      ],
      child: const MaterialApp(home: IaMonitoringScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('IaMonitoringScreen - layout responsive (sin overflow)', () {
    for (final size in [
      const Size(320, 640),
      const Size(360, 800),
      const Size(390, 844),
      const Size(768, 1024),
      const Size(1200, 1400),
    ]) {
      testWidgets('$size no produce overflow y muestra el control center',
          (tester) async {
        await _pump(tester, size);

        // DEBUG: excepciones sin consumir
        expect(tester.takeException(), isNull);
        expect(find.text('IA MONITORING'), findsOneWidget);
        expect(find.text('SYSTEM HEALTH'), findsOneWidget);
        expect(find.text('PERFORMANCE'), findsOneWidget);
        expect(find.text('MODEL ANALYTICS'), findsOneWidget);
        expect(find.text('LIVE EVENTS'), findsOneWidget);
        expect(find.text('IA DIAGNOSTIC'), findsOneWidget);
        expect(find.text('SERVICE HEALTH'), findsOneWidget);
        await _unmount(tester);
      });
    }
  });

  testWidgets('Estado offline se muestra cuando no hay datos', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Servicio realmente offline: refreshData carga el estado OFFLINE estable.
    final state = IaMonitoringState(_OfflineMonitoringService());
    await state.refreshData();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthState>.value(value: _AdminAuth()),
          ChangeNotifierProvider<IaMonitoringState>.value(value: state),
        ],
        child: const MaterialApp(home: IaMonitoringScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('OFFLINE'), findsWidgets);
    await _unmount(tester);
  });

  testWidgets('Las secciones colapsan y se expanden', (tester) async {
    await _pump(tester, const Size(360, 800));

    expect(find.text('ANÁLISIS / MINUTO'), findsOneWidget);

    await tester.ensureVisible(find.text('PERFORMANCE'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('PERFORMANCE'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('ANÁLISIS / MINUTO'), findsNothing);

    await tester.tap(find.text('PERFORMANCE'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('ANÁLISIS / MINUTO'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('Las métricas muestran datos reales del backend', (tester) async {
    await _pump(tester, const Size(360, 800));

    expect(find.text('142'), findsOneWidget); // Análisis
    expect(find.text('12'), findsWidgets); // req/min o errores
    expect(find.text('421 ms'), findsOneWidget); // P95
    expect(find.text('87.0%'), findsOneWidget); // Confianza
    await _unmount(tester);
  });

  testWidgets('Service Health / Diagnostic no quedan HEALTHY falsos si cae la BD',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = IaMonitoringState(_FlakyMonitoringService());
    await state.refreshData(); // 1er ciclo OK (BD operativa)

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthState>.value(value: _AdminAuth()),
          ChangeNotifierProvider<IaMonitoringState>.value(value: state),
        ],
        child: const MaterialApp(home: IaMonitoringScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.text('saludable'), findsWidgets); // DB HEALTHY inicial

    // 2º ciclo: MySQL caída simulada en /ia/health y /ia/diagnostics.
    await state.refreshData();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    // La fila de DB ya NO debe decir "saludable" (ni ningún HEALTHY falso).
    expect(find.text('saludable'), findsNothing,
        reason: 'No debe quedar un HEALTHY falso con la BD caída');
    expect(find.text('sin conexión'), findsWidgets); // fila API y DB
    expect(find.textContaining('Diagnóstico no disponible'), findsWidgets);
    await _unmount(tester);
  });
}