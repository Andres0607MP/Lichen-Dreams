import 'package:flutter/material.dart';

import '../routes/route_names.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  static const routeName = '/dashboard';

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<String> _connectionFuture;
  late Future<String?> _userRoleFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _connectionFuture = _apiService.testConnection();
    _userRoleFuture = _apiService.getSavedRole();
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  void _retryConnection() {
    setState(() {
      _connectionFuture = _apiService.testConnection();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () {},
        ),
        title: const Text(
          'Lichen Dreams',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_rounded),
            selectedIcon: Icon(Icons.search_rounded),
            label: 'Buscar',
          ),
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt_rounded),
            label: 'Analizar',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroSection(
                onLogout: () async {
                  await _apiService.clearAuth();
                  if (!mounted) return;
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.login,
                    (_) => false,
                  );
                },
              ),
              const SizedBox(height: 24),
              FutureBuilder<String?>(
                future: _userRoleFuture,
                builder: (context, snapshot) {
                  final isAdmin = snapshot.data == 'admin';
                  return _ActionGrid(showAdmin: isAdmin);
                },
              ),
              const SizedBox(height: 24),
              _ConnectionCard(
                connectionFuture: _connectionFuture,
                onRetry: _retryConnection,
              ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Últimas actividades',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _InfoCard(
                title: 'Análisis recientes',
                subtitle: 'Aquí aparecerán tus últimos análisis de liquen',
                trailing: const Icon(Icons.arrow_forward_rounded),
              ),
              const SizedBox(height: 12),
              _InfoCard(
                title: 'Mapa de zonas',
                subtitle: 'Resumen visual de tus puntos de análisis',
                trailing: const Icon(Icons.arrow_forward_rounded),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.connectionFuture,
    required this.onRetry,
  });

  final Future<String> connectionFuture;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade50],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE1E9DD), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2F7D32).withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEAF3E6), Color(0xFFDFF0DC)],
                  ),
                ),
                child: const Icon(
                  Icons.cloud_done_rounded,
                  color: Color(0xFF2F7D32),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Conexión con Backend',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF18301F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FutureBuilder<String>(
            future: connectionFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color(0xFF2F7D32).withOpacity(0.7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Probando conexión...',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              }

              if (snapshot.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reintentar'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          snapshot.data ?? 'Backend conectado correctamente',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: onRetry,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEAF3E6),
                    ),
                    child: const Text(
                      'Probar de nuevo',
                      style: TextStyle(color: Color(0xFF2F7D32)),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF3E6), Color(0xFFDFF0DC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2F7D32).withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bienvenido de vuelta',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF558B2F),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Lichen Dreams',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF18301F),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2F7D32), Color(0xFF1B5E20)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2F7D32).withOpacity(0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.eco_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Lee el aire, entiende tu entorno con datos precisos sobre calidad del aire',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF18301F),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.camera_alt_rounded, size: 20),
                  label: const Text('Tomar foto'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2F7D32),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.image_rounded, size: 20),
                  label: const Text('Galería'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF2F7D32), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Cerrar sesión'),
              style: TextButton.styleFrom(
                foregroundColor: Color(0xFF18301F).withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({this.showAdmin = false});

  final bool showAdmin;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(
        icon: Icons.document_scanner_outlined,
        label: 'Nuevo análisis',
        route: AppRoutes.analisis,
      ),
      _QuickAction(icon: Icons.map_outlined, label: 'Mapa interactivo', route: AppRoutes.mapa),
      if (showAdmin)
        _QuickAction(icon: Icons.group_rounded, label: 'Usuarios', route: AppRoutes.adminUsers),
      _QuickAction(icon: Icons.library_books_outlined, label: 'LichenPedia', route: AppRoutes.liquenpedia),
      _QuickAction(icon: Icons.info_outline_rounded, label: 'Resultados', route: AppRoutes.historial),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemBuilder: (_, index) => actions[index],
    );
  }
}

class _QuickAction extends StatefulWidget {
  const _QuickAction({required this.icon, required this.label, this.route});

  final IconData icon;
  final String label;
  final String? route;

  @override
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 0.95).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: MouseRegion(
        onEnter: (_) => _controller.forward(),
        onExit: (_) => _controller.reverse(),
        child: InkWell(
          onTap: widget.route == null
              ? null
              : () => Navigator.pushNamed(context, widget.route!),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE1E9DD), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2F7D32).withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEAF3E6), Color(0xFFDFF0DC)],
                    ),
                  ),
                  child: Icon(
                    widget.icon,
                    color: const Color(0xFF2F7D32),
                    size: 28,
                  ),
                ),
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF18301F),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatefulWidget {
  const _InfoCard({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  State<_InfoCard> createState() => _InfoCardState();
}

class _InfoCardState extends State<_InfoCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 1.02).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE1E9DD), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2F7D32).withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF18301F),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEAF3E6),
                ),
                child: IconTheme(
                  data: const IconThemeData(color: Color(0xFF2F7D32)),
                  child: widget.trailing,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
