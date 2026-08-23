import 'environmental_quality.dart';

class DashboardStats {
  final int analysisCount;
  final int zoneCount;
  final String airQuality;

  DashboardStats({
    required this.analysisCount,
    required this.zoneCount,
    required this.airQuality,
  });

  EnvironmentalQuality get environmentalQuality {
    final quality = EnvironmentalQuality.fromStrings(
      airQuality: airQuality,
    );
    print('[ANALYSIS FLOW] dashboard, quality: ${quality.label}, level: ${quality.level.name}');
    return quality;
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
    );
  }
}
