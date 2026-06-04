import 'package:flutter/material.dart';

import '../services/api_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  void _loadUsers() {
    _usersFuture = _apiService.getUsers();
  }

  Future<void> _refreshUsers() async {
    setState(() {
      _loadUsers();
    });
  }

  void _showMessage(String message, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(success ? Icons.check_circle_outline : Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: success ? Colors.green.shade600 : Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _deleteUser(int id) async {
    try {
      await _apiService.deleteUser(id);
      _showMessage('Usuario eliminado correctamente.');
      _refreshUsers();
    } catch (error) {
      _showMessage(error is ApiException ? error.message : 'Error al eliminar usuario.', success: false);
    }
  }

  Future<void> _toggleUserActive(int id, bool currentState) async {
    try {
      await _apiService.updateUser(id, active: !currentState);
      _showMessage('Estado de usuario actualizado.');
      _refreshUsers();
    } catch (error) {
      _showMessage(error is ApiException ? error.message : 'Error al actualizar usuario.', success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administración de usuarios')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: const Text(
                  'Administra usuarios, elimina cuentas y controla el acceso desde aquí.',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  future: _usersFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 50),
                            const SizedBox(height: 12),
                            Text('Error: ${snapshot.error}'),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _refreshUsers,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      );
                    }

                    final users = snapshot.data ?? [];
                    if (users.isEmpty) {
                      return const Center(
                        child: Text('No se encontraron usuarios registrados.'),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: _refreshUsers,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index] as Map<String, dynamic>;
                          final active = user['activo'] as bool? ?? false;
                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              user['nombre']?.toString() ?? 'Sin nombre',
                                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(user['correo']?.toString() ?? 'Sin correo'),
                                          ],
                                        ),
                                      ),
                                      Chip(
                                        label: Text(active ? 'Activo' : 'Inactivo'),
                                        backgroundColor: active ? Colors.green.shade100 : Colors.orange.shade100,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    runSpacing: 8,
                                    spacing: 8,
                                    children: [
                                      ActionChip(
                                        label: Text(active ? 'Desactivar' : 'Activar'),
                                        avatar: Icon(active ? Icons.pause_circle_outline : Icons.play_circle_outline),
                                        onPressed: () => _toggleUserActive(user['id_usuario'] as int, active),
                                      ),
                                      ActionChip(
                                        label: const Text('Eliminar'),
                                        avatar: const Icon(Icons.delete_outline),
                                        backgroundColor: Colors.red.shade50,
                                        labelStyle: const TextStyle(color: Colors.red),
                                        onPressed: () => _deleteUser(user['id_usuario'] as int),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.admin_panel_settings_outlined, size: 18, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Text('Rol: ${user['rol'] ?? 'desconocido'}'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
