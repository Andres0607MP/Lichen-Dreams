import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/ia_metrics.dart';

void main() {
  group('IaMetrics.fromJson', () {
    test('parses all fields correctly', () {
      final json = {
        'total_inferences': 142,
        'successful_inferences': 130,
        'failed_inferences': 12,
        'active_inferences': 1,
        'average_inference_time_ms': 280.5,
        'min_inference_time_ms': 45.0,
        'max_inference_time_ms': 1200.0,
        'error_rate': 0.0845,
        'average_confidence': 0.87,
        'last_inference_timestamp': '2024-01-15T10:30:00+00:00',
        'last_error': 'TimeoutError',
        'last_error_timestamp': '2024-01-15T10:15:00+00:00',
      };

      final metrics = IaMetrics.fromJson(json);

      expect(metrics.totalInferences, 142);
      expect(metrics.successfulInferences, 130);
      expect(metrics.failedInferences, 12);
      expect(metrics.activeInferences, 1);
      expect(metrics.averageInferenceTimeMs, 280.5);
      expect(metrics.minInferenceTimeMs, 45.0);
      expect(metrics.maxInferenceTimeMs, 1200.0);
      expect(metrics.errorRate, 0.0845);
      expect(metrics.averageConfidence, 0.87);
      expect(metrics.lastInferenceTimestamp, isNotNull);
      expect(metrics.lastError, 'TimeoutError');
      expect(metrics.lastErrorTimestamp, isNotNull);
    });

    test('handles null and missing fields', () {
      final json = {
        'total_inferences': 0,
        'successful_inferences': 0,
        'failed_inferences': 0,
        'active_inferences': 0,
        'error_rate': 0.0,
      };

      final metrics = IaMetrics.fromJson(json);

      expect(metrics.totalInferences, 0);
      expect(metrics.averageInferenceTimeMs, isNull);
      expect(metrics.minInferenceTimeMs, isNull);
      expect(metrics.maxInferenceTimeMs, isNull);
      expect(metrics.averageConfidence, isNull);
      expect(metrics.lastInferenceTimestamp, isNull);
      expect(metrics.lastError, isNull);
      expect(metrics.errorRate, 0.0);
    });

    test('handles empty json', () {
      final metrics = IaMetrics.fromJson({});
      expect(metrics.totalInferences, 0);
      expect(metrics.successfulInferences, 0);
      expect(metrics.failedInferences, 0);
      expect(metrics.activeInferences, 0);
      expect(metrics.errorRate, 0.0);
    });
  });
}
