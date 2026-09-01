import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../widgets/lichen_scaffold.dart';
import '../../widgets/app_theme.dart';
import '../../widgets/settings_widgets.dart';
import '../../routes/route_names.dart';

class InformationSettingsScreen extends StatelessWidget {
  const InformationSettingsScreen({super.key});

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
          'Información',
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
              title: 'Información',
              subtitle: 'Conoce más sobre Lichen Dreams',
              gradientColor: const Color(0xFF00897B),
            ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.03),

            const SizedBox(height: 24),

            SettingsSection(
              title: 'Aplicación',
              children: [
                SettingsTile(
                  icon: Icons.eco_rounded,
                  iconColor: AppTheme.primaryGreen,
                  title: 'Sobre Lichen Dreams',
                  subtitle: 'Conoce el propósito del proyecto y cómo funciona',
                  onTap: () => _showAboutDialog(context),
                ),
                const SizedBox(height: 8),
                SettingsTile(
                  icon: Icons.info_outline_rounded,
                  iconColor: const Color(0xFF1976D2),
                  title: 'Versión',
                  subtitle: '1.0.0',
                  showChevron: false,
                ),
                const SizedBox(height: 8),
                SettingsTile(
                  icon: Icons.code_rounded,
                  iconColor: const Color(0xFF7B1FA2),
                  title: 'Desarrollado con',
                  subtitle: 'Tecnologías utilizadas en el proyecto',
                  onTap: () => _showTechDialog(context),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: 0.02),

            const SizedBox(height: 20),

            SettingsSection(
              title: 'Ayuda',
              children: [
                SettingsTile(
                  icon: Icons.help_outline_rounded,
                  iconColor: const Color(0xFFFF8F00),
                  title: 'Ayuda y soporte',
                  subtitle: 'Preguntas frecuentes y asistencia',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.helpSettings),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms, delay: 200.ms).slideY(begin: 0.02),

            const SizedBox(height: 20),

            SettingsSection(
              title: 'Licencias',
              children: [
                SettingsTile(
                  icon: Icons.description_rounded,
                  iconColor: const Color(0xFF5D4037),
                  title: 'Licencias',
                  subtitle: 'Información de las dependencias utilizadas',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.licensesSettings),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms, delay: 300.ms).slideY(begin: 0.02),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    SettingsDialog.showInfo(
      context: context,
      title: 'Sobre Lichen Dreams',
      content: 'Lichen Dreams es una aplicación para analizar líquenes como bioindicadores ambientales mediante inteligencia artificial.',
    );
  }

  void _showTechDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Desarrollado con',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TechItem(icon: Icons.flutter_dash, name: 'Flutter'),
            SizedBox(height: 8),
            _TechItem(icon: Icons.api_rounded, name: 'FastAPI'),
            SizedBox(height: 8),
            _TechItem(icon: Icons.psychology_rounded, name: 'Inteligencia Artificial'),
            SizedBox(height: 8),
            _TechItem(icon: Icons.storage_rounded, name: 'MySQL'),
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

class _TechItem extends StatelessWidget {
  final IconData icon;
  final String name;

  const _TechItem({
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
        Text(
          name,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
