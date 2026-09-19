import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

typedef BackendHealthProgressCallback = void Function(
  int attempt,
  int maxAttempts,
  bool retrying,
);

enum ConnectivityStatus {
  connected,
  checking,
  disconnected,
}

class ConnectivityService {
  ConnectivityService({
    http.Client? client,
    bool startMonitoring = true,
  }) : _client = client ?? http.Client() {
    if (startMonitoring) {
      _startMonitoring();
    }
  }

  final http.Client _client;
  bool _isMonitoring = false;
  Timer? _monitoringTimer;
  ConnectivityStatus _status = ConnectivityStatus.checking;
  final List<VoidCallback> _listeners = [];

  ConnectivityStatus get status => _status;

  void addListener(VoidCallback callback) {
    _listeners.add(callback);
  }

  void removeListener(VoidCallback callback) {
    _listeners.remove(callback);
  }

  void _notifyListeners() {
    for (final callback in _listeners) {
      callback();
    }
  }

  Future<void> _startMonitoring() async {
    if (_isMonitoring) return;
    _isMonitoring = true;
    
    // Perform initial check
    await _checkConnectivity();
    
    // Set up periodic checking (every 30 seconds)
    _monitoringTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkConnectivity();
    });
  }

  Future<bool> checkBackendWithRetry({
    Duration timeout = const Duration(seconds: 15),
    int maxAttempts = 3,
    List<Duration> backoffs = const [
      Duration(seconds: 5),
      Duration(seconds: 10),
    ],
    BackendHealthProgressCallback? onProgress,
  }) async {
    final attempts = maxAttempts > 0 ? maxAttempts : 1;

    for (var attempt = 1; attempt <= attempts; attempt++) {
      onProgress?.call(attempt, attempts, attempt > 1);

      try {
        final response = await _client
            .get(AppConfig.buildUri('/api/test'))
            .timeout(timeout);

        if (response.statusCode >= 500 && attempt < attempts) {
          await _waitForBackoff(attempt, backoffs);
          continue;
        }

        return response.statusCode < 500;
      } on TimeoutException {
        if (attempt >= attempts) return false;
      } on SocketException {
        if (attempt >= attempts) return false;
      } on HandshakeException {
        if (attempt >= attempts) return false;
      } on http.ClientException {
        if (attempt >= attempts) return false;
      } catch (_) {
        return false;
      }

      await _waitForBackoff(attempt, backoffs);
    }

    return false;
  }

  Future<void> _waitForBackoff(int attempt, List<Duration> backoffs) async {
    if (backoffs.isEmpty) return;
    final index = attempt - 1;
    if (index < 0 || index >= backoffs.length) return;
    await Future.delayed(backoffs[index]);
  }

  Future<void> _checkConnectivity() async {
    // Don't check if already checking
    if (_status == ConnectivityStatus.checking) return;
    
    _updateStatus(ConnectivityStatus.checking);
    
    try {
      // Try to connect to the backend test endpoint
      final response = await _client
          .get(AppConfig.buildUri('/api/test'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _updateStatus(ConnectivityStatus.connected);
      } else {
        _updateStatus(ConnectivityStatus.disconnected);
      }
    } on SocketException catch (_) {
      _updateStatus(ConnectivityStatus.disconnected);
    } on HttpException catch (_) {
      _updateStatus(ConnectivityStatus.disconnected);
    } on FormatException catch (_) {
      _updateStatus(ConnectivityStatus.disconnected);
    } on TimeoutException catch (_) {
      _updateStatus(ConnectivityStatus.disconnected);
    } catch (e) {
      // Any other error means disconnected
      _updateStatus(ConnectivityStatus.disconnected);
    }
  }

  void _updateStatus(ConnectivityStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _notifyListeners();
    }
  }

  Future<void> retry() async {
    await _checkConnectivity();
  }

  void dispose() {
    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _listeners.clear();
  }
}
