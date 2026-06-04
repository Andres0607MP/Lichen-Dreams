import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/api_service.dart';
import '../widgets/app_theme.dart';
import '../widgets/modern_widgets.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({Key? key}) : super(key: key);

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
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gestión de usuarios',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            Text(
              'Panel de administración',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppTheme.textGray,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.red),
                onPressed: _refreshUsers,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header info
            Padding(
              padding: const EdgeInsets.all(16),
              child: ModernCard(
                gradient: [
                  Colors.red.withOpacity(0.1),
                  Colors.red.withOpacity(0.05),
                ],
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Colors.red,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Control total',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Administra usuarios, elimina cuentas y controla acceso',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: AppTheme.textGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Users list
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: _usersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: EmptyState(
                        icon: Icons.error_outline,
                        title: 'Error al cargar usuarios',
                        description: snapshot.error.toString(),
                        actionLabel: 'Reintentar',
                        onAction: _refreshUsers,
                      ),
                    );
                  }

                  final users = snapshot.data ?? [];
                  if (users.isEmpty) {
                    return Center(
                      child: EmptyState(
                        icon: Icons.people_outline,
                        title: 'Sin usuarios',
                        description: 'No hay usuarios registrados en el sistema',
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _refreshUsers,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      physics: const AlwaysScrollableScrollPhysics(),
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index] as Map<String, dynamic>;
                        final active = user['active'] as bool? ?? false;
                        final userName = user['name']?.toString() ?? 'Sin nombre';
                        final userEmail = user['email']?.toString() ?? 'Sin correo';
                        final userId = user['id'] as int;

                        return ModernCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          userName,
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.email_rounded,
                                              size: 14,
                                              color: AppTheme.textGray,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                userEmail,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w400,
                                                  color: AppTheme.textGray,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: active ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      active ? 'Activo' : 'Inactivo',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: active ? Colors.green : Colors.orange,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isMobile = constraints.maxWidth < 400;
                                  return isMobile
                                      ? Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          spacing: 8,
                                          children: [
                                            ModernButton(
                                              label: active ? 'Desactivar' : 'Activar',
                                              onPressed: () => _toggleUserActive(userId, active),
                                              color: active ? Colors.orange : Colors.green,
                                              width: double.infinity,
                                            ),
                                            ModernButton(
                                              label: 'Eliminar',
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => AlertDialog(
                                                    title: const Text('Confirmar eliminación'),
                                                    content: Text('¿Eliminar usuario $userName?'),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.pop(context),
                                                        child: const Text('Cancelar'),
                                                      ),
                                                      TextButton(
                                                        onPressed: () {
                                                          Navigator.pop(context);
                                                          _deleteUser(userId);
                                                        },
                                                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                                                        child: const Text('Eliminar'),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                              isOutlined: true,
                                              color: Colors.red,
                                              width: double.infinity,
                                            ),
                                          ],
                                        )
                                      : Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            ModernButton(
                                              label: active ? 'Desactivar' : 'Activar',
                                              onPressed: () => _toggleUserActive(userId, active),
                                              color: active ? Colors.orange : Colors.green,
                                              width: 140,
                                            ),
                                            ModernButton(
                                              label: 'Eliminar',
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => AlertDialog(
                                                    title: const Text('Confirmar eliminación'),
                                                    content: Text('¿Eliminar usuario $userName?'),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.pop(context),
                                                        child: const Text('Cancelar'),
                                                      ),
                                                      TextButton(
                                                        onPressed: () {
                                                          Navigator.pop(context);
                                                          _deleteUser(userId);
                                                        },
                                                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                                                        child: const Text('Eliminar'),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                              isOutlined: true,
                                              color: Colors.red,
                                              width: 110,
                                            ),
                                          ],
                                        );
                                },
                              ),
                            ],
                          ),
                        ).animate().fadeIn(duration: (100 * (index + 1)).ms);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
