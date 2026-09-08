import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/models/environmental_zone.dart';
import 'package:frontend/models/map_analysis_point.dart';
import 'package:frontend/models/map_quality_filter.dart';
import 'package:frontend/screens/map_explorer_screen.dart';
import 'package:frontend/widgets/app_theme.dart';

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
    'zone_name': 'Zona',
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

Map<String, dynamic> _healthy(int id, double lat, double lng) =>
    _point(id: id, air: 'buena', lat: lat, lng: lng);
Map<String, dynamic> _critical(int id, double lat, double lng) =>
    _point(id: id, air: 'mala', lat: lat, lng: lng);

void main() {
  group('applyQualityFilter (filtro de calidad del mapa)', () {
    test('Sin filtro (null) devuelve todos los puntos y zonas', () {
      final points = [
        MapAnalysisPoint.fromJson(_healthy(1, 4.650000, -74.100000)),
        MapAnalysisPoint.fromJson(_critical(2, 4.650020, -74.100000)),
      ];
      final zones = calculateEnvironmentalZones(points);

      final result = applyQualityFilter(points, zones, null);
      expect(result.points, hasLength(2));
      expect(result.zones.length, zones.length);
    });

    test('Saludable: solo puntos saludables y zonas healthy (sin transiciones)',
        () {
      final unhealthyFar =
          MapAnalysisPoint.fromJson(_critical(3, 4.850000, -74.100000));
      final points = [
        MapAnalysisPoint.fromJson(_healthy(1, 4.650000, -74.100000)),
        MapAnalysisPoint.fromJson(_critical(2, 4.650020, -74.100000)),
        unhealthyFar,
      ];
      final zones = calculateEnvironmentalZones(points);
      // La intersección existe y la transición se identificó sobre el conjunto
      // completo ANTES de filtrar (requisito #10).
      expect(
        zones.where((z) => z.type == EnvironmentalZoneType.transition),
        hasLength(1),
      );

      final result = applyQualityFilter(points, zones, AirQualityLevel.good);

      expect(result.points.map((p) => p.id), [1]);
      expect(result.zones.every((z) => z.type == EnvironmentalZoneType.healthy),
          isTrue);
      // Un filtro exclusivamente saludable NO muestra la transición derivada.
      expect(
        result.zones.where((z) => z.type == EnvironmentalZoneType.transition),
        isEmpty,
      );
    });

    test('Moderado: solo zonas de transición derivadas (sin marcadores)', () {
      final points = [
        MapAnalysisPoint.fromJson(_healthy(1, 4.650000, -74.100000)),
        MapAnalysisPoint.fromJson(_critical(2, 4.650020, -74.100000)),
      ];
      final zones = calculateEnvironmentalZones(points);

      final result =
          applyQualityFilter(points, zones, AirQualityLevel.moderate);

      expect(result.points, isEmpty, reason: 'La transición es derivada');
      expect(result.zones, hasLength(1));
      expect(result.zones.single.type, EnvironmentalZoneType.transition);
      expect(result.zones.single.radius, 100.0);
    });

    test('Contaminado: solo puntos críticos y zonas contaminated', () {
      final points = [
        MapAnalysisPoint.fromJson(_healthy(1, 4.650000, -74.100000)),
        MapAnalysisPoint.fromJson(_critical(2, 4.650020, -74.100000)),
      ];
      final zones = calculateEnvironmentalZones(points);

      final result = applyQualityFilter(points, zones, AirQualityLevel.poor);

      expect(result.points.map((p) => p.id), [2]);
      expect(
        result.zones.every(
            (z) => z.type == EnvironmentalZoneType.contaminated),
        isTrue,
      );
      expect(
        result.zones.where((z) => z.type == EnvironmentalZoneType.transition),
        isEmpty,
      );
    });

    test('Tocar nuevamente el filtro activo devuelve todos (null)', () {
      final points = [
        MapAnalysisPoint.fromJson(_healthy(1, 4.650000, -74.100000)),
        MapAnalysisPoint.fromJson(_critical(2, 4.650020, -74.100000)),
      ];
      final zones = calculateEnvironmentalZones(points);

      final filtered = applyQualityFilter(points, zones, AirQualityLevel.good);
      final all = applyQualityFilter(points, zones, null);

      expect(filtered.points, hasLength(1));
      expect(all.points, hasLength(2));
      expect(all.zones.length, zones.length);
    });

    test('Las transiciones no dependen del orden del filtrado (#10)', () {
      // Incluso filtrando solo puntos saludables primero, el cálculo de zonas
      // usa el conjunto completo: la transición sigue identificable.
      final points = [
        MapAnalysisPoint.fromJson(_healthy(1, 4.650000, -74.100000)),
        MapAnalysisPoint.fromJson(_critical(2, 4.650020, -74.100000)),
      ];
      final onlyHealthy = points
          .where((p) => p.visualQualityLevel == AirQualityLevel.good)
          .toList();
      final zonesFull = calculateEnvironmentalZones(points);

      // Con solo saludables, calculateEnvironmentalZones no produce transición,
      // por lo que el renderizado deriva las zonas del conjunto COMPLETO.
      expect(calculateEnvironmentalZones(onlyHealthy).where(
          (z) => z.type == EnvironmentalZoneType.transition), isEmpty);
      final moderate = applyQualityFilter(points, zonesFull, AirQualityLevel.moderate);
      expect(moderate.zones.where(
          (z) => z.type == EnvironmentalZoneType.transition), hasLength(1));
    });
  });

  group('MapQualityFilterBar (botones de la leyenda interactiva)', () {
    testWidgets('Inicialmente los tres filtros están inactivos (gris)', (tester) async {
      final levels = <AirQualityLevel?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapQualityFilterBar(
              selected: null,
              onChanged: (v) => levels.add(v),
            ),
          ),
        ),
      );

      for (final label in ['Saludable', 'Moderado', 'Contaminado']) {
        final text = tester.widget<Text>(find.text(label));
        expect(text.style?.color, const Color(0xFF9E9E9E));
      }
      expect(levels, isEmpty);
    });

    testWidgets('Tocar Saludable activa verde y es el único activo (selección simple)',
        (tester) async {
      AirQualityLevel? current;
      Widget build(AirQualityLevel? sel) => MaterialApp(
            home: Scaffold(
              body: MapQualityFilterBar(
                selected: sel,
                onChanged: (v) => current = v,
              ),
            ),
          );

      await tester.pumpWidget(build(null));
      await tester.tap(find.text('Saludable'));
      await tester.pump();
      expect(current, AirQualityLevel.good);

      await tester.pumpWidget(build(AirQualityLevel.good));
      final saludable = tester.widget<Text>(find.text('Saludable'));
      expect(saludable.style?.color, AppTheme.successColor);

      // Tocar Contaminado reemplaza la selección (un solo activo a la vez).
      await tester.tap(find.text('Contaminado'));
      await tester.pump();
      expect(current, AirQualityLevel.poor);
    });

    testWidgets('Tocar el activo de nuevo lo desactiva (vuelve a null)',
        (tester) async {
      AirQualityLevel? current = AirQualityLevel.moderate;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapQualityFilterBar(
              selected: current,
              onChanged: (v) => current = v,
            ),
          ),
        ),
      );

      final moderado = tester.widget<Text>(find.text('Moderado'));
      expect(moderado.style?.color, const Color(0xFFFFC107));

      await tester.tap(find.text('Moderado'));
      await tester.pump();
      expect(current, isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapQualityFilterBar(
              selected: current,
              onChanged: (v) => current = v,
            ),
          ),
        ),
      );
      expect(tester.widget<Text>(find.text('Moderado')).style?.color,
          const Color(0xFF9E9E9E));
    });

    testWidgets('Colores de activación: verde, amarillo y rojo', (tester) async {
      Future<void> check(AirQualityLevel level, String label, Color color) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MapQualityFilterBar(
                selected: level,
                onChanged: (_) {},
              ),
            ),
          ),
        );
        expect(tester.widget<Text>(find.text(label)).style?.color, color);
      }

      await check(AirQualityLevel.good, 'Saludable', AppTheme.successColor);
      await check(
          AirQualityLevel.moderate, 'Moderado', const Color(0xFFFFC107));
      await check(AirQualityLevel.poor, 'Contaminado', AppTheme.errorColor);
    });
  });
}