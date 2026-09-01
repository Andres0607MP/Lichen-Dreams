import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../state/users_state.dart';
import '../state/auth_state.dart';
import '../widgets/app_theme.dart';
import '../widgets/app_notification.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<int> _deletingUserIds = {};
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _parseUserId(dynamic rawId) {
    if (rawId is int) return rawId;
    if (rawId is String) return int.tryParse(rawId) ?? 0;
    return 0;
  }

  void _showMessage(String message, {bool success = true}) {
    if (!mounted) return;
    AppNotification.show(context, message: message, isError: !success);
  }

  Future<void> _deleteUser(BuildContext context, int id) async {
    try {
      final usersState = Provider.of<UsersState>(context, listen: false);
      await usersState.deleteUser(id);
      if (mounted) {
        setState(() => _deletingUserIds.remove(id));
        _showMessage('Usuario eliminado correctamente.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _deletingUserIds.remove(id));
        _showMessage(
          error is ApiException ? error.message : 'Error al eliminar usuario.',
          success: false,
        );
      }
    }
  }

  void _startDelete(int userId) {
    setState(() => _deletingUserIds.add(userId));
  }

  Future<void> _toggleUserActive(
    BuildContext context,
    int id,
    bool currentState,
  ) async {
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

  Future<void> _toggleUserRole(
    BuildContext context,
    int id,
    String userName,
    bool makeAdmin,
  ) async {
    try {
      final usersState = Provider.of<UsersState>(context, listen: false);
      await usersState.setUserRole(id, makeAdmin);
      _showMessage(
        makeAdmin
            ? 'Usuario $userName ahora es administrador.'
            : 'Rol actualizado a usuario normal.',
      );
    } catch (error) {
      _showMessage(
        error is ApiException ? error.message : 'Error al actualizar rol.',
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

  List<dynamic> _filterUsers(List<dynamic> users) {
    if (_searchQuery.isEmpty) return users;
    final query = _searchQuery.toLowerCase();
    return users.where((user) {
      final nombre = user['nombre']?.toString().toLowerCase() ?? '';
      final correo = user['correo']?.toString().toLowerCase() ?? '';
      return nombre.contains(query) || correo.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final usersState = context.watch<UsersState>();
    final authState = context.watch<AuthState>();
    final users = usersState.users;
    final isAdmin = authState.role == 'admin';
    if (!isAdmin) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: Theme.of(context).colorScheme.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Acceso restringido',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final filteredUsers = _filterUsers(users);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gestionar usuarios',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              'Administra cuentas y permisos',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_rounded,
              color: AppTheme.primaryGreen,
            ),
            tooltip: 'Enviar notificación',
            onPressed: () {
              Navigator.pushNamed(context, '/admin-notifications');
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: AppTheme.primaryGreen,
                ),
                onPressed: usersState.loadUsers,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeaderSection(users.length, filteredUsers.length),
            if (users.isNotEmpty) _buildSearchField(),
            Expanded(
              child: usersState.loading
                  ? _buildLoadingState()
                  : usersState.error != null
                  ? _buildErrorState(usersState.error.toString())
                  : users.isEmpty
                  ? _buildEmptyState()
                  : filteredUsers.isEmpty
                  ? _buildNoResultsState()
                  : RefreshIndicator(
                      onRefresh: usersState.loadUsers,
                      child: _buildUsersList(filteredUsers),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(int totalUsers, int filteredCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryGreen.withValues(alpha: 0.08),
              AppTheme.primaryGreen.withValues(alpha: 0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppTheme.primaryGreen.withValues(alpha: 0.12),
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryGreen.withValues(alpha: 0.2),
                    AppTheme.primaryGreen.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.people_alt_rounded,
                color: AppTheme.primaryGreen,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$totalUsers ${totalUsers == 1 ? 'usuario' : 'usuarios'}',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _searchQuery.isNotEmpty
                        ? '$filteredCount encontrado${filteredCount == 1 ? '' : 's'} de $totalUsers'
                        : 'Registrados en la plataforma',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          style: GoogleFonts.poppins(fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'Buscar por nombre o correo...',
            hintStyle: GoogleFonts.poppins(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppTheme.textGray,
              size: 20,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppTheme.textGray,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppTheme.primaryGreen,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Cargando usuarios...',
            style: GoogleFonts.poppins(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 36,
                  color: AppTheme.errorColor.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Error al cargar',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () =>
                    Provider.of<UsersState>(context, listen: false).loadUsers(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  'Reintentar',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryGreen.withValues(alpha: 0.10),
                      AppTheme.primaryGreen.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.people_outline_rounded,
                  size: 44,
                  color: AppTheme.primaryGreen.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Sin usuarios',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No hay usuarios registrados en el sistema actualmente.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_off_rounded,
                  size: 36,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Sin resultados',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No se encontraron usuarios que coincidan con "$_searchQuery".',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                icon: const Icon(Icons.clear_rounded, size: 18),
                label: Text(
                  'Limpiar búsqueda',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsersList(List<dynamic> users) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index] as Map<String, dynamic>;
        final userId = _parseUserId(user['id_usuario'] ?? user['id']);
        final userName = user['nombre']?.toString() ?? 'Sin nombre';
        final isDeleting = _deletingUserIds.contains(userId);
        return _UserCard(
              user: user,
              isDeleting: isDeleting,
              onDelete: () => _confirmDelete(context, user),
              onToggleActive: () {
                final estado =
                    user['estado_cuenta']?.toString().toLowerCase() ?? '';
                final active = estado == 'activo' || estado == 'active';
                _toggleUserActive(context, userId, active);
              },
              onToggleRole: (makeAdmin) {
                if (makeAdmin) {
                  _confirmMakeAdmin(context, userId, userName);
                } else {
                  _confirmRemoveAdmin(context, userId, userName);
                }
              },
              onDeleteAnimationComplete: () => _deleteUser(context, userId),
            )
            .animate()
            .fadeIn(duration: 200.ms, delay: (40 * index).ms)
            .slideY(begin: 0.05, end: 0);
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Map<String, dynamic> user,
  ) async {
    final userName = user['nombre']?.toString() ?? 'este usuario';
    final userId = _parseUserId(user['id_usuario'] ?? user['id']);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(
          Icons.delete_outline_rounded,
          size: 36,
          color: AppTheme.errorColor.withValues(alpha: 0.7),
        ),
        title: Text(
          'Eliminar usuario',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar a $userName? Esta acción no se puede deshacer.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            height: 1.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Eliminar',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      ),
    );
    if (confirmed == true && context.mounted) {
      _startDelete(userId);
    }
  }

  Future<void> _confirmMakeAdmin(
    BuildContext context,
    int userId,
    String userName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(
          Icons.admin_panel_settings_rounded,
          size: 36,
          color: AppTheme.primaryGreen.withValues(alpha: 0.7),
        ),
        title: Text(
          'Hacer administrador',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          '¿Otorgar permisos de administrador a $userName? Tendrá acceso completo al panel de administración.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            height: 1.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Confirmar',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      ),
    );
    if (confirmed == true && context.mounted) {
      _toggleUserRole(context, userId, userName, true);
    }
  }

  Future<void> _confirmRemoveAdmin(
    BuildContext context,
    int userId,
    String userName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(
          Icons.person_rounded,
          size: 36,
          color: AppTheme.warningColor.withValues(alpha: 0.7),
        ),
        title: Text(
          'Quitar administrador',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          '¿Quitar permisos de administrador a $userName? Perderá acceso al panel de administración.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            height: 1.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Confirmar',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      ),
    );
    if (confirmed == true && context.mounted) {
      _toggleUserRole(context, userId, userName, false);
    }
  }
}

class _UserCard extends StatefulWidget {
  final Map<String, dynamic> user;
  final bool isDeleting;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;
  final Function(bool makeAdmin) onToggleRole;
  final VoidCallback onDeleteAnimationComplete;
  const _UserCard({
    required this.user,
    required this.isDeleting,
    required this.onDelete,
    required this.onToggleActive,
    required this.onToggleRole,
    required this.onDeleteAnimationComplete,
  });
  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard>
    with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  late AnimationController _deleteAnimController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  @override
  void initState() {
    super.initState();
    _deleteAnimController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _deleteAnimController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _deleteAnimController, curve: Curves.easeOut),
    );
    _deleteAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDeleteAnimationComplete();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _UserCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDeleting && !oldWidget.isDeleting) {
      _deleteAnimController.forward();
    } else if (!widget.isDeleting && oldWidget.isDeleting) {
      _deleteAnimController.reset();
    }
  }

  @override
  void dispose() {
    _deleteAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final estado = user['estado_cuenta']?.toString().toLowerCase() ?? '';
    final active = estado == 'activo' || estado == 'active';
    final userRole = user['rol']?.toString().toLowerCase() ?? 'user';
    final isAdminRole = userRole == 'admin';
    final userName = user['nombre']?.toString() ?? 'Sin nombre';
    final userEmail = user['correo']?.toString() ?? 'Sin correo';
    final userPhoto = user['foto_perfil']?.toString();
    final fechaRegistro = user['fecha_registro']?.toString();
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Opacity(
          opacity: widget.isDeleting ? 0.6 : 1.0,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovering = true),
            onExit: (_) => setState(() => _isHovering = false),
            child: AnimatedContainer(
              duration: AppTheme.animationNormal,
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _isHovering && !widget.isDeleting
                      ? AppTheme.primaryGreen.withValues(alpha: 0.3)
                      : AppTheme.border40,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: _isHovering && !widget.isDeleting ? 0.08 : 0.04,
                    ),
                    blurRadius: _isHovering && !widget.isDeleting ? 16 : 8,
                    offset: Offset(
                      0,
                      _isHovering && !widget.isDeleting ? 6 : 2,
                    ),
                  ),
                ],
              ),
              child: AbsorbPointer(
                absorbing: widget.isDeleting,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 500;
                      return isCompact
                          ? _buildCompactLayout(
                              userName,
                              userEmail,
                              userPhoto,
                              active,
                              isAdminRole,
                              fechaRegistro,
                            )
                          : _buildExpandedLayout(
                              userName,
                              userEmail,
                              userPhoto,
                              active,
                              isAdminRole,
                              fechaRegistro,
                            );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactLayout(
    String userName,
    String userEmail,
    String? userPhoto,
    bool active,
    bool isAdminRole,
    String? fechaRegistro,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Avatar(name: userName, photo: userPhoto),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    userEmail,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _BadgesRow(
          active: active,
          isAdmin: isAdminRole,
          fechaRegistro: fechaRegistro,
        ),
        const SizedBox(height: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RoleToggleButton(
              isAdmin: isAdminRole,
              onTap: () => widget.onToggleRole(!isAdminRole),
            ),
            const SizedBox(height: 8),
            _ActionButton(
              label: active ? 'Desactivar' : 'Activar',
              icon: active
                  ? Icons.pause_circle_outline_rounded
                  : Icons.play_circle_outline_rounded,
              color: active ? AppTheme.warningColor : AppTheme.successColor,
              onTap: widget.onToggleActive,
            ),
            const SizedBox(height: 8),
            _ActionButton(
              label: 'Eliminar',
              icon: Icons.delete_outline_rounded,
              color: AppTheme.errorColor,
              isDestructive: true,
              onTap: widget.onDelete,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExpandedLayout(
    String userName,
    String userEmail,
    String? userPhoto,
    bool active,
    bool isAdminRole,
    String? fechaRegistro,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _Avatar(name: userName, photo: userPhoto),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.email_rounded,
                        size: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          userEmail,
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _BadgesRow(
              active: active,
              isAdmin: isAdminRole,
              fechaRegistro: fechaRegistro,
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(height: 1, color: AppTheme.borderColor),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _RoleToggleButton(
              isAdmin: isAdminRole,
              onTap: () => widget.onToggleRole(!isAdminRole),
            ),
            const SizedBox(width: 8),
            _ActionButton(
              label: active ? 'Desactivar' : 'Activar',
              icon: active
                  ? Icons.pause_circle_outline_rounded
                  : Icons.play_circle_outline_rounded,
              color: active ? AppTheme.warningColor : AppTheme.successColor,
              onTap: widget.onToggleActive,
            ),
            const SizedBox(width: 8),
            _ActionButton(
              label: 'Eliminar',
              icon: Icons.delete_outline_rounded,
              color: AppTheme.errorColor,
              isDestructive: true,
              onTap: widget.onDelete,
            ),
          ],
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? photo;
  const _Avatar({required this.name, this.photo});
  @override
  Widget build(BuildContext context) {
    final initials = _extractInitials(name);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGreen.withValues(alpha: 0.15),
            AppTheme.primaryGreen.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: photo != null && photo!.isNotEmpty
            ? Image.network(
                photo!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _buildInitialsFallback(initials),
              )
            : _buildInitialsFallback(initials),
      ),
    );
  }

  Widget _buildInitialsFallback(String initials) {
    return Center(
      child: Text(
        initials,
        style: GoogleFonts.poppins(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryGreen,
        ),
      ),
    );
  }

  String _extractInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || name == 'Sin nombre') return '?';
    if (parts.length == 1)
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class _BadgesRow extends StatelessWidget {
  final bool active;
  final bool isAdmin;
  final String? fechaRegistro;
  const _BadgesRow({
    required this.active,
    required this.isAdmin,
    this.fechaRegistro,
  });
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _Badge(
          label: isAdmin ? 'Admin' : 'Usuario',
          color: isAdmin ? AppTheme.primaryGreen : Theme.of(context).colorScheme.onSurfaceVariant,
          icon: isAdmin ? Icons.shield_rounded : Icons.person_rounded,
        ),
        _Badge(
          label: active ? 'Activo' : 'Inactivo',
          color: active ? AppTheme.successColor : AppTheme.warningColor,
          icon: active
              ? Icons.check_circle_outline_rounded
              : Icons.cancel_outlined,
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _Badge({required this.label, required this.color, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleToggleButton extends StatelessWidget {
  final bool isAdmin;
  final VoidCallback onTap;
  const _RoleToggleButton({required this.isAdmin, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: AppTheme.animationFast,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isAdmin
                ? AppTheme.warningColor.withValues(alpha: 0.08)
                : AppTheme.primaryGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAdmin
                  ? AppTheme.warningColor.withValues(alpha: 0.25)
                  : AppTheme.primaryGreen.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isAdmin
                    ? Icons.person_outline_rounded
                    : Icons.admin_panel_settings_rounded,
                size: 16,
                color: isAdmin ? AppTheme.warningColor : AppTheme.primaryGreen,
              ),
              const SizedBox(width: 6),
              Text(
                isAdmin ? 'Quitar admin' : 'Hacer admin',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isAdmin
                      ? AppTheme.warningColor
                      : AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isDestructive;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isDestructive = false,
  });
  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isPressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: AppTheme.animationFast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: widget.isDestructive
              ? AppTheme.errorColor.withValues(alpha: _isPressed ? 0.15 : 0.08)
              : widget.color.withValues(alpha: _isPressed ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.color.withValues(alpha: _isPressed ? 0.4 : 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, size: 16, color: widget.color),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: widget.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
