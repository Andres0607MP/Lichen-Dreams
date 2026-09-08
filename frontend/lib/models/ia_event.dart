import 'dart:convert';

class IaEvent {
  final String type;
  final DateTime? timestamp;
  final int? analysisId;
  final int? activeInferences;
  final double? processingTimeMs;
  final double? confidence;
  final String? category;
  final String? errorType;
  final String? modelPath;
  final int? reloadCount;
  final String? modelVersion;
  final String? ts;

  IaEvent({
    required this.type,
    this.timestamp,
    this.analysisId,
    this.activeInferences,
    this.processingTimeMs,
    this.confidence,
    this.category,
    this.errorType,
    this.modelPath,
    this.reloadCount,
    this.modelVersion,
    this.ts,
  });

  factory IaEvent.fromSse(String rawEvent, String rawData) {
    final type = rawEvent.isEmpty ? 'message' : rawEvent;
    DateTime? parsedTs;
    String? tsString;
    Map<String, dynamic> data = {};

    try {
      final decoded = jsonDecode(rawData);
      if (decoded is Map<String, dynamic>) {
        data = decoded;
      }
    } catch (_) {
      data = {};
    }

    final tsValue = data['timestamp'] ?? data['ts'];
    if (tsValue is String && tsValue.isNotEmpty) {
      tsString = tsValue;
      parsedTs = DateTime.tryParse(tsValue);
    }

    return IaEvent(
      type: type,
      timestamp: parsedTs,
      analysisId: _parseInt(data['analysis_id']),
      activeInferences: _parseInt(data['active_inferences']),
      processingTimeMs: _parseDouble(data['processing_time_ms']),
      confidence: _parseDouble(data['confidence']),
      category: data['category']?.toString(),
      errorType: data['error_type']?.toString(),
      modelPath: data['model_path']?.toString(),
      reloadCount: _parseInt(data['reload_count']),
      modelVersion: data['model_version']?.toString(),
      ts: tsString,
    );
  }

  Map<String, String> get display {
    switch (type) {
      case 'analysis_started':
        return {'title': 'Análisis iniciado', 'icon': '🔵'};
      case 'analysis_completed':
        return {'title': 'Análisis completado', 'icon': '✅'};
      case 'analysis_failed':
        return {'title': 'Análisis fallido', 'icon': '❌'};
      case 'model_loaded':
        return {'title': 'Modelo cargado', 'icon': '📦'};
      case 'model_reloaded':
        return {'title': 'Modelo actualizado', 'icon': '🔄'};
      case 'heartbeat':
        return {'title': 'Latido', 'icon': '💓'};
      default:
        return {'title': type, 'icon': '📨'};
    }
  }

  String get displayTitle => display['title']!;
  String get displayIcon => display['icon']!;

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
