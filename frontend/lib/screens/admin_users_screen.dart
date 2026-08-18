import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../state/users_state.dart';
import '../state/auth_state.dart';
import '../widgets/app_theme.dart';
import '../widgets/modern_widgets.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({Key? key}) : super(key: key);

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  int _parseUserId(dynamic rawId) {
    if (rawId is int) return rawId;
    if (rawId is String) return int.tryParse(rawId) ?? 0;
    return 0;
  }

  void _showMessage(String message, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_outline : Icons.error_outline,
              color: Colors.white,
            ),
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

  Future<void> _deleteUser(BuildContext context, int id) async {
    try {
      final usersState = Provider.of<UsersState>(context, listen: false);
      await usersState.deleteUser(id);
      _showMessage('Usuario eliminado correctamente.');
    } catch (error) {
      _showMessage(
        error is ApiException ? error.message : 'Error al eliminar usuario.',
        success: false,
      );
    }
  }

  Future<void> _toggleUserActive(BuildContext context, int id, bool currentState) async {
    try {
      final usersState = Provider.of<UsersState>(context, listen: false);
      await usersState.toggleUserActive(id, currentState);
      _showMessage('Estado de usuario actualizado.');
    } catch (error) {
      _showMessage(
        error is ApiException ? error.message : 'Error al actualizar usuario.',
        success: false,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final usersState = Provider.of<UsersState>(context, listen: false);
      if (usersState.users.isEmpty && !usersState.loading) {
        usersState.loadUsers();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authState = Provider.of<AuthState>(context, listen: false);
    final usersState = Provider.of<UsersState>(context, listen: false);
    if (!authState.isAuthenticated) {
      usersState.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersState = context.watch<UsersState>();
    final authState = context.watch<AuthState>();
    final users = usersState.users;
    final isAdmin = authState.role == 'admin';

    if (!isAdmin) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textDark),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Acceso restringido',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

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
                onPressed: usersState.loadUsers,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
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
            Expanded(
              child: usersState.loading
                  ? const Center(child: CircularProgressIndicator())
                  : usersState.error != null
                      ? Center(
                          child: EmptyState(
                            icon: Icons.error_outline,
                            title: 'Error al cargar usuarios',
                            description: usersState.error.toString(),
                            actionLabel: 'Reintentar',
                            onAction: usersState.loadUsers,
                          ),
                        )
                      : users.isEmpty
                          ? Center(
                              child: EmptyState(
                                icon: Icons.people_outline,
                                title: 'Sin usuarios',
                                description:
                                    'No hay usuarios registrados en el sistema',
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: usersState.loadUsers,
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                physics: const AlwaysScrollableScrollPhysics(),
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemCount: users.length,
                                itemBuilder: (context, index) {
                                  final user = users[index] as Map<String, dynamic>;
                                  final estado =
                                      user['estado_cuenta']?.toString().toLowerCase() ??
                                          '';
                                  final active = estado == 'activo' || estado == 'active';
                                  final userName =
                                      user['nombre']?.toString() ?? 'Sin nombre';
                                  final userEmail =
                                      user['correo']?.toString() ?? 'Sin correo';
                                  final userId = _parseUserId(
                                    user['id_usuario'] ?? user['id'],
                                  );

                                  return ModernCard(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
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
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: active
                                                    ? Colors.green.withOpacity(0.1)
                                                    : Colors.orange.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                active ? 'Activo' : 'Inactivo',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: active
                                                      ? Colors.green
                                                      : Colors.orange,
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
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.stretch,
                                                    spacing: 8,
                                                    children: [
                                                      ModernButton(
                                                        label: active
                                                            ? 'Desactivar'
                                                            : 'Activar',
                                                        onPressed: () =>
                                                            _toggleUserActive(
                                                              context,
                                                              userId,
                                                              active,
                                                            ),
                                                        color: active
                                                            ? Colors.orange
                                                            : Colors.green,
                                                        width: double.infinity,
                                                      ),
                                                      ModernButton(
                                                        label: 'Eliminar',
                                                        onPressed: () {
                                                          showDialog(
                                                            context: context,
                                                            builder: (context) => AlertDialog(
                                                              title: const Text(
                                                                'Confirmar eliminación',
                                                              ),
                                                              content: Text(
                                                                '¿Eliminar usuario $userName?',
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () =>
                                                                      Navigator.pop(
                                                                        context,
                                                                      ),
                                                                  child: const Text(
                                                                    'Cancelar',
                                                                  ),
                                                                ),
                                                                TextButton(
                                                                  onPressed: () {
                                                                    Navigator.pop(
                                                                      context,
                                                                    );
                                                                    _deleteUser(
                                                                        context, userId);
                                                                  },
                                                                  style:
                                                                      TextButton.styleFrom(
                                                                    foregroundColor:
                                                                        Colors.red,
                                                                  ),
                                                                  child: const Text(
                                                                    'Eliminar',
                                                                  ),
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
                                                        label: active
                                                            ? 'Desactivar'
                                                            : 'Activar',
                                                        onPressed: () =>
                                                            _toggleUserActive(
                                                              context,
                                                              userId,
                                                              active,
                                                            ),
                                                        color: active
                                                            ? Colors.orange
                                                            : Colors.green,
                                                        width: 140,
                                                      ),
                                                      ModernButton(
                                                        label: 'Eliminar',
                                                        onPressed: () {
                                                          showDialog(
                                                            context: context,
                                                            builder: (context) => AlertDialog(
                                                              title: const Text(
                                                                'Confirmar eliminación',
                                                              ),
                                                              content: Text(
                                                                '¿Eliminar usuario $userName?',
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () =>
                                                                      Navigator.pop(
                                                                        context,
                                                                      ),
                                                                  child: const Text(
                                                                    'Cancelar',
                                                                  ),
                                                                ),
                                                                TextButton(
                                                                  onPressed: () {
                                                                    Navigator.pop(
                                                                      context,
                                                                    );
                                                                    _deleteUser(
                                                                        context, userId);
                                                                  },
                                                                  style:
                                                                      TextButton.styleFrom(
                                                                    foregroundColor:
                                                                        Colors.red,
                                                                  ),
                                                                  child: const Text(
                                                                    'Eliminar',
                                                                  ),
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
                            ),
            ),
          ],
        ),
      ),
    );
  }
}