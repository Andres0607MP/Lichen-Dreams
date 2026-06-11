import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../widgets/app_theme.dart';
import '../widgets/modern_widgets.dart';
import '../routes/route_names.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  late Future<String> _connectionFuture;
  String? _userRole;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _connectionFuture = _apiService.testConnection();
    _loadUserRole();
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
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(
                Icons.eco_rounded,
                color: AppTheme.primaryGreen,
                size: 28,
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
        actions: [
          if (_userRole == 'admin')
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.eco_outlined, color: Colors.orange),
                  tooltip: 'LichenPedia',
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.liquenpedia),
                ),
              ),
            ),
          if (_userRole == 'admin')
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.red,
                  ),
                  tooltip: 'Panel de administración',
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.adminUsers),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppTheme.primaryGreen,
                ),
                onPressed: () {},
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.logout_rounded,
                  color: AppTheme.primaryGreen,
                ),
                onPressed: () async {
                  await _apiService.clearAuth();
                  if (!mounted) return;
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.login,
                    (_) => false,
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome section
            _buildWelcomeSection(),
            const SizedBox(height: 24),

            // Connection status
            _buildConnectionStatus(),
            const SizedBox(height: 24),

            // Stats section
            _buildStatsSection(),
            const SizedBox(height: 24),

            // Quick actions
            SectionHeader(
              title: 'Acciones rápidas',
              subtitle: 'Comienza tu análisis',
            ),
            const SizedBox(height: 12),
            _buildQuickActions(),
            const SizedBox(height: 24),

            // Featured features
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

  Widget _buildWelcomeSection() {
    return ModernCard(
      gradient: [AppTheme.primaryGreen, AppTheme.darkGreen],
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¡Bienvenido!',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Analiza líquenes y descubre la calidad del aire en tu entorno',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 16),
          ModernButton(
            label: 'Realizar análisis',
            onPressed: () => Navigator.pushNamed(context, '/analisis'),
            width: double.infinity,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildConnectionStatus() {
    return FutureBuilder<String>(
      future: _connectionFuture,
      builder: (context, snapshot) {
        final isConnected =
            snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData;
        final statusColor = isConnected ? AppTheme.accentGreen : Colors.orange;

        return ModernCard(
          backgroundColor: statusColor.withOpacity(0.05),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withOpacity(0.2),
                ),
                child: Icon(
                  isConnected
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConnected ? 'Conectado' : 'Reconectando...',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                    Text(
                      snapshot.data ?? 'Esperando conexión...',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textGray,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!isConnected)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatsCard(
                title: 'Análisis',
                value: '0',
                icon: Icons.analytics_rounded,
                color: AppTheme.primaryGreen,
                backgroundColor: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatsCard(
                title: 'Zonas',
                value: '0',
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
                value: '---',
                icon: Icons.air_rounded,
                color: Colors.amber,
                backgroundColor: Colors.amber,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatsCard(
                title: 'Racha',
                value: '0 días',
                icon: Icons.local_fire_department_rounded,
                color: Colors.orange,
                backgroundColor: Colors.orange,
              ),
            ),
          ],
        ),
      ],
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
            onTap: () => Navigator.pushNamed(context, '/analisis'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FeatureCard(
            title: 'Historial',
            description: 'Ver análisis',
            icon: Icons.history_rounded,
            color: AppTheme.accentGreen,
            onTap: () => Navigator.pushNamed(context, '/historial'),
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
          onTap: () => Navigator.pushNamed(context, '/analisis'),
        ),
        const SizedBox(height: 12),
        FeatureCard(
          title: 'Mapa interactivo',
          description: 'Visualiza todas las zonas analizadas',
          icon: Icons.map_rounded,
          color: Colors.teal,
          onTap: () => Navigator.pushNamed(context, '/mapa'),
        ),
        const SizedBox(height: 12),
        FeatureCard(
          title: 'Liquenpedia',
          description: 'Aprende sobre líquenes y el ambiente',
          icon: Icons.school_rounded,
          color: Colors.purple,
          onTap: () => Navigator.pushNamed(context, '/liquenpedia'),
        ),
      ],
    );
  }

  void _navigateToSection(int index) {
    switch (index) {
      case 1:
        Navigator.pushNamed(context, '/analisis');
        break;
      case 2:
        Navigator.pushNamed(context, '/mapa');
        break;
      case 3:
        Navigator.pushNamed(context, '/historial');
        break;
      case 4:
        Navigator.pushNamed(context, '/perfil');
        break;
    }
  }
}
