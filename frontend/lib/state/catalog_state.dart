import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class CatalogState extends ChangeNotifier {
  final ApiService _apiService;

  CatalogState({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  List<Map<String, dynamic>> _species = [];
  List<Map<String, dynamic>> _zones = [];
  bool _loadingSpecies = false;
  bool _loadingZones = false;
  bool _mutationPending = false;
  String? _speciesError;
  String? _zonesError;

  List<Map<String, dynamic>> get species => List.unmodifiable(_species);
  List<Map<String, dynamic>> get zones => List.unmodifiable(_zones);
  bool get loadingSpecies => _loadingSpecies;
  bool get loadingZones => _loadingZones;
  bool get mutationPending => _mutationPending;
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
    if (_mutationPending) return;
    _mutationPending = true;
    notifyListeners();
    try {
      final created = await _apiService.createAdminSpecies(data);
      _upsertSpecies(created);
      await _refreshSpeciesQuietly();
    } catch (e) {
      rethrow;
    } finally {
      _mutationPending = false;
      notifyListeners();
    }
  }

  Future<void> updateSpecies(int id, Map<String, dynamic> data) async {
    if (_mutationPending) return;
    _mutationPending = true;
    notifyListeners();
    try {
      final updated = await _apiService.updateAdminSpecies(id, data);
      _upsertSpecies(updated);
      await _refreshSpeciesQuietly();
    } catch (e) {
      rethrow;
    } finally {
      _mutationPending = false;
      notifyListeners();
    }
  }

  Future<void> deleteSpecies(int id) async {
    if (_mutationPending) return;
    _mutationPending = true;
    notifyListeners();
    try {
      await _apiService.deleteAdminSpecies(id);
      _species.removeWhere((s) => s['id_especie'] == id);
      await _refreshSpeciesQuietly();
    } catch (e) {
      rethrow;
    } finally {
      _mutationPending = false;
      notifyListeners();
    }
  }

  Future<void> _refreshSpeciesQuietly() async {
    try {
      final data = await _apiService.getAdminSpecies();
      _species = data.cast<Map<String, dynamic>>();
      _speciesError = null;
    } catch (_) {
      // La mutación ya fue exitosa: se conserva la lista local.
    }
    notifyListeners();
  }

  void _upsertSpecies(Map<String, dynamic> item) {
    final id = item['id_especie'];
    final index = _species.indexWhere((s) => s['id_especie'] == id);
    if (index >= 0) {
      _species[index] = item;
    } else {
      _species.add(item);
    }
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
