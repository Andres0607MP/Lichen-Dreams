import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../state/notifications_state.dart';

class AnalysisState extends ChangeNotifier {
  final ApiService _apiService;
  AnalysisState({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  int? _activeAnalysisId;
  String _status = 'idle'; // idle | processing | completed | failed
  String? _error;
  Timer? _pollTimer;
  Map<String, dynamic>? _lastResult;
  int? _lastCompletedId;
  String? _imageSource;
  int _dataVersion = 0;
  DateTime? _startedAt;
  double _estimatedProgress = 0.0;
  Timer? _progressTimer;

  List<Map<String, dynamic>> _availableSpecies = [];
  bool _speciesLoading = false;
  String? _speciesError;

  List<Map<String, dynamic>> get availableSpecies =>
      List.unmodifiable(_availableSpecies);
  bool get speciesLoading => _speciesLoading;
  String? get speciesError => _speciesError;

  Future<void> loadSpecies() async {
    if (_speciesLoading) return;
    _speciesLoading = true;
    _speciesError = null;
    notifyListeners();
    try {
      _availableSpecies = await _apiService.getCatalogSpecies();
    } catch (e) {
      _speciesError = e.toString();
    } finally {
      _speciesLoading = false;
      notifyListeners();
    }
  }

  /// Guarda la especie seleccionada manualmente por el usuario
  /// (idEspecie = null para omitir). Devuelve el mapa actualizado del análisis.
  Future<Map<String, dynamic>> saveAnalysisSpecies(
    int analysisId,
    int? idEspecie,
  ) async {
    final result = await _apiService.updateAnalysisSpecies(analysisId, idEspecie);
    return result;
  }

  int? get activeAnalysisId => _activeAnalysisId;
  String get status => _status;
  bool get isProcessing => _status == 'processing';
  bool get hasActiveAnalysis => _activeAnalysisId != null && _status == 'processing';
  String? get error => _error;
  Map<String, dynamic>? get lastResult => _lastResult;
  int? get lastCompletedId => _lastCompletedId;
  String? get imageSource => _imageSource;
  int get dataVersion => _dataVersion;
  DateTime? get startedAt => _startedAt;
  double get estimatedProgress => _estimatedProgress;

  Future<void> startAnalysis({required File image, int? locationId, String imageSource = 'camera'}) async {
    if (_activeAnalysisId != null && _status == 'processing') {
      throw ApiException('Ya tienes un análisis en proceso. Espera a que termine.');
    }

    _status = 'processing';
    _error = null;
    _activeAnalysisId = null;
    _lastResult = null;
    _lastCompletedId = null;
    _imageSource = imageSource;
    _startProgressEstimation();
    notifyListeners();

    try {
      final resultJson = await _apiService.submitAnalysis(image, id_ubicacion: locationId, imageSource: _imageSource ?? 'camera');

      if (resultJson['rechazado'] == true) {
        _status = 'rejected';
        _error = resultJson['mensaje_rechazo']?.toString() ?? 'La imagen no corresponde a un liquen.';
        _activeAnalysisId = 0;
        _lastResult = Map<String, dynamic>.from(resultJson)..['source'] = _imageSource;
        _lastCompletedId = null;
        _stopProgressEstimation();
        notifyListeners();
        return;
      }

final analysisId = resultJson['id'] is int
           ? resultJson['id'] as int
           : int.tryParse(resultJson['id']?.toString() ?? '') ?? 0;

       if (analysisId == 0) {
         _status = 'failed';
         _error = 'El servidor no devolvió un ID de análisis válido';
         _stopProgressEstimation();
         notifyListeners();
         return;
       }

       if (_imageSource == 'gallery' && analysisId < 0) {
         // Gallery result: treat as completed without persistence
         _status = 'completed';
         _lastResult = Map<String, dynamic>.from(resultJson)..['source'] = _imageSource;
         _dataVersion++;
         _notifyAnalysisCompleted();
         notifyListeners();
         return;
       }

       // Normal flow for camera/upload
       _activeAnalysisId = analysisId;

       final estadoBackend = (resultJson['estado'] ??
               resultJson['status'] ??
               resultJson['estado_validacion'] ??
               resultJson['resultado'])
           ?.toString()
           .toLowerCase();

       final isCompleted = estadoBackend == 'completed' ||
           estadoBackend == 'completado' ||
           (resultJson['resultado_ia'] != null && resultJson['resultado_ia'].toString().isNotEmpty);

       if (isCompleted) {
         _status = 'completed';
         _lastResult = Map<String, dynamic>.from(resultJson)..['source'] = _imageSource;
         _lastCompletedId = analysisId;
         NotificationsState.instance.completeAnalysis(analysisId, _extractTitle(resultJson));
         _dataVersion++;
         _stopProgressEstimation(completed: true);
         _notifyAnalysisCompleted();
         notifyListeners();
       } else {
         NotificationsState.instance.trackAnalysis(analysisId, 'Análisis en proceso');
         _startPolling(analysisId);
         notifyListeners();
       }
    } catch (e) {
      _status = 'failed';
      _error = e is ApiException ? e.message : e.toString();
      if (_activeAnalysisId != null) {
        NotificationsState.instance.failAnalysis(_activeAnalysisId!);
      }
      _stopProgressEstimation();
      notifyListeners();
    }
  }

  void _startPolling(int analysisId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_activeAnalysisId != analysisId || _status != 'processing') {
        _pollTimer?.cancel();
        return;
      }
      try {
        final statusJson = await _apiService.getAnalysisStatus(analysisId);
        final estado = (statusJson['estado'] ?? statusJson['status'] ?? statusJson['estado_validacion'])
                ?.toString()
                .toLowerCase() ??
            'processing';

        if (estado == 'completed' || estado == 'completado') {
          _status = 'completed';
          _lastCompletedId = analysisId;
          _pollTimer?.cancel();
          try {
            final resultJson = await _apiService.getAnalysisResult(analysisId);
            _lastResult = Map<String, dynamic>.from(resultJson)..['source'] = _imageSource;
            NotificationsState.instance.completeAnalysis(analysisId, _extractTitle(resultJson));
          } catch (_) {
            NotificationsState.instance.completeAnalysis(analysisId, 'Análisis completado');
          }
          _dataVersion++;
          _stopProgressEstimation(completed: true);
          _notifyAnalysisCompleted();
          notifyListeners();
        } else if (estado == 'failed' || estado == 'error' || estado == 'fallido') {
          _status = 'failed';
          _pollTimer?.cancel();
          NotificationsState.instance.failAnalysis(analysisId);
          _stopProgressEstimation();
          notifyListeners();
        }
      } catch (_) {
        // Mantener polling en error de red
      }
    });
  }

  Future<void> refreshStatus() async {
    if (_activeAnalysisId == null || _activeAnalysisId == 0) return;
    try {
      final resultJson = await _apiService.getAnalysisResult(_activeAnalysisId!);
      final estado = (resultJson['estado'] ??
              resultJson['status'] ??
              resultJson['estado_validacion'] ??
              resultJson['resultado'])
          ?.toString()
          .toLowerCase();

      final isCompleted = estado == 'completed' ||
          estado == 'completado' ||
          (resultJson['resultado_ia'] != null && resultJson['resultado_ia'].toString().isNotEmpty);

      if (isCompleted) {
        _status = 'completed';
        _lastResult = Map<String, dynamic>.from(resultJson)..['source'] = _imageSource;
        _lastCompletedId = _activeAnalysisId;
        NotificationsState.instance.completeAnalysis(_activeAnalysisId!, _extractTitle(resultJson));
        _dataVersion++;
        _stopProgressEstimation(completed: true);
        _notifyAnalysisCompleted();
      } else if (estado == 'failed' || estado == 'error') {
        _status = 'failed';
        NotificationsState.instance.failAnalysis(_activeAnalysisId!);
        _stopProgressEstimation();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      notifyListeners();
    }
  }

  Future<void> reset() {
    _pollTimer?.cancel();
    _progressTimer?.cancel();
    _activeAnalysisId = null;
    _status = 'idle';
    _error = null;
    _lastResult = null;
    _lastCompletedId = null;
    _startedAt = null;
    _estimatedProgress = 0.0;
    _availableSpecies = [];
    _speciesLoading = false;
    _speciesError = null;
    notifyListeners();
    return Future.value();
  }

  void markLastAsShared() {
    if (_lastResult == null) return;
    final updated = Map<String, dynamic>.from(_lastResult!);
    updated['visibilidad'] = 'shared';
    _lastResult = updated;
    notifyListeners();
  }

  static final List<VoidCallback> _analysisCompletedListeners = [];

  static void addAnalysisCompletedListener(VoidCallback listener) {
    _analysisCompletedListeners.add(listener);
  }

  static void removeAnalysisCompletedListener(VoidCallback listener) {
    _analysisCompletedListeners.remove(listener);
  }

  void _notifyAnalysisCompleted() {
    for (final listener in _analysisCompletedListeners) {
      listener();
    }
  }

  void _startProgressEstimation() {
    _progressTimer?.cancel();
    _startedAt = DateTime.now();
    _estimatedProgress = 0.0;
    _progressTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (_status != 'processing') {
        _progressTimer?.cancel();
        return;
      }
      final elapsed = DateTime.now().difference(_startedAt!).inMilliseconds;
      final raw = 1.0 - (1.0 / (elapsed / 1800.0 + 1.0));
      _estimatedProgress = (raw * 0.9).clamp(0.0, 0.9);
      notifyListeners();
    });
  }

  void _stopProgressEstimation({bool completed = false}) {
    _progressTimer?.cancel();
    _progressTimer = null;
    _startedAt = null;
    if (completed) {
      _estimatedProgress = 1.0;
      notifyListeners();
    }
  }

  String _extractTitle(Map<String, dynamic> json) {
    return (json['titulo'] ??
            json['nombre'] ??
            json['resultado'] ??
            json['resultado_ia'] ??
            'Análisis completado')
        .toString();
  }
}
