import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../state/auth_state.dart';
import '../state/profile_state.dart';
import '../state/app_settings_state.dart';
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
  bool _notificationsEnabled = true;
  bool _soundEnabled = false;
  bool _analysisAlertsEnabled = true;
  bool _darkMode = false;
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
    String? profileRole =
        (profile['rol'] as String?)?.trim().isNotEmpty == true
            ? (profile['rol'] as String).trim()
            : null;

    final userName = profileName ??
        (authState.userName?.trim().isNotEmpty == true
            ? authState.userName!.trim()
            : 'Usuario');
    final userEmail = profileEmail ??
        (authState.token != null && authState.token!.isNotEmpty
            ? 'usuario@lichendreams.app'
            : '');
    final userRole =
        (profileRole ?? authState.role ?? 'usuario').toUpperCase();
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
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primaryGreen.withValues(alpha: 0.05),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configuración',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: -0.1),
            const SizedBox(height: 20),

            _buildProfileHeader(
              initial: initial,
              name: userName,
              email: userEmail,
              role: userRole,
              profile: profile,
            ).animate().fadeIn(duration: 400.ms, delay: 150.ms).slideY(begin: 0.05),

            const SizedBox(height: 24),

            _buildSectionCard(
              title: 'Cuenta',
              icon: Icons.person_rounded,
              children: [
                _buildSettingsTile(
                  icon: Icons.edit_rounded,
                  title: 'Editar perfil',
                  subtitle: 'Actualiza tu información personal',
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.perfil);
                  },
                ),
                const SizedBox(height: 12),
                _buildSettingsTile(
                  icon: Icons.badge_rounded,
                  title: 'Rol',
                  subtitle: userRole,
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      userRole,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.05),

            const SizedBox(height: 20),

            _buildSectionCard(
              title: 'Apariencia',
              icon: Icons.palette_rounded,
              children: [
                SwitchListTile(
                  value: _darkMode,
                  onChanged: (value) {
                    setState(() => _darkMode = value);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _darkMode
                              ? 'Modo oscuro disponible próximamente'
                              : 'Modo claro activado',
                        ),
                        backgroundColor: AppTheme.primaryGreen,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                  title: Text(
                    'Modo oscuro',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  subtitle: Text(
                    _darkMode ? 'Activado (próximamente)' : 'Desactivado',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textGray,
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppTheme.primaryGreen,
                  activeTrackColor: AppTheme.primaryGreen.withValues(alpha: 0.3),
                ),
              ],
            ).animate().fadeIn(duration: 400.ms, delay: 250.ms).slideY(begin: 0.05),

            const SizedBox(height: 20),

            _buildSectionCard(
              title: 'Apariencia del texto',
              icon: Icons.text_fields_rounded,
              children: [
                _buildTextScaleSelector(),
              ],
            ).animate().fadeIn(duration: 400.ms, delay: 260.ms).slideY(begin: 0.05),

            const SizedBox(height: 20),

            _buildSectionCard(
              title: 'Notificaciones',
              icon: Icons.notifications_rounded,
              children: [
                SwitchListTile(
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() => _notificationsEnabled = value);
                    if (!value) {
                      setState(() {
                        _soundEnabled = false;
                        _analysisAlertsEnabled = false;
                      });
                    }
                  },
                  title: Text(
                    'Notificaciones push',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  subtitle: Text(
                    'Recibir alertas generales de la aplicación',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textGray,
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppTheme.primaryGreen,
                  activeTrackColor: AppTheme.primaryGreen.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _soundEnabled,
                  onChanged: _notificationsEnabled
                      ? (value) {
                          setState(() => _soundEnabled = value);
                        }
                      : null,
                  title: Text(
                    'Sonido',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  subtitle: Text(
                    'Reproducir sonido al recibir notificaciones',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textGray,
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppTheme.primaryGreen,
                  activeTrackColor: AppTheme.primaryGreen.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _analysisAlertsEnabled,
                  onChanged: _notificationsEnabled
                      ? (value) {
                          setState(() => _analysisAlertsEnabled = value);
                        }
                      : null,
                  title: Text(
                    'Alertas de análisis',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  subtitle: Text(
                    'Notificar cuando un análisis esté listo',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textGray,
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppTheme.primaryGreen,
                  activeTrackColor: AppTheme.primaryGreen.withValues(alpha: 0.3),
                ),
              ],
            ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 0.05),

            const SizedBox(height: 20),

            _buildSectionCard(
              title: 'Privacidad y seguridad',
              icon: Icons.security_rounded,
              children: [
                _buildSettingsTile(
                  icon: Icons.lock_rounded,
                  title: 'Cambiar contraseña',
                  subtitle: 'Actualiza tu credencial de acceso',
                  onTap: _handleChangePassword,
                ),
                const SizedBox(height: 12),
                _buildSettingsTile(
                  icon: Icons.verified_user_rounded,
                  title: 'Sesión actual',
                  subtitle: authState.token != null && authState.token!.isNotEmpty
                      ? 'Activa'
                      : 'Inactiva',
                  trailing: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: authState.token != null && authState.token!.isNotEmpty
                          ? AppTheme.successColor
                          : AppTheme.textGray,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSettingsTile(
                  icon: Icons.delete_outline_rounded,
                  title: 'Eliminar cuenta',
                  subtitle: 'Borra tu cuenta y datos permanentemente',
                  titleColor: AppTheme.errorColor,
                  iconColor: AppTheme.errorColor,
                  onTap: _handleDeleteAccount,
                ),
              ],
            ).animate().fadeIn(duration: 400.ms, delay: 350.ms).slideY(begin: 0.05),

            const SizedBox(height: 20),

            _buildSectionCard(
              title: 'Aplicación',
              icon: Icons.info_rounded,
              children: [
                _buildInfoRow('Aplicación', 'Lichen Dreams'),
                const SizedBox(height: 12),
                _buildInfoRow('Versión', '1.0.0'),
                const SizedBox(height: 12),
                _buildInfoRow('Desarrollado con', 'Flutter'),
                const SizedBox(height: 12),
                _buildInfoRow('Tema actual', 'Claro'),
              ],
            ).animate().fadeIn(duration: 400.ms, delay: 400.ms).slideY(begin: 0.05),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loadingLogout ? null : _handleLogout,
                icon: _loadingLogout
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.logout_rounded, color: Colors.white),
                label: Text(
                  _loadingLogout ? 'Cerrando sesión...' : 'Cerrar sesión',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 450.ms).slideY(begin: 0.05),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader({
    required String initial,
    required String name,
    required String email,
    required String role,
    required Map<String, dynamic> profile,
  }) {
    final fotoPerfil = profile['foto_perfil']?.toString();

    Widget avatarChild;
    if (fotoPerfil != null && fotoPerfil.isNotEmpty) {
      final apiService = Provider.of<ApiService>(context, listen: false);
      avatarChild = FutureBuilder<Uint8List>(
        future: apiService.downloadPrivateImageBytes(fotoPerfil),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            );
          }
          final data = snapshot.data;
          if (snapshot.hasError || data == null) {
            return Text(
              initial,
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            );
          }
          return ClipOval(
            child: Image.memory(
              data,
              fit: BoxFit.cover,
              width: 64,
              height: 64,
            ),
          );
        },
      );
    } else {
      avatarChild = Text(
        initial,
        style: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryGreen.withValues(alpha: 0.12),
            AppTheme.lightGreen.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.borderColor,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppTheme.primaryGreen, AppTheme.darkGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(child: avatarChild),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textGray,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    role,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.perfil);
            },
            icon: Icon(
              Icons.edit_rounded,
              color: AppTheme.primaryGreen,
              size: 20,
            ),
            tooltip: 'Editar perfil',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.borderColor,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primaryGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Color? titleColor,
    Color? iconColor,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor ?? AppTheme.primaryGreen,
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? AppTheme.textDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textGray,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              Flexible(
                fit: FlexFit.loose,
                child: trailing,
              ),
            ] else if (onTap != null) ...[
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textGray,
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textGray,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          fit: FlexFit.loose,
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTextScaleSelector() {
    final appSettings = context.watch<AppSettingsState>();
    final currentScale = appSettings.textScaleFactor;

    final options = [
      {'label': 'Pequeña', 'value': 0.85},
      {'label': 'Normal', 'value': 1.0},
      {'label': 'Grande', 'value': 1.15},
      {'label': 'Muy grande', 'value': 1.30},
    ];

    return Column(
      children: options.map((option) {
        return RadioListTile<double>(
          value: option['value'] as double,
          groupValue: currentScale,
          onChanged: (value) {
            if (value != null) {
              appSettings.setTextScaleFactor(value);
            }
          },
          title: Flexible(
            fit: FlexFit.loose,
            child: Text(
              option['label'] as String,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          subtitle: Flexible(
            fit: FlexFit.loose,
            child: Text(
              '${option['value']}x',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textGray,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          activeColor: AppTheme.primaryGreen,
          contentPadding: EdgeInsets.zero,
        );
      }).toList(),
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

  Future<void> _handleChangePassword() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Cambiar contraseña',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
        content: Text(
          'Esta funcionalidad no está disponible en este momento.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppTheme.textGray,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Entendido',
              style: GoogleFonts.poppins(
                color: AppTheme.textGray,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Eliminar cuenta',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: AppTheme.errorColor,
          ),
        ),
        content: Text(
          'Esta acción eliminará tu cuenta y todos tus datos de forma permanente. Esta funcionalidad no está disponible en este momento.',
          style: GoogleFonts.poppins(
            fontSize: 14,
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
              'Entendido',
              style: GoogleFonts.poppins(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'La eliminación de cuenta no está disponible actualmente'),
          backgroundColor: AppTheme.warningColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}
