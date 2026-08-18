import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/analysis_record.dart';

class HistoryState extends ChangeNotifier {
  final ApiService _apiService;
  HistoryState({ApiService? apiService}) : _apiService = apiService ?? ApiService();
  List<AnalysisRecord> _history = [];
  bool _loading = false;
  String? _error;
  bool _loaded = false;
  DateTime? _lastLoadedAt;
  static const Duration _cacheDuration = Duration(seconds: 30);
  final Set<int> _sharedAnalysisIds = {};

  List<AnalysisRecord> get history => List.unmodifiable(_history);
  bool get loading => _loading;
  String? get error => _error;
  bool get hasData => _history.isNotEmpty;
  bool get hasLoaded => _loaded;
  bool get hasFreshData => _lastLoadedAt != null && DateTime.now().difference(_lastLoadedAt!) < _cacheDuration;

  Future<void> loadHistory({bool force = false}) async {
    if (_loading) return;
    if (!force && hasFreshData) return;
    _notify(() {
      _loading = true;
      _error = null;
      _history = [];
    });
    try {
      final items = await _apiService.getAnalysisHistory();
      _notify(() {
        _history = items.map((json) {
          final record = AnalysisRecord.fromJson(json);
          if (_sharedAnalysisIds.contains(record.id)) {
            final updatedRaw = Map<String, dynamic>.from(record.raw);
            updatedRaw['visibilidad'] = 'shared';
            return AnalysisRecord(
              id: record.id,
              title: record.title,
              status: record.status,
              summary: record.summary,
              imageUrl: record.imageUrl,
              imageBase64: record.imageBase64,
              createdAt: record.createdAt,
              ubicacion: record.ubicacion,
              humedad: record.humedad,
              calidadDelAire: record.calidadDelAire,
              source: record.source,
              raw: updatedRaw,
            );
          }
          return record;
        }).toList();
        _loaded = true;
        _lastLoadedAt = DateTime.now();
      });
    } catch (e) {
      _notify(() {
        _error = e.toString();
        _history = [];
      });
    } finally {
      _notify(() => _loading = false);
    }
  }

  Future<void> refresh() async {
    _notify(() {
      _loaded = false;
      _error = null;
      _lastLoadedAt = null;
    });
    await loadHistory(force: true);
  }

  Future<void> reset() {
    _notify(() {
      _history = [];
      _error = null;
      _loading = false;
      _loaded = false;
      _lastLoadedAt = null;
    });
    return Future.value();
  }

  Future<void> deleteRecord(int? id) async {
    if (id == null || id <= 0) return;
    try {
      await _apiService.deleteHistory(id);
      await loadHistory();
    } catch (e) {
      _notify(() => _error = e.toString());
    }
  }

  void markAnalysisAsShared(int analysisId) {
    _sharedAnalysisIds.add(analysisId);
    final index = _history.indexWhere((r) => r.id == analysisId);
    if (index < 0) return;
    final old = _history[index];
    final updatedRaw = Map<String, dynamic>.from(old.raw);
    updatedRaw['visibilidad'] = 'shared';
    _history[index] = AnalysisRecord(
      id: old.id,
      title: old.title,
      status: old.status,
      summary: old.summary,
      imageUrl: old.imageUrl,
      imageBase64: old.imageBase64,
      createdAt: old.createdAt,
      ubicacion: old.ubicacion,
      humedad: old.humedad,
      calidadDelAire: old.calidadDelAire,
      source: old.source,
      raw: updatedRaw,
    );
    notifyListeners();
  }

  bool isShared(int? analysisId) {
    if (analysisId == null || analysisId <= 0) return false;
    if (_sharedAnalysisIds.contains(analysisId)) return true;
    final index = _history.indexWhere((r) => r.id == analysisId);
    if (index >= 0) return _history[index].isShared;
    return false;
  }

  void _notify(void Function() fn) {
    fn();
    notifyListeners();
  }
}
