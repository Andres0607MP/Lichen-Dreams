import 'package:flutter/foundation.dart';

/// Distribución de predicciones por clase del modelo.
@immutable
class IaPredictions {
  final int healthy;
  final int critical;
  final int unknown;

  const IaPredictions({
    required this.healthy,
    required this.critical,
    required this.unknown,
  });

  factory IaPredictions.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const IaPredictions(healthy: 0, critical: 0, unknown: 0);
    return IaPredictions(
      healthy: _parseInt(json['healthy']),
      critical: _parseInt(json['critical']),
      unknown: _parseInt(json['unknown']),
    );
  }

  int get total => healthy + critical + unknown;

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }
}

/// Muestra de la serie temporal por minuto (historial para gráficas).
@immutable
class IaMetricSample {
  final DateTime timestamp;
  final int requests;
  final int success;
  final int failed;
  final double? avgLatencyMs;
  final double? p95LatencyMs;
  final double? avgConfidence;
  final int healthy;
  final int critical;
  final int unknown;

  const IaMetricSample({
    required this.timestamp,
    required this.requests,
    required this.success,
    required this.failed,
    this.avgLatencyMs,
    this.p95LatencyMs,
    this.avgConfidence,
    required this.healthy,
    required this.critical,
    required this.unknown,
  });

  factory IaMetricSample.fromJson(Map<String, dynamic> json) {
    return IaMetricSample(
      timestamp:
          DateTime.tryParse(json['ts']?.toString() ?? '') ?? DateTime.now(),
      requests: _parseInt(json['requests']),
      success: _parseInt(json['success']),
      failed: _parseInt(json['failed']),
      avgLatencyMs: _parseDouble(json['avg_latency_ms']),
      p95LatencyMs: _parseDouble(json['p95_latency_ms']),
      avgConfidence: _parseDouble(json['avg_confidence']),
      healthy: _parseInt(json['healthy']),
      critical: _parseInt(json['critical']),
      unknown: _parseInt(json['unknown']),
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }
}

@immutable
class IaMetrics {
  final int totalInferences;
  final int successfulInferences;
  final int failedInferences;
  final int activeInferences;
  final double? averageInferenceTimeMs;
  final double? minInferenceTimeMs;
  final double? maxInferenceTimeMs;
  final double? p95LatencyMs;
  final double errorRate;
  final double? averageConfidence;
  final DateTime? lastInferenceTimestamp;
  final String? lastError;
  final DateTime? lastErrorTimestamp;
  final int requestsPerMinute;
  final double throughputPerSecond;
  final IaPredictions predictions;
  final List<IaMetricSample> series;

  const IaMetrics({
    required this.totalInferences,
    required this.successfulInferences,
    required this.failedInferences,
    required this.activeInferences,
    this.averageInferenceTimeMs,
    this.minInferenceTimeMs,
    this.maxInferenceTimeMs,
    this.p95LatencyMs,
    required this.errorRate,
    this.averageConfidence,
    this.lastInferenceTimestamp,
    this.lastError,
    this.lastErrorTimestamp,
    this.requestsPerMinute = 0,
    this.throughputPerSecond = 0.0,
    this.predictions = const IaPredictions(healthy: 0, critical: 0, unknown: 0),
    this.series = const [],
  });

  factory IaMetrics.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return IaMetrics(
      totalInferences: _parseInt(json['total_inferences']),
      successfulInferences: _parseInt(json['successful_inferences']),
      failedInferences: _parseInt(json['failed_inferences']),
      activeInferences: _parseInt(json['active_inferences']),
      averageInferenceTimeMs: _parseDouble(json['average_inference_time_ms']),
      minInferenceTimeMs: _parseDouble(json['min_inference_time_ms']),
      maxInferenceTimeMs: _parseDouble(json['max_inference_time_ms']),
      p95LatencyMs: _parseDouble(json['p95_latency_ms']),
      errorRate: _parseDouble(json['error_rate']) ?? 0.0,
      averageConfidence: _parseDouble(json['average_confidence']),
      lastInferenceTimestamp: parseDateTime(json['last_inference_timestamp']),
      lastError: json['last_error']?.toString(),
      lastErrorTimestamp: parseDateTime(json['last_error_timestamp']),
      requestsPerMinute: _parseInt(json['requests_per_minute']),
      throughputPerSecond: _parseDouble(json['throughput_per_second']) ?? 0.0,
      predictions:
          IaPredictions.fromJson((json['predictions'] as Map?) == null
              ? null
              : Map<String, dynamic>.from(json['predictions'] as Map)),
      series: _parseSeries(json['series']),
    );
  }

  static List<IaMetricSample> _parseSeries(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => IaMetricSample.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }
}
