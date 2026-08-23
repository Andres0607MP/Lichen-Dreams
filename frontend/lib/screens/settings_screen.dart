import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../state/auth_state.dart';
import '../state/profile_state.dart';
import '../widgets/lichen_scaffold.dart';
import '../widgets/app_theme.dart';
import '../services/navigation_service.dart';
import '../routes/route_names.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loadingLogout = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      final profileState = context.read<ProfileState>();
      if (profileState.profile == null || profileState.profile!.isEmpty) {
        await profileState.loadProfile();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();
    final profileState = context.watch<ProfileState>();
    final profile = profileState.profile ?? {};

    String? profileName =
        (profile['nombre'] as String?)?.trim().isNotEmpty == true
            ? (profile['nombre'] as String).trim()
            : null;
    String? profileEmail =
        (profile['correo'] as String?)?.trim().isNotEmpty == true
            ? (profile['correo'] as String).trim()
            : null;

    final userName = profileName ??
        (authState.userName?.trim().isNotEmpty == true
            ? authState.userName!.trim()
            : 'Usuario');
    final userEmail = profileEmail ?? '';
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return LichenScaffold(
      apiService: Provider.of<ApiService>(context, listen: false),
      showBottomNav: false,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textDark),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.dashboard,
                (route) => false,
              );
            }
          },
        ),
        title: Text(
          'Configuración',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SettingsUserHeader(
              initial: initial,
              name: userName,
              email: userEmail,
              profile: profile,
            ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.03),

            const SizedBox(height: 20),

            Text(
              'Categorías',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textGray,
                letterSpacing: 0.5,
              ),
            ).animate().fadeIn(duration: 250.ms, delay: 50.ms),

            const SizedBox(height: 12),

            _SettingsCategoryTile(
              icon: Icons.person_rounded,
              iconColor: const Color(0xFF4F7A45),
              title: 'Cuenta',
              subtitle: 'Información personal, foto de perfil, rol',
              onTap: () => Navigator.pushNamed(context, AppRoutes.accountSettings),
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideX(begin: 0.05),

            const SizedBox(height: 10),

            _SettingsCategoryTile(
              icon: Icons.shield_rounded,
              iconColor: const Color(0xFF1976D2),
              title: 'Privacidad y seguridad',
              subtitle: 'Análisis compartidos, contraseña, eliminar cuenta',
              onTap: () => Navigator.pushNamed(context, AppRoutes.privacySettings),
            ).animate().fadeIn(duration: 300.ms, delay: 150.ms).slideX(begin: 0.05),

            const SizedBox(height: 10),

            _SettingsCategoryTile(
              icon: Icons.notifications_rounded,
              iconColor: const Color(0xFFFF8F00),
              title: 'Notificaciones',
              subtitle: 'Alertas push, sonido, avisos de análisis',
              onTap: () => Navigator.pushNamed(context, AppRoutes.notificationSettings),
            ).animate().fadeIn(duration: 300.ms, delay: 200.ms).slideX(begin: 0.05),

            const SizedBox(height: 10),

            _SettingsCategoryTile(
              icon: Icons.palette_rounded,
              iconColor: const Color(0xFF7B1FA2),
              title: 'Apariencia',
              subtitle: 'Modo oscuro, tamaño de texto, tema',
              onTap: () => Navigator.pushNamed(context, AppRoutes.appearanceSettings),
            ).animate().fadeIn(duration: 300.ms, delay: 250.ms).slideX(begin: 0.05),

            const SizedBox(height: 10),

            _SettingsCategoryTile(
              icon: Icons.info_outline_rounded,
              iconColor: const Color(0xFF00897B),
              title: 'Información',
              subtitle: 'Sobre Lichen Dreams, ayuda, versión',
              onTap: () => Navigator.pushNamed(context, AppRoutes.informationSettings),
            ).animate().fadeIn(duration: 300.ms, delay: 300.ms).slideX(begin: 0.05),

            const SizedBox(height: 10),

            _SettingsCategoryTile(
              icon: Icons.description_outlined,
              iconColor: const Color(0xFF5D4037),
              title: 'Legal',
              subtitle: 'Términos, privacidad, tratamiento de datos',
              onTap: () => Navigator.pushNamed(context, AppRoutes.legalSettings),
            ).animate().fadeIn(duration: 300.ms, delay: 350.ms).slideX(begin: 0.05),

            const SizedBox(height: 24),

            Text(
              'Sesión',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textGray,
                letterSpacing: 0.5,
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 400.ms),

            const SizedBox(height: 12),

            _SettingsLogoutTile(
              loading: _loadingLogout,
              onTap: _loadingLogout ? null : _handleLogout,
            ).animate().fadeIn(duration: 300.ms, delay: 450.ms),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Cerrar sesión',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
        content: Text(
          '¿Estás seguro de que deseas cerrar sesión?',
          style: GoogleFonts.poppins(
            color: AppTheme.textGray,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(
                color: AppTheme.textGray,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: Text(
              'Cerrar sesión',
              style: GoogleFonts.poppins(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _loadingLogout = true);

    try {
      await context.read<AuthState>().logout();
      if (mounted) {
        LichenNavigation.instance.reset();
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingLogout = false);
      }
    }
  }
}

class _SettingsUserHeader extends StatelessWidget {
  final String initial;
  final String name;
  final String email;
  final Map<String, dynamic> profile;

  const _SettingsUserHeader({
    required this.initial,
    required this.name,
    required this.email,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final fotoPerfil = profile['foto_perfil']?.toString();

    Widget avatarChild;
    if (fotoPerfil != null && fotoPerfil.isNotEmpty) {
      final apiService = Provider.of<ApiService>(context, listen: false);
      avatarChild = FutureBuilder<Uint8List>(
        future: apiService.downloadPrivateImageBytes(fotoPerfil),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            );
          }
          final data = snapshot.data;
          if (snapshot.hasError || data == null) {
            return Text(
              initial,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            );
          }
          return ClipOval(
            child: Image.memory(
              data,
              fit: BoxFit.cover,
              width: 50,
              height: 50,
            ),
          );
        },
      );
    } else {
      avatarChild = Text(
        initial,
        style: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      );
    }

    return InkWell(
      onTap: () => Navigator.pushNamed(context, AppRoutes.perfil),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryGreen.withValues(alpha: 0.08),
              AppTheme.primaryGreen.withValues(alpha: 0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppTheme.primaryGreen, AppTheme.darkGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(child: avatarChild),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
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
                        color: AppTheme.textGray,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Toca para ver perfil',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textGray,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCategoryTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsCategoryTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textGray,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textGray,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsLogoutTile extends StatelessWidget {
  final bool loading;
  final VoidCallback? onTap;

  const _SettingsLogoutTile({
    required this.loading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.errorColor,
                      ),
                    )
                  : const Icon(
                      Icons.logout_rounded,
                      color: AppTheme.errorColor,
                      size: 22,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loading ? 'Cerrando sesión...' : 'Cerrar sesión',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.errorColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Salir de tu cuenta',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textGray,
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
}
