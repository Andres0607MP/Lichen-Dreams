import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../widgets/lichen_scaffold.dart';
import '../../widgets/app_theme.dart';
import '../../widgets/settings_widgets.dart';
import 'terms_conditions_screen.dart';

class LegalSettingsScreen extends StatelessWidget {
  const LegalSettingsScreen({super.key});

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
          'Legal',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsHeader(
              title: 'Legal',
              subtitle: 'Información legal y políticas de Lichen Dreams',
              gradientColor: const Color(0xFF5D4037),
            ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.03),

            const SizedBox(height: 24),

            SettingsSection(
              title: 'Políticas',
              children: [
                SettingsTile(
                  icon: Icons.gavel_rounded,
                  iconColor: const Color(0xFF5D4037),
                  title: 'Términos y condiciones',
                  subtitle: 'Consulta las reglas de uso de la aplicación',
                  onTap: () => _showTermsDialog(context),
                ),
                const SizedBox(height: 8),
                SettingsTile(
                  icon: Icons.privacy_tip_rounded,
                  iconColor: const Color(0xFF1976D2),
                  title: 'Política de privacidad',
                  subtitle: 'Conoce cómo protegemos tu información',
                  onTap: () => _showPrivacyDialog(context),
                ),
                const SizedBox(height: 8),
                SettingsTile(
                  icon: Icons.storage_rounded,
                  iconColor: const Color(0xFFFF8F00),
                  title: 'Tratamiento de datos',
                  subtitle: 'Información sobre el uso de tus datos dentro del sistema',
                  onTap: () => _showDataDialog(context),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: 0.02),

            const SizedBox(height: 20),

            SettingsSection(
              title: 'Acerca del proyecto',
              children: [
                SettingsTile(
                  icon: Icons.description_rounded,
                  iconColor: AppTheme.primaryGreen,
                  title: 'Licencia del proyecto',
                  subtitle: 'Información sobre software y tecnologías utilizadas',
                  onTap: () => _showLicenseDialog(context),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms, delay: 200.ms).slideY(begin: 0.02),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TermsConditionsScreen()),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    SettingsDialog.showInfo(
      context: context,
      title: 'Política de privacidad',
      content: 'Lichen Dreams utiliza datos necesarios para el funcionamiento de la aplicación, como información de cuenta, ubicación para análisis ambientales y resultados generados por inteligencia artificial.',
    );
  }

  void _showDataDialog(BuildContext context) {
    SettingsDialog.showInfo(
      context: context,
      title: 'Tratamiento de datos',
      content: 'Los datos recopilados son utilizados para mejorar el análisis ambiental y la experiencia del usuario.',
    );
  }

  void _showLicenseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Licencia del proyecto',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LicenseItem(icon: Icons.flutter_dash, name: 'Flutter'),
            SizedBox(height: 8),
            _LicenseItem(icon: Icons.code_rounded, name: 'Dart'),
            SizedBox(height: 8),
            _LicenseItem(icon: Icons.api_rounded, name: 'FastAPI'),
            SizedBox(height: 8),
            _LicenseItem(icon: Icons.storage_rounded, name: 'MySQL'),
            SizedBox(height: 8),
            _LicenseItem(icon: Icons.psychology_rounded, name: 'Librerías de inteligencia artificial'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cerrar',
              style: GoogleFonts.poppins(
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LicenseItem extends StatelessWidget {
  final IconData icon;
  final String name;

  const _LicenseItem({
    required this.icon,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppTheme.primaryGreen,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
