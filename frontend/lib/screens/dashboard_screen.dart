import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../widgets/app_theme.dart';
import '../widgets/dashboard/lichen_carousel.dart';
import '../widgets/dashboard/liquenpedia_carousel.dart';
import '../models/dashboard_stats.dart';
import '../widgets/modern_widgets.dart';
import '../routes/route_names.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  late Future<DashboardStats> _statsFuture;
  String? _userRole;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadUserRole();
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

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Image.asset(
                'assets/logo/logo.png',
                width: 64,
                height: 64,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lichen Dreams',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            Text(
              'Lee el aire, entiende tu entorno',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppTheme.textGray,
              ),
            ),
          ],
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
        actions: [
          Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(
                  Icons.menu_rounded,
                  color: AppTheme.primaryGreen,
                ),
                tooltip: 'Menú',
                onPressed: () {
                  Scaffold.of(context).openEndDrawer();
                },
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: IgnorePointer(child: _ParticleBackground())),
          SafeArea(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LichenCarousel(),
                  const SizedBox(height: 32),

                  // Divider
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.borderColor.withValues(alpha: 0.3),
                          AppTheme.borderColor.withValues(alpha: 0.1),
                          AppTheme.borderColor.withValues(alpha: 0.3),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Lichenpedia Section
                  _buildLichenpediaHeader().animate().fadeIn(duration: 500.ms),
                  const SizedBox(height: 12),
                  LiquenpediaCarousel(),
                  const SizedBox(height: 32),

                  // Divider
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.borderColor.withValues(alpha: 0.3),
                          AppTheme.borderColor.withValues(alpha: 0.1),
                          AppTheme.borderColor.withValues(alpha: 0.3),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Sección de estadísticas
                  _buildStatsSection(),
                  const SizedBox(height: 24),
                  SectionHeader(
                    title: 'Acciones rápidas',
                    subtitle: 'Comienza tu análisis',
                  ),
                  const SizedBox(height: 12),
                  _buildQuickActions(),
                  const SizedBox(height: 24),
                  SectionHeader(
                    title: 'Características',
                    subtitle: 'Explora todas las funciones',
                  ),
                  const SizedBox(height: 12),
                  _buildFeaturedFeatures(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        backgroundColor: AppTheme.backgroundColor,
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color.fromARGB(17, 165, 185, 167).withValues(alpha: 0.1),
                    AppTheme.backgroundColor,
                  ],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/logo/logo.png',
                    width: 210,
                    height: 84,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Lichen Dreams',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.home_rounded, color: AppTheme.primaryGreen),
              title: Text('Inicio', style: GoogleFonts.poppins()),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(Icons.eco_rounded, color: AppTheme.primaryGreen),
              title: Text('Lichenpedia', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.liquenpedia);
              },
            ),
            ListTile(
              leading: Icon(Icons.person_rounded, color: AppTheme.primaryGreen),
              title: Text('Perfil', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.perfil);
              },
            ),
            if (_userRole == 'admin')
              ListTile(
                leading: Icon(
                  Icons.admin_panel_settings_rounded,
                  color: AppTheme.primaryGreen,
                ),
                title: Text('Administración', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AppRoutes.adminUsers);
                },
              ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout_rounded, color: AppTheme.primaryGreen),
              title: Text('Cerrar sesión', style: GoogleFonts.poppins()),
              onTap: () async {
                await _apiService.clearAuth();
                if (!mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.login,
                  (_) => false,
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          _navigateToSection(index);
        },
        backgroundColor: AppTheme.surfaceColor,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryGreen,
        unselectedItemColor: AppTheme.textGray,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt_rounded),
            label: 'Análisis',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Mapa'),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'Historial',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
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

        final stats = snapshot.data!;
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
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatsCard(
                    title: 'Zonas',
                    value: stats.zoneCount.toString(),
                    icon: Icons.location_on_rounded,
                    color: AppTheme.accentGreen,
                    backgroundColor: AppTheme.accentGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatsCard(
                    title: 'Aire',
                    value: stats.airQuality,
                    icon: Icons.air_rounded,
                    color: AppTheme.lightGreen,
                    backgroundColor: AppTheme.lightGreen,
                  ),
                ),
              ],
            ),
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
          title: 'Liquenpedia',
          description: 'Aprende sobre líquenes y el ambiente',
          icon: Icons.school_rounded,
          color: AppTheme.lightGreen,
          onTap: () => Navigator.pushNamed(context, AppRoutes.liquenpedia),
        ),
      ],
    );
  }

  Widget _buildLichenpediaHeader() {
    return Row(
      children: [
        Container(
          width: 4,
          height: 28,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryGreen, AppTheme.lightGreen],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lichenpedia',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Explora el conocimiento de los líquenes',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textGray,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryGreen.withValues(alpha: 0.12),
                AppTheme.lightGreen.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.school_rounded,
            size: 20,
            color: AppTheme.primaryGreen,
          ),
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

class _ParticleBackground extends StatefulWidget {
  const _ParticleBackground();

  @override
  State<_ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<_ParticleBackground>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);

    for (int i = 0; i < 12; i++) {
      _particles.add(_Particle(delay: Duration(milliseconds: i * 200)));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ParticlePainter(particles: _particles, animation: _controller),
      size: Size.infinite,
    );
  }
}

class _Particle {
  final Duration delay;
  _Particle({required this.delay});
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final Animation<double> animation;

  _ParticlePainter({required this.particles, required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryGreen.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;

    final breathe = 1.0 + 0.2 * math.sin(animation.value * math.pi * 2);

    for (int i = 0; i < particles.length; i++) {
      final progress = (i / particles.length);
      final yOffset = progress * size.height;
      final xOffset =
          size.width * 0.1 + (size.width * 0.8) * (progress * breathe);
      final radius = 1.5 + 1.0 * math.sin(progress * math.pi);

      canvas.drawCircle(Offset(xOffset, yOffset), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
