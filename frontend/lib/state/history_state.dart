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
  int _version = 0;

  List<AnalysisRecord> get history => List.unmodifiable(_history);
  bool get loading => _loading;
  String? get error => _error;
  bool get hasData => _history.isNotEmpty;
  bool get hasLoaded => _loaded;
  bool get hasFreshData => _lastLoadedAt != null && DateTime.now().difference(_lastLoadedAt!) < _cacheDuration;
  int get version => _version;

  void invalidate() {
    _loaded = false;
    _lastLoadedAt = null;
  }

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
        _history = items.map((json) => AnalysisRecord.fromJson(json)).toList();
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

  Future<void> deleteRecord(int? analysisId) async {
    if (analysisId == null || analysisId <= 0) return;
    try {
      await _apiService.deleteAnalysis(analysisId);
      _notify(() {
        _history.removeWhere((r) => r.analysisId == analysisId);
      });
    } catch (e) {
      _notify(() => _error = e.toString());
    }
  }

  void _notify(void Function() fn) {
    fn();
    _version++;
    notifyListeners();
  }
}
