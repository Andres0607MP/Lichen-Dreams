import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';
import '../widgets/app_theme.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  bool _bootstrapStarted = false;

  late AnimationController _pulseController;
  late AnimationController _rotationController;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_bootstrapStarted) {
        _startBootstrap();
      }
    });
  }

  void _startBootstrap() {
    if (_bootstrapStarted || !mounted) return;
    _bootstrapStarted = true;
    final authState = context.read<AuthState>();
    unawaited(authState.bootstrapAndDecide(context));
  }

  void _retryBootstrap() {
    if (!mounted) return;
    final authState = context.read<AuthState>();
    unawaited(authState.bootstrapAndDecide(context));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 600;

    return Theme(
      data: AppTheme.lightTheme(),
      child: Scaffold(
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
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!isSmallScreen)
                              SizedBox(height: constraints.maxHeight * 0.1),
                            _buildLogo(),
                            SizedBox(height: isSmallScreen ? 20 : 32),
                            _buildTitle(),
                            SizedBox(height: isSmallScreen ? 32 : 48),
                            _buildLoader(authState),
                            SizedBox(height: isSmallScreen ? 16 : 24),
                            _buildSubtitle(authState),
                            if (!isSmallScreen)
                              SizedBox(height: constraints.maxHeight * 0.15),
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
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    final colorScheme = Theme.of(context).colorScheme;
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
                color: colorScheme.onPrimary.withValues(alpha: 0.05),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLogo() {
    final colorScheme = Theme.of(context).colorScheme;
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
                    color: colorScheme.onPrimary.withValues(alpha: 0.12),
                    border: Border.all(
                      color: colorScheme.onPrimary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.onPrimary.withValues(alpha: 0.1),
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
                      color: colorScheme.onPrimary.withValues(alpha: 0.95),
                    ),
                  ),
                ),
              ),
            );
          },
        )
        .animate()
        .scale(duration: 800.ms, curve: Curves.easeOutBack)
        .fadeIn(duration: 600.ms);
  }

  Widget _buildTitle() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  colorScheme.onPrimary,
                  colorScheme.onPrimary.withValues(alpha: 0.9),
                  AppTheme.accentGreen,
                ],
              ).createShader(bounds),
              child: Text(
                'Lichen Dreams',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            )
            .animate()
            .fadeIn(duration: 600.ms, delay: 200.ms)
            .slideY(begin: 0.2, duration: 600.ms),
        const SizedBox(height: 8),
        Text(
              'Lee el aire, entiende tu entorno',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colorScheme.onPrimary.withValues(alpha: 0.75),
                letterSpacing: 0.3,
              ),
            )
            .animate()
            .fadeIn(duration: 600.ms, delay: 400.ms)
            .slideY(begin: 0.15, duration: 600.ms),
      ],
    );
  }

  Widget _buildLoader(AuthState authState) {
    if (authState.bootstrapStatus == BootstrapStatus.error) {
      return _buildErrorState(authState);
    }

    return Column(
      children: [
        _buildAnimatedLoader(),
        const SizedBox(height: 20),
        _buildLoadingMessage(authState),
      ],
    );
  }

  Widget _buildAnimatedLoader() {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.onPrimary.withValues(alpha: 0.08),
                border: Border.all(
                  color: colorScheme.onPrimary.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.onPrimary.withValues(
                      alpha: 0.7 + (_pulseController.value * 0.3),
                    ),
                  ),
                ),
              ),
            );
          },
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .scale(duration: 600.ms, curve: Curves.easeOut);
  }

  Widget _buildLoadingMessage(AuthState authState) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _pulseController,
          child: Text(
            authState.bootstrapMessage,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colorScheme.onPrimary.withValues(alpha: 0.85),
            ),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }

  Widget _buildErrorState(AuthState authState) {
    final colorScheme = Theme.of(context).colorScheme;
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
                color: colorScheme.onPrimary.withValues(alpha: 0.1),
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
            authState.bootstrapMessage,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colorScheme.onPrimary.withValues(alpha: 0.95),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Verifica tu conexión o intenta nuevamente.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: colorScheme.onPrimary.withValues(alpha: 0.7),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Semantics(
            button: true,
            label: 'Reintentar',
            child: ElevatedButton(
              onPressed: _bootstrapStarted ? _retryBootstrap : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.onPrimary,
                foregroundColor: AppTheme.darkGreen,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 4,
                shadowColor: colorScheme.shadow.withValues(alpha: 0.3),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Reintentar'),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, duration: 400.ms);
  }

  Widget _buildSubtitle(AuthState authState) {
    final colorScheme = Theme.of(context).colorScheme;
    final message = authState.bootstrapStatus == BootstrapStatus.retrying
        ? 'El servidor se está iniciando...'
        : 'Preparando tu sesión...';
    return Semantics(
      label: message,
      child: Text(
        message,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: colorScheme.onPrimary.withValues(alpha: 0.5),
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
      canvas.drawCircle(Offset(offsetX, offsetY), shapeRadius, paint);
    }

    paint.color = color.withValues(alpha: 0.5);
    for (int i = 0; i < 5; i++) {
      final angle = -(rotation * 2 * 3.14159) + (i * 1.256);
      final offsetX = center.dx + (radius * 0.7 * _cos(angle));
      final offsetY = center.dy + (radius * 0.7 * _sin(angle));

      final shapeRadius = (15 + (pulse * 10)) * (1 + i * 0.2);
      canvas.drawCircle(Offset(offsetX, offsetY), shapeRadius, paint);
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
