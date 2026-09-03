import '../models/analysis_record.dart';
import '../models/dashboard_stats.dart';
import '../models/environmental_quality.dart';

class DailyAnalysisStat {
  final DateTime date;
  final int count;

  DailyAnalysisStat({required this.date, required this.count});
}

class EnvironmentalDistribution {
  final int healthy;
  final int moderate;
  final int critical;
  final int unknown;

  EnvironmentalDistribution({
    required this.healthy,
    required this.moderate,
    required this.critical,
    required this.unknown,
  });

  int get total => healthy + moderate + critical + unknown;
  bool get hasData => total > 0;
}

class DashboardStatsDetail {
  final List<DailyAnalysisStat> dailyActivity;
  final EnvironmentalDistribution environmentalDistribution;
  final int zoneCount;
  final int ubicacionesCount;
  final int zonasAmbientalesCount;
  final double? averageHumidity;
  final double? averageConfidence;
  final DateTime? lastAnalysisDate;
  final int totalAnalyses;

  DashboardStatsDetail({
    required this.dailyActivity,
    required this.environmentalDistribution,
    required this.zoneCount,
    this.ubicacionesCount = 0,
    this.zonasAmbientalesCount = 0,
    this.averageHumidity,
    this.averageConfidence,
    this.lastAnalysisDate,
    required this.totalAnalyses,
  });

  factory DashboardStatsDetail.fromHistory({
    required List<AnalysisRecord> history,
    required DashboardStats? stats,
  }) {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    final recentHistory = history
        .where((r) => r.createdAt != null && r.createdAt!.isAfter(sevenDaysAgo))
        .toList();

    final dailyActivity = _calculateDailyActivity(recentHistory);
    final environmentalDistribution = _calculateEnvironmentalDistribution(history);
    final averageHumidity = _calculateAverageHumidity(history);
    final averageConfidence = _calculateAverageConfidence(history);
    final lastAnalysisDate = _getLastAnalysisDate(history);

    return DashboardStatsDetail(
      dailyActivity: dailyActivity,
      environmentalDistribution: environmentalDistribution,
      zoneCount: stats?.ubicacionesCount ?? 0,
      ubicacionesCount: stats?.ubicacionesCount ?? 0,
      zonasAmbientalesCount: stats?.zonasAmbientalesCount ?? 0,
      averageHumidity: averageHumidity,
      averageConfidence: averageConfidence,
      lastAnalysisDate: lastAnalysisDate,
      totalAnalyses: history.length,
    );
  }

  static List<DailyAnalysisStat> _calculateDailyActivity(List<AnalysisRecord> history) {
    final Map<String, int> counts = {};

    for (final record in history) {
      if (record.createdAt == null) continue;
      final dateKey = '${record.createdAt!.year}-${record.createdAt!.month.toString().padLeft(2, '0')}-${record.createdAt!.day.toString().padLeft(2, '0')}';
      counts[dateKey] = (counts[dateKey] ?? 0) + 1;
    }

    final sortedEntries = counts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return sortedEntries.map((entry) {
      final parts = entry.key.split('-');
      return DailyAnalysisStat(
        date: DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
        count: entry.value,
      );
    }).toList();
  }

  static EnvironmentalDistribution _calculateEnvironmentalDistribution(List<AnalysisRecord> history) {
    int healthy = 0;
    int moderate = 0;
    int critical = 0;
    int unknown = 0;

    for (final record in history) {
      final quality = record.environmentalQuality;
      switch (quality.level) {
        case EnvironmentalQualityLevel.excellent:
        case EnvironmentalQualityLevel.good:
          healthy++;
          break;
        case EnvironmentalQualityLevel.moderate:
          moderate++;
          break;
        case EnvironmentalQualityLevel.poor:
        case EnvironmentalQualityLevel.critical:
          critical++;
          break;
        case EnvironmentalQualityLevel.unknown:
          unknown++;
          break;
      }
    }

    return EnvironmentalDistribution(
      healthy: healthy,
      moderate: moderate,
      critical: critical,
      unknown: unknown,
    );
  }

  static double? _calculateAverageHumidity(List<AnalysisRecord> history) {
    final humidities = history
        .where((r) => r.humedad != null)
        .map((r) => r.humedad!)
        .toList();

    if (humidities.isEmpty) return null;

    final sum = humidities.reduce((a, b) => a + b);
    return sum / humidities.length;
  }

  static double? _calculateAverageConfidence(List<AnalysisRecord> history) {
    final confidences = <double>[];

    for (final record in history) {
      final confidence = record.raw['confianza'] ??
          record.raw['confidence'] ??
          record.raw['confianza_ia'];
      if (confidence is num) {
        confidences.add(confidence.toDouble());
      } else if (confidence is String) {
        final parsed = double.tryParse(confidence);
        if (parsed != null) confidences.add(parsed);
      }
    }

    if (confidences.isEmpty) return null;

    final sum = confidences.reduce((a, b) => a + b);
    return sum / confidences.length;
  }

  static DateTime? _getLastAnalysisDate(List<AnalysisRecord> history) {
    final dates = history
        .where((r) => r.createdAt != null)
        .map((r) => r.createdAt!)
        .toList();

    if (dates.isEmpty) return null;

    dates.sort((a, b) => b.compareTo(a));
    return dates.first;
  }
}
