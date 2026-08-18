import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';
import '../state/profile_state.dart';
import '../state/dashboard_state.dart';
import '../state/history_state.dart';
import '../state/map_state.dart';
import '../state/articles_state.dart';
import '../state/notifications_state.dart';
import '../state/analysis_state.dart';
import '../routes/route_names.dart';
import '../widgets/app_theme.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  String? _errorMessage;
  bool _hasNavigated = false;
  String? _lastUserToken;
  final List<String> _loadLog = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasNavigated) {
        _preloadAndNavigate();
      }
    });
  }

  Future<void> _preloadAndNavigate() async {
    if (_hasNavigated || !mounted) return;

    final authState = context.read<AuthState>();
    if (_lastUserToken != null && _lastUserToken != authState.token) {
      _lastUserToken = authState.token;
      await Future.wait([
        context.read<ProfileState>().reset(),
        context.read<DashboardState>().reset(),
        context.read<HistoryState>().reset(),
        context.read<ArticlesState>().reset(),
        context.read<NotificationsState>().reset(),
        context.read<AnalysisState>().reset(),
        context.read<MapState>().reset(),
      ]);
    }

    final sw = Stopwatch()..start();

    Future<void> timed(String label, Future<void> Function() fn) async {
      final t0 = DateTime.now();
      try {
        await fn();
        final dt = DateTime.now().difference(t0).inMilliseconds;
        _loadLog.add('$label: ${dt}ms');
      } catch (e) {
        final dt = DateTime.now().difference(t0).inMilliseconds;
        _loadLog.add('$label: ERROR after ${dt}ms - ${e.toString()}');
      }
    }

    try {
      await Future.wait([
        timed('ProfileState', () => context.read<ProfileState>().loadProfile()),
        timed('DashboardState', () => context.read<DashboardState>().loadStats().timeout(const Duration(seconds: 4))),
      ]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
      return;
    }

    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    for (final entry in _loadLog) {
      debugPrint('[LoadingScreen] $entry');
    }
    debugPrint('[LoadingScreen] critical total: ${sw.elapsedMilliseconds}ms');
    Navigator.pushReplacementNamed(context, AppRoutes.dashboard);

    final MapState mapState = context.read<MapState>();
    Future.microtask(() async {
      if (!mounted) return;
      final t0 = DateTime.now();
      try {
        await Future.wait([
          timed('HistoryState', () => context.read<HistoryState>().loadHistory()),
          timed('ArticlesState', () => context.read<ArticlesState>().loadArticles()),
          timed('MapState', () => mapState.loadPoints()),
        ]);
      } catch (_) {
        debugPrint('[LoadingScreen] background: ERROR');
      }
      if (!mounted) return;
      sw.stop();
      debugPrint('[LoadingScreen] total: ${sw.elapsedMilliseconds}ms');
      for (final entry in _loadLog) {
        debugPrint('[LoadingScreen] $entry');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.darkGreen,
                    AppTheme.primaryGreen.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),
                  _buildLogo(),
                  const SizedBox(height: 24),
                  _buildTitle(),
                  const SizedBox(height: 48),
                  _buildLoader(),
                  const SizedBox(height: 24),
                  _buildSubtitle(),
                  const Spacer(flex: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Image.asset(
          'assets/logo/logo.png',
          fit: BoxFit.contain,
        ),
      ),
    ).animate().scale(duration: 800.ms, curve: Curves.easeOutBack);
  }

  Widget _buildTitle() {
    return Column(
      children: [
        Text(
          'Lichen Dreams',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
        const SizedBox(height: 8),
        Text(
          'Lee el aire, entiende tu entorno',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 400.ms),
      ],
    );
  }

  Widget _buildLoader() {
    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 36,
              color: Colors.white70,
            ),
            const SizedBox(height: 16),
            Text(
              'No fue posible cargar toda la información',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Puedes continuar, pero algunos datos podrían estar desactualizados.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() => _errorMessage = null);
                _preloadAndNavigate();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.darkGreen,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                'Reintentar',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms);
    }

    return Column(
      children: [
        const SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 16),
        Text(
          'Cargando información...',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
      ],
    );
  }

  Widget _buildSubtitle() {
    return Text(
      'Esto tomará solo unos segundos',
      style: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: Colors.white.withValues(alpha: 0.6),
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 600.ms);
  }
}
