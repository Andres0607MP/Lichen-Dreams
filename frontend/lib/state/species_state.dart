import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class SpeciesState extends ChangeNotifier {
  final ApiService _apiService;
  SpeciesState({ApiService? apiService}) : _apiService = apiService ?? ApiService();
  List<Map<String, dynamic>> _species = [];
  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> get species => List.unmodifiable(_species);
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadSpecies() async {
    setState(() => _loading = true);
    _error = null;
    try {
      final history = await _apiService.getAnalysisHistory();
      final speciesList = <Map<String, dynamic>>[];
      for (final analysis in history) {
        final id = analysis['id'] is int
            ? analysis['id'] as int
            : int.tryParse(analysis['id']?.toString() ?? '');
        if (id != null) {
          try {
            final species = await _apiService.getSpecies(id);
            final rawSpecies = species['data'] is List
                ? List<Map<String, dynamic>>.from(species['data'])
                : [species];
            speciesList.addAll(rawSpecies);
          } catch (_) {
            continue;
          }
        }
      }
      _species = speciesList;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      setState(() => _loading = false);
    }
  }

  void setState(bool Function() fn) {
    final changed = fn();
    if (changed) notifyListeners();
  }
}
