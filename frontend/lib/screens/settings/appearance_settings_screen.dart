import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../state/app_settings_state.dart';
import '../../widgets/lichen_scaffold.dart';
import '../../widgets/app_theme.dart';
import '../../widgets/settings_widgets.dart';

class AppearanceSettingsScreen extends StatefulWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  State<AppearanceSettingsScreen> createState() => _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends State<AppearanceSettingsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        context.read<AppSettingsState>().loadSettings();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appSettings = context.watch<AppSettingsState>();

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
          'Apariencia',
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
            SettingsHeader(
              title: 'Apariencia',
              subtitle: 'Personaliza cómo se ve Lichen Dreams',
              gradientColor: const Color(0xFF7B1FA2),
            ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.03),

            const SizedBox(height: 24),

            SettingsSection(
              title: 'Tema',
              children: [
                SettingsSwitchTile(
                  icon: Icons.dark_mode_rounded,
                  iconColor: const Color(0xFF5C6BC0),
                  title: 'Modo oscuro',
                  subtitle: 'Cambia entre tema claro y oscuro',
                  value: appSettings.darkMode,
                  onChanged: (value) {
                    appSettings.setDarkMode(value);
                  },
                ),
              ],
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: 0.02),

            const SizedBox(height: 20),

            SettingsSection(
              title: 'Texto',
              children: [
                _TextScaleSelector(
                  currentScale: appSettings.textScaleFactor,
                  onChanged: (value) {
                    appSettings.setTextScaleFactor(value);
                  },
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

class _TextScaleSelector extends StatelessWidget {
  final double currentScale;
  final ValueChanged<double> onChanged;

  const _TextScaleSelector({
    required this.currentScale,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      {'label': 'Pequeño', 'value': 0.85},
      {'label': 'Normal', 'value': 1.0},
      {'label': 'Grande', 'value': 1.15},
      {'label': 'Muy grande', 'value': 1.30},
    ];

    return Column(
      children: options.map((option) {
        final value = option['value'] as double;
        final isSelected = (currentScale - value).abs() < 0.01;

        return InkWell(
          onTap: () => onChanged(value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryGreen.withValues(alpha: 0.15)
                        : AppTheme.textGray.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.text_fields_rounded,
                    color: isSelected ? AppTheme.primaryGreen : AppTheme.textGray,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    option['label'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? AppTheme.primaryGreen : AppTheme.textDark,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.primaryGreen,
                    size: 22,
                  )
                else
                  Icon(
                    Icons.circle_outlined,
                    color: AppTheme.textGray.withValues(alpha: 0.5),
                    size: 22,
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
