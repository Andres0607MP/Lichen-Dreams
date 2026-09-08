import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/ia_event.dart';

void main() {
  group('IaEvent.fromSse', () {
    test('parses analysis_started event', () {
      final data = jsonEncode({
        'active_inferences': 2,
        'timestamp': '2024-01-15T10:30:00+00:00',
      });

      final event = IaEvent.fromSse('analysis_started', data);

      expect(event.type, 'analysis_started');
      expect(event.activeInferences, 2);
      expect(event.analysisId, isNull);
      expect(event.timestamp, isNotNull);
      expect(event.displayTitle, 'Análisis iniciado');
    });

    test('parses analysis_completed event', () {
      final data = jsonEncode({
        'analysis_id': 145,
        'active_inferences': 1,
        'processing_time_ms': 284.0,
        'confidence': 0.92,
        'category': 'healthy',
        'timestamp': '2024-01-15T10:30:00+00:00',
      });

      final event = IaEvent.fromSse('analysis_completed', data);

      expect(event.type, 'analysis_completed');
      expect(event.analysisId, 145);
      expect(event.activeInferences, 1);
      expect(event.processingTimeMs, 284.0);
      expect(event.confidence, 0.92);
      expect(event.category, 'healthy');
      expect(event.displayTitle, 'Análisis completado');
    });

    test('parses analysis_failed event', () {
      final data = jsonEncode({
        'analysis_id': 146,
        'active_inferences': 0,
        'processing_time_ms': 150.0,
        'error_type': 'FileNotFoundError',
        'timestamp': '2024-01-15T10:30:00+00:00',
      });

      final event = IaEvent.fromSse('analysis_failed', data);

      expect(event.type, 'analysis_failed');
      expect(event.analysisId, 146);
      expect(event.errorType, 'FileNotFoundError');
      expect(event.displayTitle, 'Análisis fallido');
    });

    test('parses model_loaded event', () {
      final data = jsonEncode({
        'model_path': '/models/lichen_v8.h5',
        'model_version': 'v8',
        'timestamp': '2024-01-15T10:30:00+00:00',
      });

      final event = IaEvent.fromSse('model_loaded', data);

      expect(event.type, 'model_loaded');
      expect(event.modelPath, '/models/lichen_v8.h5');
      expect(event.modelVersion, 'v8');
      expect(event.displayTitle, 'Modelo cargado');
    });

    test('parses model_reloaded event', () {
      final data = jsonEncode({
        'model_path': '/models/lichen_v8.h5',
        'reload_count': 5,
        'timestamp': '2024-01-15T10:30:00+00:00',
      });

      final event = IaEvent.fromSse('model_reloaded', data);

      expect(event.type, 'model_reloaded');
      expect(event.reloadCount, 5);
      expect(event.displayTitle, 'Modelo actualizado');
    });

    test('parses heartbeat event', () {
      final data = jsonEncode({'ts': '2024-01-15T10:30:00+00:00'});

      final event = IaEvent.fromSse('heartbeat', data);

      expect(event.type, 'heartbeat');
      expect(event.displayTitle, 'Latido');
    });

    test('handles missing timestamp gracefully', () {
      final data = jsonEncode({'analysis_id': 1});

      final event = IaEvent.fromSse('analysis_started', data);

      expect(event.timestamp, isNull);
      expect(event.analysisId, 1);
    });

    test('handles unknown event type', () {
      final data = jsonEncode({});
      final event = IaEvent.fromSse('unknown_type', data);
      expect(event.type, 'unknown_type');
      expect(event.displayTitle, 'unknown_type');
    });
  });
}
