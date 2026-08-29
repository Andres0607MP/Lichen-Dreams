import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/screens/history_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/state/analysis_state.dart';
import 'package:frontend/state/dashboard_state.dart';
import 'package:frontend/state/history_state.dart';
import 'package:frontend/state/map_state.dart';
import 'package:frontend/state/notifications_state.dart';

class _FakeApiService extends ApiService {
  int statsCount = 4;
  bool failDelete = false;
  int deleteCalls = 0;
  List<Map<String, dynamic>> history = [];

  @override
  Future<Map<String, dynamic>> getDashboardStats() async {
    return {'analysis_count': statsCount, 'zone_count': 2, 'air_quality': 'buena'};
  }

  @override
  Future<List<Map<String, dynamic>>> getAnalysisHistory() async => history;

  @override
  Future<void> deleteAnalysis(int analysisId) async {
    if (failDelete) {
      throw ApiException('No se pudo eliminar el análisis');
    }
    deleteCalls++;
    statsCount = 0;
    history = [];
  }

  @override
  Future<List<Map<String, dynamic>>> getMapPoints() async => [];
}

List<Map<String, dynamic>> _unaEspecie() => [
      {
        'id': 1,
        'id_analisis': 5,
        'resultado_ia': 'liquen saludable',
        'resultado': 'liquen saludable',
        'estado': 'completed',
        'fecha_creacion': '2026-08-27T10:00:00',
        'recomendacion': 'La calidad del aire es buena',
        'calidad_del_aire': 'buena',
        'ubicacion': 'Bogotá',
        'humedad': 65.0,
        'url_imagen': '',
      },
    ];

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Historial vacío refleja 0 en el Dashboard sin caché obsoleta', (tester) async {
    final api = _FakeApiService()..statsCount = 0;
    final dashboard = DashboardState(apiService: api);

    await dashboard.loadStats();
    expect(dashboard.stats?.analysisCount, 0);
  });

  testWidgets('DashboardState refresca tras invalidar (crear/borrar análisis)', (tester) async {
    final api = _FakeApiService()..statsCount = 1;
    final dashboard = DashboardState(apiService: api);

    await dashboard.loadStats();
    expect(dashboard.stats?.analysisCount, 1);
    expect(dashboard.hasFreshData, isTrue);

    // Nuevo análisis en backend: sin invalidar, la caché fresca evita el refetch
    // (aquí se producía el dato desactualizado en la vieja sincronización).
    api.statsCount = 2;
    await dashboard.loadStats();
    expect(dashboard.stats?.analysisCount, 1, reason: 'La caché fresca omite recargar');

    // Al invalidar (lo que ahora hace el flujo de borrado/creación), el siguiente
    // loadStats vuelve a consultar y refleja el valor real.
    api.statsCount = 2;
    dashboard.invalidate();
    await dashboard.loadStats();
    expect(dashboard.stats?.analysisCount, 2);

    // Borrado: 2 -> 0 tras invalidar.
    api.statsCount = 0;
    dashboard.invalidate();
    await dashboard.loadStats(force: true);
    expect(dashboard.stats?.analysisCount, 0);
  });

  testWidgets('HistoryState.deleteRecord elimina el registro en memoria', (tester) async {
    final api = _FakeApiService()..history = _unaEspecie();
    final history = HistoryState(apiService: api);
    await history.loadHistory();
    expect(history.history.length, 1);

    await history.deleteRecord(5);
    expect(api.deleteCalls, 1);
    expect(history.history, isEmpty);

    // El fallo del backend preserva los datos y no elimina localmente.
    final api2 = _FakeApiService()
      ..history = _unaEspecie()
      ..failDelete = true;
    final history2 = HistoryState(apiService: api2);
    await history2.loadHistory();
    await history2.deleteRecord(5);
    expect(history2.history.length, 1, reason: 'Con error deben conservarse los datos');
    expect(history2.error, isNotNull);
  });

  testWidgets('borrar análisis desde Historial invalida y refresca el Dashboard', (tester) async {
    final api = _FakeApiService()
      ..statsCount = 4
      ..history = _unaEspecie();
    final dashboard = DashboardState(apiService: api);
    await dashboard.loadStats();
    expect(dashboard.stats?.analysisCount, 4);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: HistoryState(apiService: api)),
          ChangeNotifierProvider.value(value: AnalysisState(apiService: api)),
          ChangeNotifierProvider.value(value: MapState(apiService: api)),
          ChangeNotifierProvider.value(value: dashboard),
          ChangeNotifierProvider.value(value: NotificationsState.instance),
          Provider<ApiService>.value(value: api),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final list = find.byType(ListView).first;
    await tester.drag(list, const Offset(0, -700));
    await tester.pump();
    await tester.drag(list, const Offset(0, -700));
    await tester.pump();

    expect(find.byIcon(Icons.delete_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(api.deleteCalls, 1);
    expect(dashboard.stats?.analysisCount, 0,
        reason: 'El Dashboard debe reflejar inmediatamente el conteo real');
    expect(dashboard.hasFreshData, isTrue,
        reason: 'Tras invalidar, el Dashboard recarga con datos frescos');
  });
}