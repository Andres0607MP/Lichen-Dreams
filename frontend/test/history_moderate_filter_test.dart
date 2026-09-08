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
import 'package:frontend/models/environmental_zone.dart';
import 'package:frontend/models/derived_transition_record.dart';
import 'package:frontend/models/map_analysis_point.dart';
import 'package:frontend/widgets/app_theme.dart';

/// ApiService simulado: solo devuelve historial, puntos del mapa y stats.
class _FakeApiService extends ApiService {
  List<Map<String, dynamic>> history = [];
  List<Map<String, dynamic>> points = [];

  @override
  Future<Map<String, dynamic>> getDashboardStats() async => {};

  @override
  Future<List<Map<String, dynamic>>> getAnalysisHistory() async => history;

  @override
  Future<List<Map<String, dynamic>>> getMapPoints() async => points;

  @override
  Future<void> deleteAnalysis(int analysisId) async {}
}

Map<String, dynamic> _record({
  required int id,
  required int analysisId,
  required String resultado,
}) {
  return {
    'id': id,
    'id_analisis': analysisId,
    'resultado_ia': resultado,
    'resultado': resultado,
    'estado': 'completed',
    'fecha_creacion': '2026-09-01T10:00:00',
    'recomendacion': 'Análisis de referencia',
    'calidad_del_aire': resultado == 'liquen saludable' ? 'buena' : 'mala',
    'url_imagen': '',
  };
}

Map<String, dynamic> _point({
  required int id,
  required String air,
  required double lat,
  required double lng,
}) {
  return {
    'id': id,
    'lat': lat,
    'lng': lng,
    'zone_name': 'Zona de prueba',
    'air_quality': air,
    'species': 'Liquen',
    'confidence': 0.9,
    'date': '2026-09-01T10:00:00',
    'status': 'completed',
    'visibilidad': 'private',
    'id_usuario': 1,
    'analysis_count': 1,
  };
}

Map<String, dynamic> _healthyPoint(int id, double lat, double lng) =>
    _point(id: id, air: 'buena', lat: lat, lng: lng);
Map<String, dynamic> _criticalPoint(int id, double lat, double lng) =>
    _point(id: id, air: 'mala', lat: lat, lng: lng);

