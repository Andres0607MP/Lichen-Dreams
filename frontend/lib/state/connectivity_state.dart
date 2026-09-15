import 'package:flutter/widgets.dart';
import '../services/connectivity_service.dart';

class ConnectivityState extends ChangeNotifier {
  ConnectivityState({ConnectivityService? connectivityService})
      : _connectivityService = connectivityService ?? ConnectivityService() {
    _connectivityService.addListener(_onConnectivityChanged);
  }

  final ConnectivityService _connectivityService;
  ConnectivityStatus _status = ConnectivityStatus.checking;

  ConnectivityStatus get status => _status;

  bool get isConnected => _status == ConnectivityStatus.connected;
  bool get isChecking => _status == ConnectivityStatus.checking;
  bool get isDisconnected => _status == ConnectivityStatus.disconnected;

  void _onConnectivityChanged() {
    _status = _connectivityService.status;
    notifyListeners();
  }

  Future<void> retry() async {
    await _connectivityService.retry();
  }

  @override
  void dispose() {
    _connectivityService.removeListener(_onConnectivityChanged);
    _connectivityService.dispose();
    super.dispose();
  }
}