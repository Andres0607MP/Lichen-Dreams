import 'environmental_quality.dart';

class DashboardStats {
  final int analysisCount;
  final int zoneCount;
  final String airQuality;
  final int healthyCount;
  final int affectedCount;
  final int unknownCount;

  DashboardStats({
    required this.analysisCount,
    required this.zoneCount,
    required this.airQuality,
    this.healthyCount = 0,
    this.affectedCount = 0,
    this.unknownCount = 0,
  });

  EnvironmentalQuality get environmentalQuality {
    return EnvironmentalQuality.fromStrings(
      airQuality: airQuality,
    );
  }

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    int parseInt(Object? value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    String parseString(Object? value) {
      if (value == null) return '---';
      return value.toString();
    }

    final data = <String, dynamic>{};
    data.addAll(json);
    if (json['data'] is Map<String, dynamic>) {
      data.addAll(json['data'] as Map<String, dynamic>);
    }

    return DashboardStats(
      analysisCount: parseInt(data['analysis_count'] ?? data['analisis_count'] ?? data['total_analysis'] ?? data['total_analisis'] ?? data['count'] ?? 0),
      zoneCount: parseInt(data['zone_count'] ?? data['zonas_count'] ?? data['total_zones'] ?? data['count_zones'] ?? 0),
      airQuality: parseString(data['air_quality'] ?? data['calidad_aire'] ?? data['air_status'] ?? data['iaq'] ?? '---'),
      healthyCount: parseInt(data['healthy_count'] ?? data['saludables_count'] ?? 0),
      affectedCount: parseInt(data['affected_count'] ?? data['contaminados_count'] ?? 0),
      unknownCount: parseInt(data['unknown_count'] ?? data['desconocidos_count'] ?? 0),
    );
  }
}