Future<void> _pumpHistory(
  WidgetTester tester, {
  required List<Map<String, dynamic>> history,
  required List<Map<String, dynamic>> points,
}) async {
  final api = _FakeApiService()..history = history..points = points;
  final mapState = MapState(apiService: api);
  await mapState.loadPoints();

  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: HistoryState(apiService: api)),
        ChangeNotifierProvider.value(value: AnalysisState(apiService: api)),
        ChangeNotifierProvider.value(value: mapState),
        ChangeNotifierProvider.value(value: DashboardState(apiService: api)),
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
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _tapFilter(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

// Título exacto de la representación derivada de la transición.
const _derivedTitle = 'Transición / Moderado';

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  group('Filtro Moderados en HistoryScreen (representación derivada)', () {
    testWidgets(
        '1 saludable + 1 crítico a <200 m: aparece UNA transición amarilla derivada',
        (tester) async {
      final history = [
        _record(id: 1, analysisId: 1, resultado: 'liquen saludable'),
        _record(id: 2, analysisId: 2, resultado: 'liquen contaminado'),
      ];
      final points = [
        _healthyPoint(1, 4.650000, -74.100000),
        _criticalPoint(2, 4.650020, -74.100000),
      ];
      await _pumpHistory(tester, history: history, points: points);

      expect(find.text('Moderados (1)'), findsOneWidget);

      await _tapFilter(tester, 'Moderados (1)');

      // La representación derivada aparece como elemento amarillo propio.
      expect(find.text(_derivedTitle), findsOneWidget);
      // Los análisis originales saludable/crítico no se convierten en moderados.
      expect(find.text('liquen saludable'), findsNothing);
      expect(find.text('liquen contaminado'), findsNothing);
    });

    testWidgets('Sin intersecciones: Moderados muestran 0 y estado vacío',
        (tester) async {
      final history = [
        _record(id: 1, analysisId: 1, resultado: 'liquen saludable'),
        _record(id: 2, analysisId: 2, resultado: 'liquen contaminado'),
      ];
      final points = [
        _healthyPoint(1, 4.600000, -74.100000),
        _criticalPoint(2, 4.700000, -74.100000),
      ];
      await _pumpHistory(tester, history: history, points: points);

      expect(find.text('Moderados (0)'), findsOneWidget);

      await _tapFilter(tester, 'Moderados (0)');

      expect(find.text('No hay análisis con este filtro'), findsOneWidget);
      expect(find.text(_derivedTitle), findsNothing);
    });

    testWidgets(
        '2 saludables + 1 crítico: contador 2 y aparecen 2 transiciones derivadas',
        (tester) async {
      final history = [
        _record(id: 11, analysisId: 11, resultado: 'liquen saludable'),
        _record(id: 12, analysisId: 12, resultado: 'liquen saludable'),
        _record(id: 21, analysisId: 21, resultado: 'liquen contaminado'),
      ];
      final points = [
        _healthyPoint(11, 4.650000, -74.100000),
        _healthyPoint(12, 4.650002, -74.100000),
        _criticalPoint(21, 4.650004, -74.100000),
      ];
      await _pumpHistory(tester, history: history, points: points);

      expect(find.text('Moderados (2)'), findsOneWidget);

      await _tapFilter(tester, 'Moderados (2)');

      expect(find.text(_derivedTitle), findsNWidgets(2));
    });

    testWidgets(
        'Transiciones que comparten un análisis: NO duplican los originales',
        (tester) async {
      // El saludable 2 está en 2 transiciones (2 y 3, y 2 y 4);
      // el saludable 1 queda fuera (> 200 m).
      final history = [
        _record(id: 1, analysisId: 1, resultado: 'liquen saludable'),
        _record(id: 2, analysisId: 2, resultado: 'liquen saludable'),
        _record(id: 3, analysisId: 3, resultado: 'liquen contaminado'),
        _record(id: 4, analysisId: 4, resultado: 'liquen contaminado'),
      ];
      final points = [
        _healthyPoint(1, 4.850000, -74.100000),
        _healthyPoint(2, 4.650000, -74.100000),
        _criticalPoint(3, 4.650002, -74.100000),
        _criticalPoint(4, 4.650004, -74.100000),
      ];
      await _pumpHistory(tester, history: history, points: points);

      expect(find.text('Moderados (2)'), findsOneWidget);

      // 2 transiciones derivadas, una por intersección.
      await _tapFilter(tester, 'Moderados (2)');
      expect(find.text(_derivedTitle), findsNWidgets(2));

      // Con 'Todos', los 4 análisis originales aparecen UNA sola vez cada uno.
      await _tapFilter(tester, 'Todos (4)');
      expect(find.text('liquen saludable'), findsNWidgets(2));
      expect(find.text('liquen contaminado'), findsNWidgets(2));
    });

    testWidgets(
        'Análisis fuera de cualquier transición no aparece en Moderados pero sí en Saludables',
        (tester) async {
      final history = [
        _record(id: 1, analysisId: 1, resultado: 'liquen saludable'),
        _record(id: 2, analysisId: 2, resultado: 'liquen saludable'),
        _record(id: 3, analysisId: 3, resultado: 'liquen contaminado'),
      ];
      final points = [
        _healthyPoint(1, 4.850000, -74.100000), // fuera (>200 m)
        _healthyPoint(2, 4.650000, -74.100000),
        _criticalPoint(3, 4.650004, -74.100000),
      ];
      await _pumpHistory(tester, history: history, points: points);

      await _tapFilter(tester, 'Moderados (1)');
      expect(find.text(_derivedTitle), findsOneWidget);
      expect(find.text('liquen saludable'), findsNothing);

      // El saludable lejano sigue disponible en su filtro.
      await _tapFilter(tester, 'Todos (3)');
      await _tapFilter(tester, 'Saludables (2)');
      expect(find.text('liquen saludable'), findsNWidgets(2));
    });

    testWidgets('Los filtros Saludables y Críticos siguen funcionando',
        (tester) async {
      final history = [
        _record(id: 1, analysisId: 1, resultado: 'liquen saludable'),
        _record(id: 2, analysisId: 2, resultado: 'liquen contaminado'),
      ];
      final points = [
        _healthyPoint(1, 4.600000, -74.100000),
        _criticalPoint(2, 4.700000, -74.100000),
      ];
      await _pumpHistory(tester, history: history, points: points);

      expect(find.text('Saludables (1)'), findsOneWidget);
      expect(find.text('Críticos (1)'), findsOneWidget);

      await _tapFilter(tester, 'Saludables (1)');
      expect(find.text('liquen saludable'), findsOneWidget);
      expect(find.text('liquen contaminado'), findsNothing);
      expect(find.text(_derivedTitle), findsNothing);

      await _tapFilter(tester, 'Todos (2)');
      await _tapFilter(tester, 'Críticos (1)');
      expect(find.text('liquen contaminado'), findsOneWidget);
      expect(find.text('liquen saludable'), findsNothing);
    });
  });

  group('Representación derivada de la transición (modelo + color)', () {
    test(
        'buildTransitionRecords genera un registro derivado amarillo correcto',
        () {
      final healthy = MapAnalysisPoint.fromJson(
          _healthyPoint(1, 4.650000, -74.100000));
      final critical = MapAnalysisPoint.fromJson(
          _criticalPoint(2, 4.650020, -74.100000));

      final zones = calculateEnvironmentalZones([healthy, critical]);
      final derived = buildTransitionRecords(zones);

      expect(derived, hasLength(1));
      final record = derived.single;
      expect(record.isDerivedTransition, isTrue);
      expect(record.analysisId, isNull,
          reason: 'No debe existir un análisis persistido de la transición');
      expect(record.raw['_participant_ids'], [1, 2]);
      // Resuelve al nivel moderado (base amarilla del proyecto).
      expect(record.environmentalQuality.level.name, 'moderate');
    });

    test('La transición usa el color amarillo del proyecto (AppTheme.warningColor)',
        () {
      expect(EnvironmentalZoneType.transition.color, AppTheme.warningColor);
    });
  });
}