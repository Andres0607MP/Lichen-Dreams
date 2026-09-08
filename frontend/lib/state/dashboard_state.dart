import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/dashboard_stats.dart';
import '../models/map_analysis_point.dart';
import '../models/environmental_zone.dart';

class DashboardState extends ChangeNotifier {
  final ApiService _apiService;
  DashboardState({ApiService? apiService}) : _apiService = apiService ?? ApiService();
  DashboardStats? _stats;
  bool _loading = false;
  bool _loadStatsInProgress = false;
  DateTime? _lastLoadedAt;
  static const Duration _cacheDuration = Duration(seconds: 30);

  DashboardStats? get stats => _stats;
  bool get loading => _loading;
  bool get hasFreshData => _lastLoadedAt != null && DateTime.now().difference(_lastLoadedAt!) < _cacheDuration;

  void invalidate() {
    _lastLoadedAt = null;
  }

  void calculateModerateCount(List<MapAnalysisPoint> points) {
    final zones = calculateEnvironmentalZones(points);
    final moderateCount = zones.where((z) => z.type == EnvironmentalZoneType.transition).length;
    if (_stats != null) {
      _stats = DashboardStats(
        analysisCount: _stats!.analysisCount,
        zoneCount: _stats!.zoneCount,
        ubicacionesCount: _stats!.ubicacionesCount,
        zonasAmbientalesCount: _stats!.zonasAmbientalesCount,
        airQuality: _stats!.airQuality,
        healthyCount: _stats!.healthyCount,
        affectedCount: _stats!.affectedCount,
        unknownCount: _stats!.unknownCount,
        moderateCount: moderateCount,
      );
      notifyListeners();
    }
  }

  Future<void> loadStats({bool force = false}) async {
    if (_loading || _loadStatsInProgress) return;
    if (!force && hasFreshData) return;
    _loadStatsInProgress = true;
    _loading = true;
    notifyListeners();
    try {
      final json = await _apiService.getDashboardStats().timeout(const Duration(seconds: 5));
      _stats = DashboardStats.fromJson(json);
      _lastLoadedAt = DateTime.now();
    } on TimeoutException {
      _stats = null;
    } catch (e) {
      _stats = null;
    } finally {
      _loading = false;
      _loadStatsInProgress = false;
      notifyListeners();
    }
  }

  Future<void> reset() {
    _stats = null;
    _loading = false;
    _lastLoadedAt = null;
    notifyListeners();
    return Future.value();
  }
}
