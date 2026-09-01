import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../state/app_settings_state.dart';
import '../../state/notifications_state.dart';
import '../../widgets/lichen_scaffold.dart';
import '../../widgets/app_theme.dart';
import '../../widgets/settings_widgets.dart';
import '../../routes/route_names.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  // TODO: Migrar _notificationsEnabled y _analysisAlertsEnabled a AppSettingsState
  // para persistencia consistente con soundEnabled
  bool _notificationsEnabled = true;
  bool _analysisAlertsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final appSettings = context.watch<AppSettingsState>();
    final soundEnabled = appSettings.soundEnabled;

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
          'Notificaciones',
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
              title: 'Notificaciones',
              subtitle: 'Configura cómo quieres recibir avisos de Lichen Dreams',
              gradientColor: const Color(0xFF4F7A45),
            ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.03),

            const SizedBox(height: 24),

            SettingsSection(
              title: 'Notificaciones generales',
              children: [
                SettingsSwitchTile(
                  icon: Icons.notifications_rounded,
                  iconColor: const Color(0xFF4F7A45),
                  title: 'Notificaciones push',
                  subtitle: 'Recibir avisos importantes de la aplicación',
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() {
                      _notificationsEnabled = value;
                      if (!value) {
                        appSettings.setSoundEnabled(false);
                        NotificationsState.instance.setSoundEnabled(false);
                        _analysisAlertsEnabled = false;
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                SettingsSwitchTile(
                  icon: Icons.volume_up_rounded,
                  iconColor: const Color(0xFF1976D2),
                  title: 'Sonido',
                  subtitle: 'Reproducir sonido al recibir notificaciones',
                  value: soundEnabled,
                  onChanged: _notificationsEnabled
                      ? (value) {
                          appSettings.setSoundEnabled(value);
                          NotificationsState.instance.setSoundEnabled(value);
                        }
                      : null,
                ),
                const SizedBox(height: 8),
                SettingsSwitchTile(
                  icon: Icons.psychology_rounded,
                  iconColor: const Color(0xFF7B1FA2),
                  title: 'Alertas de análisis',
                  subtitle: 'Recibir aviso cuando un análisis termine',
                  value: _analysisAlertsEnabled,
                  onChanged: _notificationsEnabled
                      ? (value) {
                          setState(() => _analysisAlertsEnabled = value);
                        }
                      : null,
                ),
              ],
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: 0.02),

            const SizedBox(height: 20),

            SettingsSection(
              title: 'Actividad ambiental',
              children: [
                SettingsTile(
                  icon: Icons.eco_rounded,
                  iconColor: AppTheme.primaryGreen,
                  title: 'Resumen ambiental',
                  subtitle: 'Consulta tus reportes de calidad ambiental',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.environmentalReports),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms, delay: 200.ms).slideY(begin: 0.02),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
