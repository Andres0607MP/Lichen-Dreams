import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/map_analysis_point.dart';

void main() {
  group('MapAnalysisPoint circle', () {
    test('genera CircleId unico por analisis', () {
      final point = MapAnalysisPoint(
        id: 10,
        lat: 4.711,
        lng: -74.072,
        zoneName: 'Test',
        airQuality: 'moderada',
        contaminationLevel: 'baja',
        species: 'Lichen',
        confidence: 0.9,
        date: DateTime.now(),
        status: 'shared',
        visibilidad: 'shared',
      );

      final circle = point.toCircle();
      expect(circle.circleId.value, 'analysis_10_circle');
    });

    test('usa radio configurable de 5 metros', () {
      final point = MapAnalysisPoint(
        id: 10,
        lat: 4.711,
        lng: -74.072,
        zoneName: 'Test',
        airQuality: 'moderada',
        contaminationLevel: 'baja',
        species: 'Lichen',
        confidence: 0.9,
        date: DateTime.now(),
        status: 'shared',
        visibilidad: 'shared',
      );

      final circle = point.toCircle();
      expect(circle.radius, 5.0);
    });

    test('genera color verde para licen saludable', () {
      final point = MapAnalysisPoint(
        id: 1,
        lat: 4.711,
        lng: -74.072,
        zoneName: 'Test',
        airQuality: 'saludable',
        contaminationLevel: 'baja',
        species: 'Lichen',
        confidence: 0.9,
        date: DateTime.now(),
        status: 'completed',
        visibilidad: 'private',
      );

      final circle = point.toCircle();
      expect(circle.fillColor.alpha, lessThan(255));
      expect(circle.strokeColor.alpha, lessThan(255));
    });

    test('genera color amarillo para estado intermedio', () {
      final point = MapAnalysisPoint(
        id: 2,
        lat: 4.711,
        lng: -74.072,
        zoneName: 'Test',
        airQuality: 'moderada',
        contaminationLevel: 'media',
        species: 'Lichen',
        confidence: 0.9,
        date: DateTime.now(),
        status: 'completed',
        visibilidad: 'private',
      );

      final circle = point.toCircle();
      expect(circle.fillColor.alpha, lessThan(255));
      expect(circle.strokeColor.alpha, lessThan(255));
    });

    test('genera color rojo para licen contaminado', () {
      final point = MapAnalysisPoint(
        id: 3,
        lat: 4.711,
        lng: -74.072,
        zoneName: 'Test',
        airQuality: 'deficiente',
        contaminationLevel: 'alta',
        species: 'Lichen',
        confidence: 0.9,
        date: DateTime.now(),
        status: 'completed',
        visibilidad: 'private',
      );

      final circle = point.toCircle();
      expect(circle.fillColor.alpha, lessThan(255));
      expect(circle.strokeColor.alpha, lessThan(255));
    });

    test('permite superposicion de multiples circulos', () {
      final points = [
        MapAnalysisPoint(
          id: 1,
          lat: 4.711,
          lng: -74.072,
          zoneName: 'Test 1',
          airQuality: 'saludable',
          contaminationLevel: 'baja',
          species: 'Lichen',
          confidence: 0.9,
          date: DateTime.now(),
          status: 'completed',
          visibilidad: 'private',
        ),
        MapAnalysisPoint(
          id: 2,
          lat: 4.711,
          lng: -74.072,
          zoneName: 'Test 2',
          airQuality: 'deficiente',
          contaminationLevel: 'alta',
          species: 'Lichen',
          confidence: 0.9,
          date: DateTime.now(),
          status: 'completed',
          visibilidad: 'private',
        ),
      ];

      final circles = points.map((p) => p.toCircle()).toSet();
      expect(circles.length, 2);
    });
  });
}
