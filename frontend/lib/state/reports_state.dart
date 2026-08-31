import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class ReportsState extends ChangeNotifier {
  final ApiService _apiService;
  ReportsState({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  List<Map<String, dynamic>> _reports = [];
  Map<String, dynamic>? _currentReport;
  bool _loading = false;
  bool _generating = false;
  String? _error;

  List<Map<String, dynamic>> get reports => List.unmodifiable(_reports);
  Map<String, dynamic>? get currentReport => _currentReport;
  bool get loading => _loading;
  bool get generating => _generating;
  String? get error => _error;

  Future<void> loadReports() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // GET /reports devuelve una lista top-level ([...]).
      final response = await _apiService.getReports();
      _reports = response
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (e) {
      _error = e.toString();
      _reports = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> getReportById(int reportId) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // GET /reports/{id} devuelve un objeto único.
      final response = await _apiService.getReport(reportId);
      _currentReport = response;
      return _currentReport;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> loadReport(int reportId) async {
    return getReportById(reportId);
  }

  Future<Map<String, dynamic>?> generateReport({required String title, String? description}) async {
    _generating = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.createEnvironmentalReport(
        title: title,
        description: description,
      );
      final report = Map<String, dynamic>.from(response);
      _reports.insert(0, report);
      _currentReport = report;
      return report;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _generating = false;
      notifyListeners();
    }
  }

  /// Elimina el reporte en el backend y actualiza la lista localmente.
  Future<bool> deleteReport(int reportId) async {
    _error = null;
    notifyListeners();
    try {
      await _apiService.deleteReport(reportId);
      _reports = _reports
          .where((r) => r['id_reporte'] != reportId)
          .toList();
      if (_currentReport?['id_reporte'] == reportId) {
        _currentReport = null;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearCurrentReport() {
    _currentReport = null;
    notifyListeners();
  }

  Future<void> reset() async {
    _reports = [];
    _currentReport = null;
    _loading = false;
    _generating = false;
    _error = null;
    notifyListeners();
  }
}
