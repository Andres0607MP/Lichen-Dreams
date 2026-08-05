import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../widgets/app_theme.dart';
import '../widgets/lichen_scaffold.dart';
import '../widgets/dashboard/lichen_carousel.dart';
import '../widgets/dashboard/liquenpedia_carousel.dart';
import '../models/dashboard_stats.dart';
import '../widgets/modern_widgets.dart';
import '../routes/route_names.dart';
import '../services/api_service.dart';
import '../services/navigation_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  late Future<DashboardStats> _statsFuture;
  String? _userRole;
  String? _userName;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadUserRole();
    _loadUserName();
  }

  Future<void> _loadStats() async {
    setState(() {
      _statsFuture = _apiService.getDashboardStats().then(
        (json) => DashboardStats.fromJson(json),
      );
    });
  }

  Future<void> _loadUserRole() async {
    final role = await _apiService.getSavedRole();
    setState(() {
      _userRole = role;
    });
  }

  Future<void> _loadUserName() async {
    try {
      final profile = await _apiService.getProfile();
      if (mounted) {
        setState(() {
          _userName = profile['nombre']?.toString();
        });
      }
    } catch (_) {
      // Silently fail — welcome header shows generic greeting
    }
  }

  Widget _buildWelcomeHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryGreen.withValues(alpha: 0.06),
            AppTheme.lightGreen.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: AppTheme.cardRadius,
        border: Border.all(
          color: AppTheme.primaryGreen.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.eco_rounded,
              color: AppTheme.primaryGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName != null
                      ? 'Hola, $_userName'
                      : 'Lichen Dreams',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Explora el estado del aire mediante los líquenes',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LichenScaffold(
      userRole: _userRole,
      apiService: _apiService,
      bottomNavIndex: _selectedIndex,
      onBottomNavTap: (index) {
        LichenNavigation.instance.navigateTo(index);
        setState(() => _selectedIndex = index);
        _navigateToSection(index);
      },
      showParticleBackground: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeHeader().animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0, duration: 500.ms),
          const SizedBox(height: 16),
          LichenCarousel().animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0, duration: 500.ms),
          const SizedBox(height: 24),

          // Lichenpedia Section
          Row(
            children: [
              Container(
                width: 3,
                height: 20,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryGreen, AppTheme.lightGreen],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SectionHeader(
                  title: 'Lichenpedia',
                  subtitle: 'Explora el conocimiento de los líquenes',
                ),
              ),
            ],
          ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0, duration: 500.ms),
          const SizedBox(height: 12),
          LiquenpediaCarousel().animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0, duration: 500.ms),
          const SizedBox(height: 24),

          // Thin natural accent
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.borderColor.withValues(alpha: 0.2),
                  AppTheme.borderColor.withValues(alpha: 0.05),
                  AppTheme.borderColor.withValues(alpha: 0.2),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Sección de estadísticas
          _buildStatsSection().animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0, duration: 500.ms),
          const SizedBox(height: 24),
          _buildPrimaryAction().animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1), duration: 500.ms),
          const SizedBox(height: 24),
          SectionHeader(
            title: 'Acciones rápidas',
            subtitle: 'Comienza tu análisis',
          ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0, duration: 500.ms),
          const SizedBox(height: 12),
          _buildQuickActions().animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0, duration: 500.ms),
          const SizedBox(height: 24),
          SectionHeader(
            title: 'Características',
            subtitle: 'Explora todas las funciones',
          ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0, duration: 500.ms),
          const SizedBox(height: 12),
          _buildFeaturedFeatures().animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0, duration: 500.ms),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return FutureBuilder<DashboardStats>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return ModernCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('No fue posible cargar las estadísticas.'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    _loadStats();
                  },
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }

        final stats = snapshot.data ?? DashboardStats(
          analysisCount: 0,
          zoneCount: 0,
          airQuality: '---',
        );
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: StatsCard(
                    title: 'Análisis',
                    value: stats.analysisCount.toString(),
                    icon: Icons.analytics_rounded,
                    color: AppTheme.primaryGreen,
                    backgroundColor: AppTheme.primaryGreen,
                  ).animate().fadeIn(duration: 400.ms),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatsCard(
                    title: 'Zonas',
                    value: stats.zoneCount.toString(),
                    icon: Icons.location_on_rounded,
                    color: AppTheme.accentGreen,
                    backgroundColor: AppTheme.accentGreen,
                  ).animate().fadeIn(duration: 400.ms),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ModernCard(
              gradient: [
                AppTheme.primaryGreen.withValues(alpha: 0.12),
                AppTheme.lightGreen.withValues(alpha: 0.06),
              ],
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.air_rounded,
                          color: AppTheme.primaryGreen,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Calidad ambiental',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textGray,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              stats.airQuality,
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Basado en el último análisis de líquenes',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textGray,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 500.ms),
          ],
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: FeatureCard(
            title: 'Capturar',
            description: 'Toma una foto',
            icon: Icons.camera_alt_rounded,
            color: AppTheme.primaryGreen,
            onTap: () => Navigator.pushNamed(context, AppRoutes.analisis),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FeatureCard(
            title: 'Historial',
            description: 'Ver análisis',
            icon: Icons.history_rounded,
            color: AppTheme.accentGreen,
            onTap: () => Navigator.pushNamed(context, AppRoutes.historial),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryAction() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.analisis),
      child: ModernCard(
        gradient: [
          AppTheme.primaryGreen.withValues(alpha: 0.15),
          AppTheme.lightGreen.withValues(alpha: 0.08),
        ],
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analizar liquen',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Identifica especies con IA',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textGray,
                  ),
                ),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.96, 0.96), duration: 600.ms),
    );
  }

  Widget _buildFeaturedFeatures() {
    return Column(
      children: [
        FeatureCard(
          title: 'Análisis con IA',
          description: 'Identifica especies de líquenes automáticamente',
          icon: Icons.smart_toy_rounded,
          color: AppTheme.primaryGreen,
          onTap: () => Navigator.pushNamed(context, AppRoutes.analisis),
        ),
        const SizedBox(height: 12),
        FeatureCard(
          title: 'Mapa interactivo',
          description: 'Visualiza todas las zonas analizadas',
          icon: Icons.map_rounded,
          color: AppTheme.accentGreen,
          onTap: () => Navigator.pushNamed(context, AppRoutes.mapa),
        ),
        const SizedBox(height: 12),
        FeatureCard(
          title: 'Guardar ubicación',
          description: 'Registra tu ubicación de análisis',
          icon: Icons.location_pin,
          color: Colors.blueAccent,
          onTap: () => Navigator.pushNamed(context, AppRoutes.location),
        ),
        const SizedBox(height: 12),
        FeatureCard(
          title: 'Especies identificadas',
          description: 'Revisa las especies encontradas',
          icon: Icons.eco_rounded,
          color: Colors.deepOrange,
          onTap: () => Navigator.pushNamed(context, AppRoutes.species),
        ),
        const SizedBox(height: 12),
        FeatureCard(
          title: 'Liquenpedia',
          description: 'Aprende sobre líquenes y el ambiente',
          icon: Icons.school_rounded,
          color: AppTheme.lightGreen,
          onTap: () => Navigator.pushNamed(context, AppRoutes.liquenpedia),
        ),
      ],
    );
  }

  void _navigateToSection(int index) {
    switch (index) {
      case 1:
        Navigator.pushNamed(
          context,
          AppRoutes.analisis,
        ).then((_) => _loadStats());
        break;
      case 2:
        Navigator.pushNamed(context, AppRoutes.mapa).then((_) => _loadStats());
        break;
      case 3:
        Navigator.pushNamed(
          context,
          AppRoutes.historial,
        ).then((_) => _loadStats());
        break;
      case 4:
        Navigator.pushNamed(
          context,
          AppRoutes.perfil,
        ).then((_) => _loadStats());
        break;
    }
  }
}
