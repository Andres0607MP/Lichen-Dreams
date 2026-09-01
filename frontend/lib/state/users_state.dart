import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class UsersState extends ChangeNotifier {
  final ApiService _apiService;
  UsersState({ApiService? apiService}) : _apiService = apiService ?? ApiService();
  List<dynamic> _users = [];
  bool _loading = false;
  String? _error;

  List<dynamic> get users => List.unmodifiable(_users);
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadUsers() async {
    setState(() => _loading = true);
    _error = null;
    try {
      _users = await _apiService.getUsers();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> refresh() async {
    await loadUsers();
  }

  Future<void> deleteUser(int id) async {
    await _apiService.deleteUser(id);
    await refresh();
  }

  Future<void> toggleUserActive(int id, bool currentState) async {
    await _apiService.updateUser(id, active: !currentState);
    await refresh();
  }

  Future<void> makeUserAdmin(int id) async {
    final adminRoleId = await _apiService.getAdminRoleId();
    await _apiService.updateUser(id, idRol: adminRoleId);
    await refresh();
  }

  Future<void> setUserRole(int id, bool makeAdmin) async {
    final roleId = makeAdmin
        ? await _apiService.getAdminRoleId()
        : await _apiService.getUserRoleId();
    await _apiService.updateUser(id, idRol: roleId);
    await refresh();
  }

  void clear() {
    _users = [];
    _error = null;
    notifyListeners();
  }

  void setState(bool Function() fn) {
    final changed = fn();
    if (changed) notifyListeners();
  }
}
