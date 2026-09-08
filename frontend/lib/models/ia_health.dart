import 'package:flutter/foundation.dart';

@immutable
class IaHealth {
  final String status;
  final String? statusDetail;
  final bool modelLoaded;
  final String? modelName;
  final String? modelVersion;
  final String? modelPath;
  final List<String> classes;
  final String? tensorflowVersion;
  final String? kerasVersion;
  final String? device;
  final DateTime? modelLoadedAt;
  final double? modelUptimeSeconds;
  final int reloadCount;
  final double uptimeSeconds;
  final bool? databaseHealthy;
  final DateTime? timestamp;

  const IaHealth({
    required this.status,
    this.statusDetail,
    required this.modelLoaded,
    this.modelName,
    this.modelVersion,
    this.modelPath,
    this.classes = const [],
    this.tensorflowVersion,
    this.kerasVersion,
    this.device,
    this.modelLoadedAt,
    this.modelUptimeSeconds,
    required this.reloadCount,
    required this.uptimeSeconds,
    this.databaseHealthy,
    this.timestamp,
  });

  factory IaHealth.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    List<String> parseClasses(dynamic value) {
      if (value == null) return const [];
      if (value is List) return value.map((e) => e.toString()).toList();
      return const [];
    }

    return IaHealth(
      status: json['status']?.toString() ?? 'unhealthy',
      statusDetail: json['status_detail']?.toString(),
      modelLoaded: json['model_loaded'] as bool? ?? false,
      modelName: json['model_name']?.toString(),
      modelVersion: json['model_version']?.toString(),
      modelPath: json['model_path']?.toString(),
      classes: parseClasses(json['classes']),
      tensorflowVersion: json['tensorflow_version']?.toString(),
      kerasVersion: json['keras_version']?.toString(),
      device: json['device']?.toString(),
      modelLoadedAt: parseDateTime(json['model_loaded_at']),
      modelUptimeSeconds: _parseDouble(json['model_uptime_seconds']),
      reloadCount: _parseInt(json['reload_count']),
      uptimeSeconds: _parseDouble(json['uptime_seconds']) ?? 0.0,
      databaseHealthy: json['database_healthy'] as bool?,
      timestamp: parseDateTime(json['timestamp']),
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
