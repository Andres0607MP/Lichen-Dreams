import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../widgets/app_theme.dart';
import '../widgets/lichen_scaffold.dart';
import '../widgets/dashboard/lichen_carousel.dart';
import '../widgets/dashboard/liquenpedia_carousel.dart';
import '../models/dashboard_stats.dart';
import '../widgets/modern_widgets.dart';
import '../routes/route_names.dart';
import '../services/api_service.dart';
import '../services/navigation_service.dart';
import '../state/dashboard_state.dart';
import '../state/auth_state.dart';
import '../state/articles_state.dart';
import '../state/analysis_state.dart';
import '../state/notifications_state.dart';

const String profileImagePath = 'assets/logo/saludo.png';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {

  @override
  void initState() {
    super.initState();
    LichenNavigation.instance.sync(0);
    Future.microtask(() {
      if (mounted) {
        final dashboardState = context.read<DashboardState>();
        final articlesState = context.read<ArticlesState>();
        final notificationsState = context.read<NotificationsState>();
        if (!dashboardState.hasFreshData && !dashboardState.loading) {
          dashboardState.loadStats();
        }
        if (!articlesState.hasFreshData && !articlesState.loading) {
          articlesState.loadArticles();
        }
        notificationsState.loadNotifications();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userRole = context.select<AuthState, String?>((a) => a.role);
    final userName = context.select<AuthState, String?>((a) => a.userName);
    final selectedIndex = 0;
    final apiService = Provider.of<ApiService>(context, listen: false);

    return LichenScaffold(
      userRole: userRole,
      apiService: apiService,
      bottomNavIndex: selectedIndex,
      onBottomNavTap: (index) {
        LichenNavigation.instance.navigateTo(index);
        _navigateToSection(context, index);
      },
      showParticleBackground: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeHeader(context, userName).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0, duration: 500.ms),
          const SizedBox(height: 16),
          LichenCarousel().animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0, duration: 500.ms),
          const SizedBox(height: 24),

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

          Selector<DashboardState, DashboardStats?>(
            selector: (context, state) => state.stats,
            builder: (context, stats, child) {
              return _buildStatsSection(context, stats ?? DashboardStats(
                analysisCount: 0,
                zoneCount: 0,
                airQuality: '---',
              )).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0, duration: 500.ms);
            },
            child: const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
          _buildPrimaryAction(context).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1), duration: 500.ms),
          const SizedBox(height: 24),

          SectionHeader(
            title: 'Acciones rápidas',
            subtitle: 'Comienza tu análisis',
          ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0, duration: 500.ms),
          const SizedBox(height: 12),
          _buildQuickActions(context).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0, duration: 500.ms),
          const SizedBox(height: 24),

          SectionHeader(
            title: 'Capacidades',
            subtitle: 'Descubre lo que puedes hacer',
          ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0, duration: 500.ms),
          const SizedBox(height: 12),
          _buildCapabilities(context).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0, duration: 500.ms),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(BuildContext context, String? userName) {
    final analysisState = context.watch<AnalysisState>();
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
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              profileImagePath,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.eco_rounded,
                  color: AppTheme.primaryGreen,
                  size: 48,
                );
              },
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName != null ? 'Hola, $userName' : 'Lichen Dreams',
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
          const SizedBox(width: 8),
          if (analysisState.hasActiveAnalysis)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.warningColor),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Analizando...',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warningColor,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, DashboardStats stats) {
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
  }

  Widget _buildQuickActions(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 400 ? 3 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.85,
          children: [
            QuickActionCard(
              title: 'Historial',
              icon: Icons.history_rounded,
              backgroundIcon: Icons.history_rounded,
              color: AppTheme.accentGreen,
              onTap: () => Navigator.pushNamed(context, AppRoutes.historial),
            ),
            QuickActionCard(
              title: 'Mapa',
              icon: Icons.map_rounded,
              backgroundIcon: Icons.map_rounded,
              color: Colors.blueAccent,
              onTap: () => Navigator.pushNamed(context, AppRoutes.mapa),
            ),
            QuickActionCard(
              title: 'Liquenpedia',
              icon: Icons.school_rounded,
              backgroundIcon: Icons.school_rounded,
              color: AppTheme.lightGreen,
              onTap: () => Navigator.pushNamed(context, AppRoutes.liquenpedia),
            ),
            QuickActionCard(
              title: 'Especies',
              icon: Icons.eco_rounded,
              backgroundIcon: Icons.eco_rounded,
              color: Colors.deepOrange,
              onTap: () => Navigator.pushNamed(context, AppRoutes.species),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPrimaryAction(BuildContext context) {
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

  Widget _buildCapabilities(BuildContext context) {
    return Column(
      children: [
        FeatureCard(
          title: 'Identificación con IA',
          description: 'Reconocimiento automático de especies de líquenes mediante inteligencia artificial.',
          icon: Icons.smart_toy_rounded,
          color: AppTheme.primaryGreen,
        ),
        const SizedBox(height: 12),
        FeatureCard(
          title: 'Bioindicadores ambientales',
          description: 'Los líquenes como indicadores de calidad del aire y estado del ecosistema.',
          icon: Icons.air_rounded,
          color: AppTheme.accentGreen,
        ),
        const SizedBox(height: 12),
        FeatureCard(
          title: 'Comunidad científica',
          description: 'Accede a artículos, estudios y el conocimiento colectivo sobre líquenes.',
          icon: Icons.people_rounded,
          color: AppTheme.lightGreen,
        ),
      ],
    );
  }

  void _navigateToSection(BuildContext context, int index) {
    switch (index) {
      case 1:
        Navigator.pushNamed(context, AppRoutes.analisis);
        break;
      case 2:
        Navigator.pushNamed(context, AppRoutes.mapa);
        break;
      case 3:
        Navigator.pushNamed(context, AppRoutes.historial);
        break;
      case 4:
        Navigator.pushNamed(context, AppRoutes.perfil);
        break;
    }
  }
}
