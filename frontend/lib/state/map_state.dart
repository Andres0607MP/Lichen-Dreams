import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/api_service.dart';
import '../models/map_analysis_point.dart';

class MapState extends ChangeNotifier {
  final ApiService _apiService;
  int? _userId;
  MapState({ApiService? apiService, int? userId}) : _apiService = apiService ?? ApiService() {
    _userId = userId;
  }
  List<MapAnalysisPoint> _points = [];
  List<MapAnalysisPoint> _ownPoints = [];
  List<MapAnalysisPoint> _communityPoints = [];
  bool _loading = false;
  String? _error;

  int? get userId => _userId;
  List<MapAnalysisPoint> get points => _points;
  List<MapAnalysisPoint> get ownPoints => _ownPoints;
  List<MapAnalysisPoint> get communityPoints => _communityPoints;
  bool get loading => _loading;
  String? get error => _error;

  Set<Circle> _cachedCircles = const {};
  Set<Circle> get circles => _cachedCircles;

  void updateUserId(int? userId) {
    if (_userId == userId) return;
    _userId = userId;
    if (_points.isNotEmpty) {
      _ownPoints = _points.where((point) => point.idUsuario == _userId).toList();
      _communityPoints = _points.where((point) => point.idUsuario != _userId && point.visibilidad == 'shared').toList();
    } else {
      _ownPoints = [];
      _communityPoints = [];
    }
    notifyListeners();
  }

  Future<void> loadPoints() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      debugPrint('MAP STATE: cargando puntos del mapa...');
      final jsonList = await _apiService.getMapPoints();
      debugPrint('MAP STATE: recibidos ${jsonList.length} puntos');
      _points = jsonList.map((json) => MapAnalysisPoint.fromJson(json)).toList();
      _ownPoints = _points.where((point) => point.idUsuario == _userId).toList();
      _communityPoints = _points.where((point) => point.idUsuario != _userId && point.visibilidad == 'shared').toList();
      _cachedCircles = _points
          .where((point) => point.qualityLevel != AirQualityLevel.moderate)
          .map((point) => point.toEnvironmentalCircle())
          .toSet();
      debugPrint('MAP STATE: mis análisis=${_ownPoints.length}, comunidad=${_communityPoints.length}');
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _loading = false;
    }
  }

  List<MapAnalysisPoint> filteredPoints({required bool showOwn, required bool showCommunity}) {
    final result = <MapAnalysisPoint>[];
    if (showOwn) result.addAll(_ownPoints);
    if (showCommunity) result.addAll(_communityPoints);
    return result;
  }

  Set<Circle> filteredCircles({required bool showZones, required bool showOwn, required bool showCommunity}) {
    final points = filteredPoints(showOwn: showOwn, showCommunity: showCommunity);
    final envPoints = showZones ? _points : <MapAnalysisPoint>[];
    final allPoints = {...points, ...envPoints};
    return allPoints
        .where((point) => point.qualityLevel != AirQualityLevel.moderate)
        .map((point) => point.toEnvironmentalCircle())
        .toSet();
  }

  List<MapAnalysisPoint> applyAdvancedFilters(
    List<MapAnalysisPoint> points, {
    Set<AirQualityLevel>? qualityLevels,
    Set<ContaminationLevel>? contaminationLevels,
    Set<ConfidenceLevel>? confidenceLevels,
    DateRange? dateRange,
  }) {
    return points.where((point) {
      if (qualityLevels != null && qualityLevels.isNotEmpty && !qualityLevels.contains(point.qualityLevel)) {
        return false;
      }
      if (contaminationLevels != null && contaminationLevels.isNotEmpty && !contaminationLevels.contains(point.contaminationLevelCategory)) {
        return false;
      }
      if (confidenceLevels != null && confidenceLevels.isNotEmpty && !confidenceLevels.contains(point.confidenceLevel)) {
        return false;
      }
      if (dateRange != null && dateRange != DateRange.all && !point.isInDateRange(dateRange)) {
        return false;
      }
      return true;
    }).toList();
  }

  void setState(bool Function() fn) {
    final changed = fn();
    if (changed) notifyListeners();
  }

  Future<void> reset() {
    _points = [];
    _cachedCircles = const {};
    _error = null;
    _loading = false;
    notifyListeners();
    return Future.value();
  }
}
