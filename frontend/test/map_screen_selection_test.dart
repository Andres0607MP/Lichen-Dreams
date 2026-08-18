import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/map_analysis_point.dart';

void main() {
  group('MapScreen card selection', () {
    test('onCardTap expande grupo y tarjeta', () {
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

      final expandedGroups = <AirQualityLevel, bool>{};
      final selectedPoint = ValueNotifier<MapAnalysisPoint?>(null);
      final expandedAnalysisId = ValueNotifier<int?>(null);

      expandedGroups[point.qualityLevel] = false;
      selectedPoint.value = null;
      expandedAnalysisId.value = null;

      final onCardTap = (MapAnalysisPoint p) {
        expandedGroups[p.qualityLevel] = true;
        selectedPoint.value = p;
        expandedAnalysisId.value = p.id;
      };

      onCardTap(point);

      expect(expandedGroups[point.qualityLevel], isTrue);
      expect(selectedPoint.value?.id, equals(point.id));
      expect(expandedAnalysisId.value, equals(point.id));
    });

    test('onCardTap no se ejecuta con coordenadas invalidas', () {
      final point = MapAnalysisPoint(
        id: 2,
        lat: double.nan,
        lng: double.infinity,
        zoneName: 'Test inválido',
        airQuality: 'saludable',
        contaminationLevel: 'baja',
        species: 'Lichen',
        confidence: 0.9,
        date: DateTime.now(),
        status: 'completed',
        visibilidad: 'private',
      );

      expect(point.lat.isFinite, isFalse);
      expect(point.lng.isFinite, isFalse);
    });
  });
}
