import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/ia_health.dart';

void main() {
  group('IaHealth.fromJson', () {
    test('parses healthy status with all fields', () {
      final json = {
        'status': 'healthy',
        'status_detail': 'Modelo cargado y operativo.',
        'model_loaded': true,
        'model_name': 'Lichen Classifier',
        'model_version': 'v8',
        'model_path': '/models/lichen_v8.h5',
        'classes': ['clase_a', 'clase_b'],
        'tensorflow_version': '2.15.0',
        'keras_version': '2.15.0',
        'device': 'CPU',
        'model_loaded_at': '2024-01-15T10:30:00+00:00',
        'model_uptime_seconds': 3600.5,
        'reload_count': 3,
        'uptime_seconds': 7200.0,
        'timestamp': '2024-01-15T11:30:00+00:00',
      };

      final health = IaHealth.fromJson(json);

      expect(health.status, 'healthy');
      expect(health.modelLoaded, isTrue);
      expect(health.modelName, 'Lichen Classifier');
      expect(health.modelVersion, 'v8');
      expect(health.classes, ['clase_a', 'clase_b']);
      expect(health.tensorflowVersion, '2.15.0');
      expect(health.device, 'CPU');
      expect(health.reloadCount, 3);
      expect(health.uptimeSeconds, 7200.0);
      expect(health.modelUptimeSeconds, 3600.5);
      expect(health.modelLoadedAt, isNotNull);
    });

    test('handles null and missing fields gracefully', () {
      final json = {
        'status': 'degraded',
        'model_loaded': false,
        'classes': null,
        'reload_count': null,
        'uptime_seconds': null,
      };

      final health = IaHealth.fromJson(json);

      expect(health.status, 'degraded');
      expect(health.modelLoaded, isFalse);
      expect(health.classes, isEmpty);
      expect(health.reloadCount, 0);
      expect(health.uptimeSeconds, 0.0);
      expect(health.modelName, isNull);
      expect(health.tensorflowVersion, isNull);
    });

    test('defaults to unhealthy when status is missing', () {
      final json = <String, dynamic>{};
      final health = IaHealth.fromJson(json);
      expect(health.status, 'unhealthy');
      expect(health.modelLoaded, isFalse);
    });
  });
}
