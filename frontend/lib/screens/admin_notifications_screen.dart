import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../state/users_state.dart';
import '../state/auth_state.dart';
import '../widgets/app_theme.dart';
import '../widgets/modern_widgets.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({Key? key}) : super(key: key);
  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _mensajeController = TextEditingController();
  final _searchController = TextEditingController();
  String _destino = 'all';
  int? _selectedUserId;
  bool _sending = false;
  @override
  void dispose() {
    _tituloController.dispose();
    _mensajeController.dispose();
    _searchController.dispose();
    super.dispose();
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final result = await apiService.createSystemNotification(
        titulo: _tituloController.text.trim(),
        mensaje: _mensajeController.text.trim(),
        destino: _destino,
        idUsuario: _destino == 'user' ? _selectedUserId : null,
      );
      if (!mounted) return;
      final count = result['count'] ?? 0;
      final destino = result['destino'] ?? _destino;
      final message = destino == 'all'
          ? 'Notificación enviada a $count usuarios.'
          : 'Notificación enviada correctamente.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      _tituloController.clear();
      _mensajeController.clear();
      _searchController.clear();
      setState(() {
        _destino = 'all';
        _selectedUserId = null;
      });
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException
          ? e.message
          : 'Error al enviar la notificación. Intenta nuevamente.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersState = context.watch<UsersState>();
    final authState = context.watch<AuthState>();
    final isAdmin = authState.role == 'admin';
    if (!isAdmin) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppTheme.textDark,
            ),
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
    final titulo = _tituloController.text.trim();
    final mensaje = _mensajeController.text.trim();
    final isWide = MediaQuery.of(context).size.width > 720;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
              'Notificaciones del sistema',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              'Envía avisos y novedades a los usuarios de Lichen Dreams',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildForm(usersState)),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _buildPreview(titulo, mensaje, usersState),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _buildForm(usersState),
                          const SizedBox(height: 20),
                          _buildPreview(titulo, mensaje, usersState),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(UsersState usersState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Crear notificación',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        ModernCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTituloField(),
              const SizedBox(height: 18),
              _buildMensajeField(),
              const SizedBox(height: 20),
              _buildDestinatarios(),
              if (_destino == 'user') ...[
                const SizedBox(height: 16),
                _buildUserSelector(usersState),
              ],
              const SizedBox(height: 24),
              _buildSubmitButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTituloField() {
    final maxLength = 100;
    final length = _tituloController.text.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Título',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _tituloController,
          textCapitalization: TextCapitalization.sentences,
          maxLength: maxLength,
          decoration: InputDecoration(
            hintText: 'Escribe un título breve y descriptivo',
            counterText: '',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Ingresa un título';
            }
            return null;
          },
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, right: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '$length/$maxLength',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: length >= maxLength
                      ? AppTheme.errorColor
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMensajeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mensaje',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _mensajeController,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Escribe el mensaje que recibirán los usuarios',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Ingresa un mensaje';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDestinatarios() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Destinatarios',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _RecipientOption(
                label: 'Todos los usuarios',
                description: 'Enviar a todos los usuarios registrados',
                icon: Icons.group_rounded,
                value: 'all',
                groupValue: _destino,
                onChanged: (value) {
                  setState(() {
                    _destino = value ?? 'all';
                    _selectedUserId = null;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _RecipientOption(
                label: 'Usuario específico',
                description: 'Enviar únicamente a un usuario',
                icon: Icons.person_rounded,
                value: 'user',
                groupValue: _destino,
                onChanged: (value) {
                  setState(() => _destino = value ?? 'all');
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserSelector(UsersState usersState) {
    final query = _searchController.text.trim().toLowerCase();
    final allUsers = usersState.users
        .whereType<Map<String, dynamic>>()
        .toList();
    final filteredUsers = query.isEmpty
        ? allUsers
        : allUsers.where((user) {
            final name = (user['nombre']?.toString() ?? '').toLowerCase();
            final email = (user['correo']?.toString() ?? '').toLowerCase();
            return name.contains(query) || email.contains(query);
          }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.person_rounded,
                size: 18,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seleccionar usuario',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Elige quién recibirá esta notificación',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_selectedUserId != null)
          _SelectedUserCard(
            usersState: usersState,
            selectedUserId: _selectedUserId!,
            onChanged: () {
              setState(() => _selectedUserId = null);
              _searchController.clear();
            },
          )
        else
          Column(
            children: [
              TextFormField(
                controller: _searchController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre o correo...',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: AppTheme.textGray,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(
                            Icons.clear_rounded,
                            size: 18,
                            color: AppTheme.textGray,
                          ),
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              if (usersState.loading)
                const Center(
                  child: SizedBox(
                    height: 36,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (usersState.error != null)
                Column(
                  children: [
                    Text(
                      'No pudimos cargar los usuarios.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.errorColor,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: usersState.loadUsers,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        size: 16,
                        color: AppTheme.primaryGreen,
                      ),
                      label: Text(
                        'Reintentar',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                  ],
                )
              else if (allUsers.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No hay usuarios disponibles',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else if (filteredUsers.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No encontramos usuarios',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: filteredUsers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      final id = user['id_usuario'] ?? user['id'];
                      final name = user['nombre']?.toString() ?? 'Sin nombre';
                      final email = user['correo']?.toString() ?? '';
                      final parsedId = id is int
                          ? id
                          : int.tryParse(id.toString()) ?? 0;
                      return _UserTile(
                        name: name,
                        email: email,
                        isSelected: _selectedUserId == parsedId,
                        onTap: () {
                          setState(() => _selectedUserId = parsedId);
                          _searchController.clear();
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _sending ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _sending
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_rounded, size: 18, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    'Enviar notificación',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPreview(String titulo, String mensaje, UsersState usersState) {
    final showUserSelector = _destino == 'user';
    String destinatarioTexto;
    if (!showUserSelector) {
      destinatarioTexto = 'Todos los usuarios';
    } else if (_selectedUserId == null) {
      destinatarioTexto = 'Usuario específico';
    } else {
      final matched = usersState.users
          .whereType<Map<String, dynamic>>()
          .where((u) => (u['id_usuario'] ?? u['id']) == _selectedUserId)
          .toList();
      final nombre = matched.isNotEmpty
          ? (matched.first['nombre']?.toString() ?? 'Usuario específico')
          : 'Usuario específico';
      destinatarioTexto = nombre;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vista previa',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        ModernCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.notifications_rounded,
                      size: 20,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      titulo.isEmpty ? 'Título de la notificación' : titulo,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: titulo.isEmpty
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                mensaje.isEmpty ? 'Mensaje de la notificación' : mensaje,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: mensaje.isEmpty
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      size: 14,
                      color: AppTheme.primaryGreen,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Sistema',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.person_outline_rounded,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        destinatarioTexto,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectedUserCard extends StatelessWidget {
  final UsersState usersState;
  final int selectedUserId;
  final VoidCallback onChanged;
  const _SelectedUserCard({
    required this.usersState,
    required this.selectedUserId,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final user = usersState.users
        .whereType<Map<String, dynamic>>()
        .where((u) => (u['id_usuario'] ?? u['id']) == selectedUserId)
        .toList();
    final name = user.isNotEmpty
        ? (user.first['nombre']?.toString() ?? 'Usuario específico')
        : 'Usuario específico';
    final email = user.isNotEmpty
        ? (user.first['correo']?.toString() ?? '')
        : '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primaryGreen.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.person_rounded,
              size: 22,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onChanged,
            icon: Icon(
              Icons.swap_horiz_rounded,
              size: 16,
              color: AppTheme.primaryGreen,
            ),
            label: Text(
              'Cambiar',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryGreen,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final String name;
  final String email;
  final bool isSelected;
  final VoidCallback onTap;
  const _UserTile({
    required this.name,
    required this.email,
    required this.isSelected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryGreen.withValues(alpha: 0.08)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryGreen
                : AppTheme.borderColor.withValues(alpha: 0.6),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryGreen.withValues(alpha: 0.18)
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.person_rounded,
                size: 20,
                color: isSelected ? AppTheme.primaryGreen : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: isSelected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                size: 22,
                color: AppTheme.primaryGreen,
              ),
          ],
        ),
      ),
    );
  }
}

class _RecipientOption extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;
  const _RecipientOption({
    required this.label,
    required this.description,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final isSelected = groupValue == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryGreen.withValues(alpha: 0.08)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : AppTheme.borderColor,
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [AppTheme.baseShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? AppTheme.primaryGreen : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: isSelected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? AppTheme.primaryGreen : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
