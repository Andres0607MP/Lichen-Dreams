import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../state/auth_state.dart';
import '../../state/profile_state.dart';
import '../../widgets/lichen_scaffold.dart';
import '../../widgets/app_theme.dart';
import '../../routes/route_names.dart';
import '../../widgets/settings_widgets.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
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
    final userEmail = profileEmail ?? '';
    final userRole = profileRole ?? authState.role ?? 'usuario';
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Cuenta',
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
            _AccountHeader(
              initial: initial,
              name: userName,
              email: userEmail,
              role: userRole.toUpperCase(),
              profile: profile,
            ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.03),

            const SizedBox(height: 24),

            SettingsSection(
              title: 'Opciones',
              children: [
                SettingsTile(
                  icon: Icons.person_outline_rounded,
                  iconColor: const Color(0xFF4F7A45),
                  title: 'Información personal',
                  subtitle: 'Nombre, correo, documento, teléfono',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.perfil),
                ),
                const SizedBox(height: 8),
                SettingsTile(
                  icon: Icons.edit_rounded,
                  iconColor: const Color(0xFF1976D2),
                  title: 'Editar perfil',
                  subtitle: 'Modificar datos personales',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.perfil),
                ),
                const SizedBox(height: 8),
                SettingsTile(
                  icon: Icons.camera_alt_rounded,
                  iconColor: const Color(0xFF7B1FA2),
                  title: 'Foto de perfil',
                  subtitle: 'Cambiar imagen de avatar',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.perfil),
                ),
                const SizedBox(height: 8),
                SettingsInfoTile(
                  icon: Icons.badge_rounded,
                  iconColor: const Color(0xFFFF8F00),
                  title: 'Rol de usuario',
                  value: userRole.toUpperCase(),
                  subtitle: 'Solo lectura',
                ),
              ],
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: 0.02),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  final String initial;
  final String name;
  final String email;
  final String role;
  final Map<String, dynamic> profile;

  const _AccountHeader({
    required this.initial,
    required this.name,
    required this.email,
    required this.role,
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
      padding: const EdgeInsets.all(16),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
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
                  color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(child: avatarChild),
          ),
          const SizedBox(height: 14),
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
          if (email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              email,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textGray,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
    );
  }
}
