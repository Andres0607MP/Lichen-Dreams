import 'package:flutter/foundation.dart';
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

class _LoadingScreenState extends State<LoadingScreen> with TickerProviderStateMixin {
  String? _errorMessage;
  bool _hasNavigated = false;
  bool _isLoading = false;
  int _backgroundTasks = 0;
  String? _lastUserToken;
  final List<String> _loadLog = [];
  static const Duration _criticalTimeout = Duration(seconds: 4);
  static const Duration _backgroundTimeout = Duration(seconds: 6);
  static const Duration _mapTimeout = Duration(seconds: 10);
  int _backgroundGeneration = 0;

  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _messageController;
  int _currentMessageIndex = 0;

  static const List<String> _loadingMessages = [
    'Validando sesión...',
    'Preparando tu perfil...',
    'Analizando datos ambientales...',
    'Cargando tu ecosistema...',
    'Conectando con la naturaleza...',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _messageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasNavigated) {
        _preloadAndNavigate();
        _cycleMessages();
      }
    });
  }

  void _cycleMessages() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _errorMessage == null && !_hasNavigated) {
        _messageController.forward().then((_) {
          if (mounted) {
            _currentMessageIndex = (_currentMessageIndex + 1) % _loadingMessages.length;
            _messageController.reset();
            _cycleMessages();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _backgroundGeneration++;
    _pulseController.dispose();
    _rotationController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _log(String message) {
    if (kDebugMode) {
      _loadLog.add(message);
    }
  }

  void _printLog(String message) {
    if (kDebugMode) {
      debugPrint('[LoadingScreen] $message');
    }
  }

  void _clearLoadState() {
    _loadLog.clear();
  }

  Future<void> _safeReset(String label, Future<void> Function() resetFn) async {
    try {
      await resetFn();
      _log('$label: reset OK');
    } catch (e) {
      _log('$label: reset ERROR - ${e.toString()}');
    }
  }

  Future<void> _preloadAndNavigate() async {
    if (_hasNavigated || !mounted || _isLoading) return;
    _isLoading = true;

    try {
      final authState = context.read<AuthState>();
      final currentToken = authState.token;
      final isLogout = currentToken == null || currentToken.isEmpty;
      final hadPreviousSession = _lastUserToken != null && _lastUserToken!.isNotEmpty;
      final isSessionChange = hadPreviousSession && _lastUserToken != currentToken;
      final isInitialLogin = _lastUserToken == null && !isLogout;

      if (isLogout) {
        _log('session: logout detected');
        if (hadPreviousSession) {
          _backgroundGeneration++;
          await _resetAllProviders();
        }
        _lastUserToken = null;
        if (!mounted) return;
        setState(() {
          _errorMessage = null;
        });
        return;
      }

      if (isInitialLogin) {
        _log('session: initial login');
        _lastUserToken = currentToken;
      } else if (isSessionChange) {
        _log('session: user changed');
        _backgroundGeneration++;
        _lastUserToken = currentToken;
        await _resetAllProviders();
      }

      if (!mounted) return;

      final sw = Stopwatch()..start();
      _clearLoadState();

      Future<void> timed(String label, Future<void> Function() fn) async {
        final t0 = DateTime.now();
        try {
          await fn();
          final dt = DateTime.now().difference(t0).inMilliseconds;
          _log('$label: ${dt}ms');
        } catch (e) {
          final dt = DateTime.now().difference(t0).inMilliseconds;
          _log('$label: ERROR after ${dt}ms');
        }
      }

      bool criticalSuccess = true;
      String? criticalError;

      try {
        await Future.wait([
          timed('ProfileState', () => context.read<ProfileState>().loadProfile().timeout(_criticalTimeout)),
          timed('DashboardState', () => context.read<DashboardState>().loadStats().timeout(_criticalTimeout)),
        ]);
      } catch (e) {
        criticalSuccess = false;
        criticalError = e.toString();
      }

      if (!mounted) return;

      if (!criticalSuccess) {
        _printLog('critical failed: $criticalError');
        for (final entry in _loadLog) {
          _printLog(entry);
        }
        setState(() {
          _errorMessage = criticalError;
        });
        return;
      }

      if (_hasNavigated) return;
      _hasNavigated = true;

      for (final entry in _loadLog) {
        _printLog(entry);
      }
      _printLog('critical total: ${sw.elapsedMilliseconds}ms');

      final historyState = context.read<HistoryState>();
      final articlesState = context.read<ArticlesState>();
      final mapState = context.read<MapState>();

      Navigator.pushReplacementNamed(context, AppRoutes.dashboard);

      final bgGeneration = _backgroundGeneration;
      _backgroundTasks++;

      Future.microtask(() async {
        if (!mounted || bgGeneration != _backgroundGeneration) {
          if (kDebugMode && bgGeneration != _backgroundGeneration) {
            debugPrint('[LoadingScreen] background: cancelled (stale generation $bgGeneration)');
          }
          _backgroundTasks--;
          return;
        }

        final t0 = DateTime.now();
        try {
          await Future.wait([
            timed('HistoryState', () => historyState.loadHistory().timeout(_backgroundTimeout)),
            timed('ArticlesState', () => articlesState.loadArticles().timeout(_backgroundTimeout)),
            timed('MapState', () => mapState.loadPoints().timeout(_mapTimeout)),
          ]);
        } catch (_) {
          _printLog('background: ERROR after ${DateTime.now().difference(t0).inMilliseconds}ms');
        }

        if (!mounted || bgGeneration != _backgroundGeneration) {
          _backgroundTasks--;
          return;
        }

        sw.stop();
        for (final entry in _loadLog) {
          _printLog(entry);
        }
        _printLog('total: ${sw.elapsedMilliseconds}ms');
        _backgroundTasks--;
      });
    } finally {
      if (mounted) {
        _isLoading = _backgroundTasks > 0;
      }
    }
  }

  Future<void> _resetAllProviders() async {
    final providers = <String, Future<void> Function()>{
      'ProfileState': () => context.read<ProfileState>().reset(),
      'DashboardState': () => context.read<DashboardState>().reset(),
      'HistoryState': () => context.read<HistoryState>().reset(),
      'ArticlesState': () => context.read<ArticlesState>().reset(),
      'NotificationsState': () => context.read<NotificationsState>().reset(),
      'AnalysisState': () => context.read<AnalysisState>().reset(),
      'MapState': () => context.read<MapState>().reset(),
    };

    for (final entry in providers.entries) {
      if (!mounted) return;
      await _safeReset(entry.key, entry.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 600;

    return Scaffold(
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          Positioned.fill(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!isSmallScreen) SizedBox(height: constraints.maxHeight * 0.1),
                          _buildLogo(),
                          SizedBox(height: isSmallScreen ? 20 : 32),
                          _buildTitle(),
                          SizedBox(height: isSmallScreen ? 32 : 48),
                          _buildLoader(),
                          SizedBox(height: isSmallScreen ? 16 : 24),
                          _buildSubtitle(),
                          if (!isSmallScreen) SizedBox(height: constraints.maxHeight * 0.15),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.darkGreen,
              AppTheme.primaryGreen.withValues(alpha: 0.85),
              AppTheme.darkGreen.withValues(alpha: 0.9),
            ],
          ),
        ),
        child: AnimatedBuilder(
          animation: _rotationController,
          builder: (context, child) {
            return CustomPaint(
              painter: _OrganicBackgroundPainter(
                rotation: _rotationController.value,
                pulse: _pulseController.value,
                color: Colors.white.withValues(alpha: 0.03),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.05);
        return Transform.scale(
          scale: scale,
          child: Semantics(
            label: 'Lichen Dreams Logo',
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.1),
                    blurRadius: 20 + (_pulseController.value * 10),
                    spreadRadius: 2 + (_pulseController.value * 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Image.asset(
                  'assets/logo/logo.png',
                  fit: BoxFit.contain,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
            ),
          ),
        );
      },
    ).animate().scale(duration: 800.ms, curve: Curves.easeOutBack).fadeIn(duration: 600.ms);
  }

  Widget _buildTitle() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              Colors.white,
              Colors.white.withValues(alpha: 0.9),
              AppTheme.accentGreen,
            ],
          ).createShader(bounds),
          child: Text(
            'Lichen Dreams',
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 200.ms).slideY(begin: 0.2, duration: 600.ms),
        const SizedBox(height: 8),
        Text(
          'Lee el aire, entiende tu entorno',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.75),
            letterSpacing: 0.3,
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 400.ms).slideY(begin: 0.15, duration: 600.ms),
      ],
    );
  }

  Widget _buildLoader() {
    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return Column(
      children: [
        _buildAnimatedLoader(),
        const SizedBox(height: 20),
        _buildLoadingMessage(),
      ],
    );
  }

  Widget _buildAnimatedLoader() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white.withValues(alpha: 0.7 + (_pulseController.value * 0.3)),
              ),
            ),
          ),
        );
      },
    ).animate().fadeIn(duration: 400.ms).scale(duration: 600.ms, curve: Curves.easeOut);
  }

  Widget _buildLoadingMessage() {
    return AnimatedBuilder(
      animation: _messageController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _messageController,
          child: Text(
            _loadingMessages[_currentMessageIndex],
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.85),
            ),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Semantics(
            label: 'Error de conexión',
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 32,
                color: Colors.orange,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No fue posible cargar toda la información',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.95),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Puedes continuar, pero algunos datos podrían estar desactualizados.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Semantics(
            button: true,
            label: 'Reintentar carga',
            child: ElevatedButton(
              onPressed: () {
                setState(() => _errorMessage = null);
                _clearLoadState();
                _preloadAndNavigate();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.darkGreen,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 4,
                shadowColor: Colors.black.withValues(alpha: 0.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Reintentar',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, duration: 400.ms);
  }

  Widget _buildSubtitle() {
    return Semantics(
      label: 'Cargando, por favor espere',
      child: Text(
        'Conectando con tu ecosistema...',
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: Colors.white.withValues(alpha: 0.5),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 600.ms);
  }
}

class _OrganicBackgroundPainter extends CustomPainter {
  final double rotation;
  final double pulse;
  final Color color;

  _OrganicBackgroundPainter({
    required this.rotation,
    required this.pulse,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.6;

    for (int i = 0; i < 3; i++) {
      final angle = (rotation * 2 * 3.14159) + (i * 2.094);
      final offsetX = center.dx + (radius * 0.5 * _cos(angle));
      final offsetY = center.dy + (radius * 0.5 * _sin(angle));

      final shapeRadius = (40 + (pulse * 20)) * (1 + i * 0.3);
      canvas.drawCircle(
        Offset(offsetX, offsetY),
        shapeRadius,
        paint,
      );
    }

    paint.color = color.withValues(alpha: 0.5);
    for (int i = 0; i < 5; i++) {
      final angle = -(rotation * 2 * 3.14159) + (i * 1.256);
      final offsetX = center.dx + (radius * 0.7 * _cos(angle));
      final offsetY = center.dy + (radius * 0.7 * _sin(angle));

      final shapeRadius = (15 + (pulse * 10)) * (1 + i * 0.2);
      canvas.drawCircle(
        Offset(offsetX, offsetY),
        shapeRadius,
        paint,
      );
    }
  }

  double _cos(double angle) {
    return _customCos(angle);
  }

  double _sin(double angle) {
    return _customSin(angle);
  }

  @override
  bool shouldRepaint(covariant _OrganicBackgroundPainter oldDelegate) {
    return oldDelegate.rotation != rotation || oldDelegate.pulse != pulse;
  }

  static double _customCos(double x) {
    x = x % (2 * 3.14159);
    double result = 1;
    double term = 1;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }

  static double _customSin(double x) {
    x = x % (2 * 3.14159);
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }
}
