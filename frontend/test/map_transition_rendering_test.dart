import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/models/map_analysis_point.dart';
import 'package:frontend/models/environmental_zone.dart';
import 'package:frontend/models/developer_map_point.dart';
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

void main() {
  group('Renderizado de zonas de transición en el mapa', () {
    test(
        'Saludable + crítico a <200 m: calculateEnvironmentalZones emite una '
        'EnvironmentalZone de tipo transition con radio 100 m y centro medio',
        () {
      final healthy = MapAnalysisPoint.fromJson(
          _point(id: 1, air: 'buena', lat: 4.650000, lng: -74.100000));
      final critical = MapAnalysisPoint.fromJson(
          _point(id: 2, air: 'mala', lat: 4.650020, lng: -74.100000));

      final zones = calculateEnvironmentalZones([healthy, critical]);

      final transitions = zones
          .where((z) => z.type == EnvironmentalZoneType.transition)
          .toList();
      expect(transitions, hasLength(1));

      final t = transitions.single;
      expect(t.radius, 100.0,
          reason: 'El radio de la transición debe ser 100 m (individualRadius), '
              'no una fórmula proporcional.');
      expect(t.center.latitude, closeTo(4.650010, 0.000001));
      expect(t.center.longitude, closeTo(-74.100000, 0.000001));
      // La transición conserva los dos puntos que la originaron.
      expect(t.points.map((p) => p.id), containsAll([1, 2]));

      // toCircle() genera el overlay visual amarillo que llega al GoogleMap.
      final circle = t.toCircle();
      expect(circle.circleId.value, contains('transition'));
      expect(circle.radius, 100.0);
      expect(circle.center.latitude, closeTo(4.650010, 0.000001));
    });

    test('Zonas saludable y crítica se conservan junto a la transición', () {
      final healthy = MapAnalysisPoint.fromJson(
          _point(id: 1, air: 'buena', lat: 4.650000, lng: -74.100000));
      final critical = MapAnalysisPoint.fromJson(
          _point(id: 2, air: 'mala', lat: 4.650020, lng: -74.100000));

      final zones = calculateEnvironmentalZones([healthy, critical]);

      expect(
        zones.where((z) => z.type == EnvironmentalZoneType.healthy),
        hasLength(1),
      );
      expect(
        zones.where((z) => z.type == EnvironmentalZoneType.contaminated),
        hasLength(1),
      );
      expect(
        zones.where((z) => z.type == EnvironmentalZoneType.transition),
        hasLength(1),
      );
    });

    test('A >200 m no se genera transición', () {
      final healthy = MapAnalysisPoint.fromJson(
          _point(id: 1, air: 'buena', lat: 4.600000, lng: -74.100000));
      final critical = MapAnalysisPoint.fromJson(
          _point(id: 2, air: 'mala', lat: 4.700000, lng: -74.100000));

      final zones = calculateEnvironmentalZones([healthy, critical]);
      expect(
        zones.where((z) => z.type == EnvironmentalZoneType.transition),
        isEmpty,
      );
    });
  });

  group('Pipeline de MapScreen (calculateZones del mapa de desarrollador)', () {
    test(
        'Saludable + crítico a <200 m: calculateZones emite transición de 100 m '
        'con centro medio (misma semántica que renderiza map_screen.dart)',
        () {
      final healthy = DeveloperMapPoint(
        latitude: 4.650000,
        longitude: -74.100000,
        quality: DevMapQuality.healthy,
        airQuality: DevAirQuality.good,
        contamination: DevContamination.low,
        confidence: 0.9,
        createdAt: DateTime(2026, 9, 1),
      );
      final critical = DeveloperMapPoint(
        latitude: 4.650020,
        longitude: -74.100000,
        quality: DevMapQuality.contaminated,
        airQuality: DevAirQuality.bad,
        contamination: DevContamination.high,
        confidence: 0.9,
        createdAt: DateTime(2026, 9, 1),
      );

      final zones = calculateZones([healthy, critical]);
      final transitions =
          zones.where((z) => z.zoneType == DevMapZoneType.transition).toList();
      expect(transitions, hasLength(1));

      final t = transitions.single;
      expect(t.radius, 100.0);
      expect(t.center.latitude, closeTo(4.650010, 0.000001));
      expect(t.center.longitude, closeTo(-74.100000, 0.000001));
      expect(t.sourceA, healthy);
      expect(t.sourceB, critical);
    });

    test('Las zonas saludable y crítica originales se conservan (no se sustituyen)',
        () {
      final healthy = DeveloperMapPoint(
        latitude: 4.650000,
        longitude: -74.100000,
        quality: DevMapQuality.healthy,
        airQuality: DevAirQuality.good,
        contamination: DevContamination.low,
        confidence: 0.9,
        createdAt: DateTime(2026, 9, 1),
      );
      final critical = DeveloperMapPoint(
        latitude: 4.650020,
        longitude: -74.100000,
        quality: DevMapQuality.contaminated,
        airQuality: DevAirQuality.bad,
        contamination: DevContamination.high,
        confidence: 0.9,
        createdAt: DateTime(2026, 9, 1),
      );

      final zones = calculateZones([healthy, critical]);
      expect(
        zones.where((z) => z.zoneType == DevMapZoneType.healthy),
        hasLength(1),
      );
      expect(
        zones.where((z) => z.zoneType == DevMapZoneType.contaminated),
        hasLength(1),
      );
      expect(
        zones.where((z) => z.zoneType == DevMapZoneType.transition),
        hasLength(1),
      );
    });

    test('La transición del mapa usa el color amarillo del proyecto', () {
      // map_screen.dart y map_explorer_screen.dart colorean la transición con
      // la representación amarilla que el proyecto ya define.
      expect(
        EnvironmentalZoneType.transition.color,
        AppTheme.warningColor,
      );
    });
  });
}