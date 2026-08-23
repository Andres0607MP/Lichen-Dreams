import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../widgets/lichen_scaffold.dart';
import '../../widgets/app_theme.dart';
import '../../widgets/settings_widgets.dart';

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          'Privacidad y seguridad',
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
            SettingsSection(
              title: 'Privacidad',
              children: [
                SettingsTile(
                  icon: Icons.share_rounded,
                  iconColor: const Color(0xFF4F7A45),
                  title: 'Análisis compartidos',
                  subtitle: 'Controla qué análisis pueden ver otros usuarios en el mapa',
                  onTap: () => SettingsDialog.showComingSoon(context, 'Gestión de análisis compartidos'),
                ),
                const SizedBox(height: 8),
                SettingsTile(
                  icon: Icons.visibility_rounded,
                  iconColor: const Color(0xFF1976D2),
                  title: 'Visibilidad de datos',
                  subtitle: 'Gestiona qué información ambiental se muestra públicamente',
                  onTap: () => SettingsDialog.showComingSoon(context, 'Visibilidad de datos'),
                ),
                const SizedBox(height: 8),
                SettingsTile(
                  icon: Icons.location_on_rounded,
                  iconColor: const Color(0xFFFF8F00),
                  title: 'Permisos de ubicación',
                  subtitle: 'Controla el acceso del GPS para registrar análisis',
                  onTap: () => SettingsDialog.showComingSoon(context, 'Permisos de ubicación'),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.02),

            const SizedBox(height: 20),

            SettingsSection(
              title: 'Seguridad',
              children: [
                SettingsTile(
                  icon: Icons.security_rounded,
                  iconColor: const Color(0xFF7B1FA2),
                  title: 'Seguridad de cuenta',
                  subtitle: 'Opciones relacionadas con protección de tu cuenta',
                  onTap: () => SettingsDialog.showComingSoon(context, 'Seguridad de cuenta'),
                ),
                const SizedBox(height: 8),
                SettingsTile(
                  icon: Icons.lock_rounded,
                  iconColor: const Color(0xFF00897B),
                  title: 'Cambiar contraseña',
                  subtitle: 'Actualiza tu credencial de acceso',
                  onTap: () => _handleChangePassword(context),
                ),
                const SizedBox(height: 8),
                SettingsTile(
                  icon: Icons.delete_outline_rounded,
                  iconColor: AppTheme.errorColor,
                  title: 'Eliminar cuenta',
                  subtitle: 'Borra tu cuenta y datos permanentemente',
                  titleColor: AppTheme.errorColor,
                  onTap: () => _handleDeleteAccount(context),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: 0.02),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _handleChangePassword(BuildContext context) async {
    await SettingsDialog.showInfo(
      context: context,
      title: 'Cambiar contraseña',
      content: 'Esta funcionalidad no está disponible en este momento.',
    );
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final confirm = await SettingsDialog.showConfirm(
      context: context,
      title: 'Eliminar cuenta',
      content: 'Esta acción eliminará tu cuenta y todos tus datos de forma permanente. Esta funcionalidad no está disponible en este momento.',
      titleColor: AppTheme.errorColor,
    );

    if (confirm == true && context.mounted) {
      SettingsDialog.showComingSoon(context, 'Eliminación de cuenta');
    }
  }
}
