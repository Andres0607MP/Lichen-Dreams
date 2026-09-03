import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../widgets/app_theme.dart';
import '../widgets/lichen_scaffold.dart';
import '../widgets/app_manual_tour.dart';
import '../widgets/dashboard/lichen_carousel.dart';
import '../widgets/dashboard/liquenpedia_carousel.dart';
import '../models/dashboard_stats.dart';
import '../models/environmental_quality.dart';
import '../widgets/modern_widgets.dart';
import '../routes/route_names.dart';
import '../services/api_service.dart';
import '../services/navigation_service.dart';
import '../state/app_settings_state.dart';
import '../state/dashboard_state.dart';
import '../state/auth_state.dart';
import '../state/articles_state.dart';
import '../state/analysis_state.dart';
import '../state/notifications_state.dart';
import '../state/catalog_state.dart';
import '../screens/dashboard_stats_detail_sheet.dart';
import '../config/app_config.dart';

const String profileImagePath = 'assets/logo/saludo.png';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  bool _hasAnimated = false;
  bool _isHoveringPrimary = false;
  int _lastProcessedDataVersion = 0;

  @override
  void initState() {
    super.initState();
    LichenNavigation.instance.sync(0);
    AnalysisState.addAnalysisCompletedListener(_onAnalysisCompleted);
    Future.microtask(() {
      if (mounted) {
        final dashboardState = context.read<DashboardState>();
        final analysisState = context.read<AnalysisState>();
        final currentDataVersion = analysisState.dataVersion;
        final hasNewData = currentDataVersion != _lastProcessedDataVersion;
        _lastProcessedDataVersion = currentDataVersion;
        if ((hasNewData || !dashboardState.hasFreshData) &&
            !dashboardState.loading) {
          if (hasNewData) {
            dashboardState.invalidate();
          }
          dashboardState.loadStats();
        }
        final appSettings = context.read<AppSettingsState>();
        final notificationsState = context.read<NotificationsState>();
        notificationsState.setSoundEnabled(appSettings.soundEnabled);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _hasAnimated = true);
        precacheImage(const AssetImage(profileImagePath), context);
        final articlesState = context.read<ArticlesState>();
        final notificationsState = context.read<NotificationsState>();
        final catalogState = context.read<CatalogState>();
        if (!articlesState.hasFreshData && !articlesState.loading) {
          articlesState.loadArticles();
        }
        notificationsState.loadNotifications();
        if (catalogState.species.isEmpty && !catalogState.loadingSpecies) {
          catalogState.loadSpecies();
        }
      }
    });
  }

  @override
  void dispose() {
    AnalysisState.removeAnalysisCompletedListener(_onAnalysisCompleted);
    super.dispose();
  }

  void _onAnalysisCompleted() {
    if (!mounted) return;
    final dashboardState = context.read<DashboardState>();
    if (!dashboardState.loading) {
      dashboardState.invalidate();
      dashboardState.loadStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRole = context.select<AuthState, String?>((a) => a.role);
    final userName = context.select<AuthState, String?>((a) => a.userName);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth >= 600;
    final horizontalPadding = isLargeScreen ? 24.0 : 16.0;
    final sectionSpacing = isLargeScreen ? 28.0 : 20.0;
    final shouldAnimate = !_hasAnimated;

    return LichenScaffold(
      userRole: userRole,
      apiService: apiService,
      onBottomNavTap: (index) {
        LichenNavigation.instance.navigateToTab(context, index);
      },
      showParticleBackground: true,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (shouldAnimate)
                _buildWelcomeHeader(context, userName, horizontalPadding)
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: 0.05, end: 0, duration: 500.ms)
              else
                _buildWelcomeHeader(context, userName, horizontalPadding),
              SizedBox(height: isLargeScreen ? 20 : 16),
              LichenCarousel(),
              SizedBox(height: isLargeScreen ? 16 : 12),
              LiquenpediaCarousel(),
              SizedBox(height: sectionSpacing),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: _buildSectionDivider(),
              ),
              SizedBox(height: sectionSpacing),
              if (shouldAnimate)
                _buildPrimaryAction(context, horizontalPadding, isLargeScreen)
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .scaleXY(begin: 0.96, end: 1.0, duration: 500.ms)
              else
                _buildPrimaryAction(context, horizontalPadding, isLargeScreen),
              SizedBox(height: sectionSpacing),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: _buildSectionHeader(
                  title: 'Acciones rápidas',
                  subtitle: 'Comienza tu análisis',
                ),
              ),
              SizedBox(height: isLargeScreen ? 16 : 12),
              Selector<NotificationsState, int>(
                selector: (context, state) => state.unreadAnalysisCount,
                builder: (context, unreadCount, child) {
                  return _buildQuickActions(context, unreadCount);
                },
              ),
              SizedBox(height: sectionSpacing),
              Selector<DashboardState, DashboardStats?>(
                selector: (context, state) => state.stats,
                builder: (context, stats, child) {
                  return _buildStatsSection(
                    context,
                    stats ??
                        DashboardStats(
                          analysisCount: 0,
                          zoneCount: 0,
                          airQuality: '---',
                        ),
                    horizontalPadding,
                    isLargeScreen,
                  );
                },
                child: const SizedBox.shrink(),
              ),
              SizedBox(height: sectionSpacing),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: _buildSectionDivider(),
              ),
              SizedBox(height: sectionSpacing),
              Selector<CatalogState, _SpeciesSectionData>(
                selector: (context, catalogState) => _SpeciesSectionData(
                  species: catalogState.species,
                  loading: catalogState.loadingSpecies,
                  error: catalogState.speciesError,
                ),
                builder: (context, data, child) {
                  return _buildSpeciesSection(
                    context,
                    data,
                    horizontalPadding,
                    isLargeScreen,
                  );
                },
              ),
              SizedBox(height: sectionSpacing),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: _buildSectionDivider(),
              ),
              SizedBox(height: sectionSpacing),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: _buildSectionHeader(
                  title: 'Capacidades',
                  subtitle: 'Descubre lo que puedes hacer',
                  trailing: _HelpButton(),
                ),
              ),
              SizedBox(height: isLargeScreen ? 16 : 12),
              _buildCapabilities(context, horizontalPadding),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    String? subtitle,
    bool accent = false,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (accent)
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppTheme.primaryGreen, AppTheme.lightGreen],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        if (accent) const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildWelcomeHeader(
    BuildContext context,
    String? userName,
    double horizontalPadding,
  ) {
    final analysisState = context.watch<AnalysisState>();
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: isLargeScreen(context) ? 20 : 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryGreen.withValues(alpha: 0.08),
            AppTheme.lightGreen.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: AppTheme.radiusXLBorder,
        border: Border.all(
          color: AppTheme.primaryGreen.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                profileImagePath,
                width: isLargeScreen(context) ? 56 : 48,
                height: isLargeScreen(context) ? 56 : 48,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: isLargeScreen(context) ? 56 : 48,
                    height: isLargeScreen(context) ? 56 : 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.eco_rounded,
                      color: AppTheme.primaryGreen,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName != null ? 'Hola, $userName' : 'Lichen Dreams',
                  style: GoogleFonts.poppins(
                    fontSize: isLargeScreen(context) ? 22 : 20,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Explora el estado del aire mediante los líquenes',
                  style: GoogleFonts.poppins(
                    fontSize: isLargeScreen(context) ? 13 : 12,
                    fontWeight: FontWeight.w400,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (analysisState.hasActiveAnalysis)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.warningColor.withValues(alpha: 0.2),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.warningColor,
                    ),
                  ),
                  const SizedBox(width: 8),
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
        ],
      ),
    );
  }

  bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= 600;
  }

  Widget _buildSectionDivider() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            colorScheme.outlineVariant.withValues(alpha: 0.6),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(
    BuildContext context,
    DashboardStats stats,
    double horizontalPadding,
    bool isLargeScreen,
  ) {
    final quality = stats.environmentalQuality;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Estadísticas',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Tooltip(
                message:
                    'Métricas basadas en tus análisis y zonas registradas. Los datos se actualizan automáticamente.',
                child: Semantics(
                  label: 'Ver estadísticas detalladas',
                  button: true,
                  child: IconButton(
                    icon: Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                    ),
                    onPressed: () => DashboardStatsDetailSheet.show(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: stats.analysisCount),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return _buildStatCard(
                      title: 'Análisis',
                      value: value.toString(),
                      icon: Icons.analytics_rounded,
                      color: AppTheme.historialPrimary,
                      trendText: 'Total registrado',
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: stats.zonasAmbientalesCount),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return _buildStatCard(
                      title: 'Zonas Ambientales',
                      value: value.toString(),
                      icon: Icons.location_on_rounded,
                      color: AppTheme.mapaPrimary,
                      trendText: 'Zonas registradas',
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ModernCard(
            gradient: [
              quality.primaryColor.withValues(alpha: 0.15),
              quality.secondaryColor.withValues(alpha: 0.08),
            ],
            padding: EdgeInsets.all(isLargeScreen ? 24 : 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: quality.primaryColor,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: quality.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(quality.icon, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quality.label,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              stats.airQuality,
                              key: ValueKey(stats.airQuality),
                              style: GoogleFonts.poppins(
                                fontSize: isLargeScreen ? 32 : 28,
                                fontWeight: FontWeight.w800,
                                color: quality.primaryColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _getQualityProgress(quality.level),
                    backgroundColor: quality.secondaryColor.withValues(
                      alpha: 0.2,
                    ),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      quality.primaryColor,
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Basado en tus análisis de cámara',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _getQualityProgress(EnvironmentalQualityLevel level) {
    switch (level) {
      case EnvironmentalQualityLevel.excellent:
        return 1.0;
      case EnvironmentalQualityLevel.good:
        return 0.8;
      case EnvironmentalQualityLevel.moderate:
        return 0.6;
      case EnvironmentalQualityLevel.poor:
        return 0.4;
      case EnvironmentalQualityLevel.critical:
        return 0.2;
      case EnvironmentalQualityLevel.unknown:
        return 0.0;
    }
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? trendText,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (trendText != null) ...[
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                trendText,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, int unreadCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = _getCrossAxisCount(width);
        final aspectRatio = _getAspectRatio(width, crossAxisCount);
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: aspectRatio,
          children: [
            QuickActionCard(
              entranceDelay: 0,
              title: 'Historial',
              subtitle: 'Análisis previos',
              icon: Icons.history_rounded,
              color: AppTheme.historialPrimary,
              badge: unreadCount > 0 ? _buildBadge('$unreadCount') : null,
              onTap: () => LichenNavigation.instance.navigateToTab(context, 3),
            ),
            QuickActionCard(
              entranceDelay: 50,
              title: 'Mapa',
              subtitle: 'Ubicaciones registradas',
              icon: Icons.map_rounded,
              color: AppTheme.mapaPrimary,
              onTap: () => LichenNavigation.instance.navigateToTab(context, 2),
            ),
            QuickActionCard(
              entranceDelay: 100,
              title: 'Liquenpedia',
              subtitle: 'Artículos y educación',
              icon: Icons.school_rounded,
              color: AppTheme.liquenpediaPrimary,
              onTap: () => Navigator.pushNamed(context, AppRoutes.liquenpedia),
            ),
            Selector<CatalogState, int>(
              selector: (context, catalogState) => catalogState.species.length,
              builder: (context, speciesCount, child) {
                return QuickActionCard(
                  entranceDelay: 150,
                  title: 'Especies',
                  subtitle: 'Catálogo de especies',
                  icon: Icons.eco_rounded,
                  color: AppTheme.especiesPrimary,
                  badge: speciesCount > 0 ? _buildBadge('$speciesCount') : null,
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.adminSpeciesSettings,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.errorColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  int _getCrossAxisCount(double width) {
    if (width < 600) return 2;
    if (width < 900) return 3;
    return 4;
  }

  double _getAspectRatio(double width, int crossAxisCount) {
    if (crossAxisCount == 4) {
      return width >= 1100 ? 0.85 : 0.75;
    }
    if (crossAxisCount == 3) {
      return 0.75;
    }
    if (width < 360) return 0.7;
    return 0.8;
  }

  Widget _buildPrimaryAction(
    BuildContext context,
    double horizontalPadding,
    bool isLargeScreen,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHoveringPrimary = true),
        onExit: (_) => setState(() => _isHoveringPrimary = false),
        child: GestureDetector(
          onTap: () => LichenNavigation.instance.navigateToTab(context, 1),
          child: Transform.scale(
            scale: _isHoveringPrimary && isLargeScreen ? 1.02 : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryGreen.withValues(
                      alpha: _isHoveringPrimary && isLargeScreen ? 0.2 : 0.15,
                    ),
                    AppTheme.lightGreen.withValues(
                      alpha: _isHoveringPrimary && isLargeScreen ? 0.12 : 0.08,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryGreen.withValues(
                    alpha: _isHoveringPrimary && isLargeScreen ? 0.3 : 0.2,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withValues(
                      alpha: _isHoveringPrimary && isLargeScreen ? 0.15 : 0.08,
                    ),
                    blurRadius: _isHoveringPrimary && isLargeScreen ? 20 : 12,
                    offset: Offset(
                      0,
                      _isHoveringPrimary && isLargeScreen ? 6 : 4,
                    ),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGreen.withValues(
                            alpha: _isHoveringPrimary && isLargeScreen
                                ? 0.5
                                : 0.3,
                          ),
                          blurRadius: _isHoveringPrimary && isLargeScreen
                              ? 16
                              : 12,
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
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Analizar liquen',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Identifica especies con IA',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isLargeScreen) ...[
                    const SizedBox(width: 12),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _isHoveringPrimary ? 1.0 : 0.0,
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppTheme.primaryGreen,
                        size: 20,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpeciesSection(
    BuildContext context,
    _SpeciesSectionData data,
    double horizontalPadding,
    bool isLargeScreen,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildSectionHeader(
                  title: 'Especies',
                  subtitle: 'Catálogo de líquenes',
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.adminSpeciesSettings,
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(
                  'Ver catálogo',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (data.loading)
            _buildSpeciesLoading(context)
          else if (data.error != null)
            _buildSpeciesError(context, data.error!)
          else if (data.species.isEmpty)
            _buildSpeciesEmpty(context)
          else
            _buildSpeciesList(context, data.species, isLargeScreen),
        ],
      ),
    );
  }

  Widget _buildSpeciesLoading(BuildContext context) {
    return SizedBox(
      height: 200,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        physics: const ClampingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(3, (index) {
            return Container(
              width: 160,
              height: 200,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSpeciesError(BuildContext context, String error) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.2)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: AppTheme.errorColor,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              'No pudimos cargar las especies',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.read<CatalogState>().loadSpecies(),
              child: Text(
                'Reintentar',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeciesEmpty(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.eco_rounded,
              size: 40,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 8),
            Text(
              'Aún no hay especies en el catálogo',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Cuando agregues especies, aparecerán aquí.',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeciesList(
    BuildContext context,
    List<Map<String, dynamic>> species,
    bool isLargeScreen,
  ) {
    final displaySpecies = species.take(5).toList();
    return SizedBox(
      height: 200,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        physics: const ClampingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: displaySpecies
              .map((s) => _DashboardSpeciesCard(species: s))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildCapabilities(BuildContext context, double horizontalPadding) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        children: [
          _buildCapabilityCard(
            title: 'Identificación con IA',
            description:
                'Reconocimiento automático de especies de líquenes mediante inteligencia artificial.',
            icon: Icons.smart_toy_rounded,
            color: AppTheme.primaryGreen,
          ),
          const SizedBox(height: 14),
          _buildCapabilityCard(
            title: 'Bioindicadores ambientales',
            description:
                'Los líquenes como indicadores de calidad del aire y estado del ecosistema.',
            icon: Icons.air_rounded,
            color: AppTheme.accentGreen,
          ),
          const SizedBox(height: 14),
          _buildCapabilityCard(
            title: 'Comunidad científica',
            description:
                'Accede a artículos, estudios y el conocimiento colectivo sobre líquenes.',
            icon: Icons.people_rounded,
            color: AppTheme.lightGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildCapabilityCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.04)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeciesSectionData {
  final List<Map<String, dynamic>> species;
  final bool loading;
  final String? error;

  const _SpeciesSectionData({
    required this.species,
    required this.loading,
    this.error,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SpeciesSectionData &&
          runtimeType == other.runtimeType &&
          species == other.species &&
          loading == other.loading &&
          error == other.error;

  @override
  int get hashCode => Object.hash(species, loading, error);
}

class _DashboardSpeciesCard extends StatelessWidget {
  final Map<String, dynamic> species;

  const _DashboardSpeciesCard({required this.species});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final nombreCientifico = species['nombre_cientifico'] ?? 'Sin nombre';
    final nombreComun = species['nombre_comun']?.toString();
    final tipoCrecimiento = species['tipo_crecimiento']?.toString();
    final colorPredominante = species['color_predominante']?.toString();
    final imagen = species['imagen_referencia']?.toString();

    return GestureDetector(
      onTap: () => _openSpeciesDetail(context, species),
      child: Container(
        width: 160,
        height: 200,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.especiesPrimary.withValues(alpha: 0.12),
              AppTheme.especiesSecondary.withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.especiesPrimary.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Theme.of(context).scaffoldBackgroundColor,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: imagen != null && imagen.isNotEmpty
                      ? Image.network(
                          AppConfig.getImageUrl(imagen),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) =>
                              _PlaceholderIcon(context),
                        )
                      : _PlaceholderIcon(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                nombreCientifico,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (nombreComun != null && nombreComun.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  nombreComun,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 6),
              if (tipoCrecimiento != null && tipoCrecimiento.isNotEmpty) ...[
                _buildTag(context, tipoCrecimiento, AppTheme.especiesIcon),
              ] else if (colorPredominante != null &&
                  colorPredominante.isNotEmpty) ...[
                _buildTag(context, colorPredominante, AppTheme.especiesIcon),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openSpeciesDetail(BuildContext context, Map<String, dynamic> species) {
    Navigator.pushNamed(context, AppRoutes.speciesDetail, arguments: species);
  }

  Widget _PlaceholderIcon(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Icon(
        Icons.eco_rounded,
        color: AppTheme.especiesPrimary.withValues(alpha: 0.25),
        size: 28,
      ),
    );
  }

  Widget _buildTag(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _HelpButton extends StatefulWidget {
  const _HelpButton();

  @override
  State<_HelpButton> createState() => _HelpButtonState();
}

class _HelpButtonState extends State<_HelpButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: '¿Cómo funciona Lichen Dreams?',
      child: Semantics(
        label: '¿Cómo funciona Lichen Dreams?',
        button: true,
        child: ScaleTransition(
          scale: _pulseAnimation,
          child: GestureDetector(
            onTap: () => AppManualTour.show(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.15),
                    colorScheme.primary.withValues(alpha: 0.05),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '?',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
