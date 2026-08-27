import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class CatalogState extends ChangeNotifier {
  final ApiService _apiService;

  CatalogState({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  List<Map<String, dynamic>> _species = [];
  List<Map<String, dynamic>> _zones = [];
  bool _loadingSpecies = false;
  bool _loadingZones = false;
  String? _speciesError;
  String? _zonesError;

  List<Map<String, dynamic>> get species => List.unmodifiable(_species);
  List<Map<String, dynamic>> get zones => List.unmodifiable(_zones);
  bool get loadingSpecies => _loadingSpecies;
  bool get loadingZones => _loadingZones;
  String? get speciesError => _speciesError;
  String? get zonesError => _zonesError;

  Future<void> loadSpecies() async {
    _loadingSpecies = true;
    _speciesError = null;
    notifyListeners();

    try {
      final data = await _apiService.getAdminSpecies();
      _species = data.cast<Map<String, dynamic>>();
    } catch (e) {
      _speciesError = e.toString();
    } finally {
      _loadingSpecies = false;
      notifyListeners();
    }
  }

  Future<void> loadZones() async {
    _loadingZones = true;
    _zonesError = null;
    notifyListeners();

    try {
      final data = await _apiService.getZones();
      _zones = data.cast<Map<String, dynamic>>();
    } catch (e) {
      _zonesError = e.toString();
    } finally {
      _loadingZones = false;
      notifyListeners();
    }
  }

  Future<void> createSpecies(Map<String, dynamic> data) async {
    await _apiService.createAdminSpecies(data);
    await loadSpecies();
  }

  Future<void> updateSpecies(int id, Map<String, dynamic> data) async {
    await _apiService.updateAdminSpecies(id, data);
    await loadSpecies();
  }

  Future<void> deleteSpecies(int id) async {
    await _apiService.deleteAdminSpecies(id);
    await loadSpecies();
  }

  Future<void> createZone(Map<String, dynamic> data) async {
    await _apiService.createZone(data);
    await loadZones();
  }

  Future<void> updateZone(int id, Map<String, dynamic> data) async {
    await _apiService.updateZone(id, data);
    await loadZones();
  }

  Future<void> deleteZone(int id) async {
    await _apiService.deleteZone(id);
    await loadZones();
  }

  void clearErrors() {
    _speciesError = null;
    _zonesError = null;
  }
}
