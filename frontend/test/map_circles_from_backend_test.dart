import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/map_analysis_point.dart';

void main() {
  group('MapAnalysisPoint circle desde backend', () {
    test('circle para punto con air_quality moderada', () {
      final json = {
        'id': 10,
        'lat': 4.711,
        'lng': -74.072,
        'zone_name': 'Test, Bogota',
        'air_quality': 'moderada',
        'contamination_level': 'baja',
        'species': 'Lichen',
        'confidence': 0.93,
        'date': '2026-08-06T00:00:00',
        'status': 'shared',
        'visibilidad': 'shared',
      };

      final point = MapAnalysisPoint.fromJson(json);
      final circle = point.toCircle();

      expect(circle.circleId.value, 'analysis_10_circle');
      expect(circle.center.latitude, 4.711);
      expect(circle.center.longitude, -74.072);
      expect(circle.radius, 5.0);
      expect(circle.fillColor.alpha, lessThan(255));
      expect(circle.strokeColor.alpha, lessThan(255));
    });

    test('circle para punto con air_quality buena', () {
      final json = {
        'id': 11,
        'lat': 4.712,
        'lng': -74.073,
        'zone_name': 'Zona saludable',
        'air_quality': 'saludable',
        'contamination_level': 'baja',
        'species': 'Lichen',
        'confidence': 0.95,
        'date': '2026-08-06T00:00:00',
        'status': 'shared',
        'visibilidad': 'shared',
      };

      final point = MapAnalysisPoint.fromJson(json);
      final circle = point.toCircle();

      expect(circle.circleId.value, 'analysis_11_circle');
      expect(circle.radius, 5.0);
    });

    test('circle para punto con air_quality deficiente', () {
      final json = {
        'id': 12,
        'lat': 4.713,
        'lng': -74.074,
        'zone_name': 'Zona contaminada',
        'air_quality': 'deficiente',
        'contamination_level': 'alta',
        'species': 'Lichen',
        'confidence': 0.85,
        'date': '2026-08-06T00:00:00',
        'status': 'shared',
        'visibilidad': 'shared',
      };

      final point = MapAnalysisPoint.fromJson(json);
      final circle = point.toCircle();

      expect(circle.circleId.value, 'analysis_12_circle');
      expect(circle.radius, 5.0);
    });
  });
}
