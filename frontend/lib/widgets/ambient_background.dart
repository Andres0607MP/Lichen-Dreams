import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';

// ============================================================
// CONTROLES DE VISIBILIDAD - Ajustar estos valores:
// ============================================================
// INTENSIDAD GLOBAL:
//   - Más visible: incrementar _globalAlphaMultiplier (ej: 1.5)
//   - Menos visible: decrementar (ej: 0.5)
//
// CANTIDAD DE GLOWS:
//   - Total = _mainGlows.length + _ambientGlows.length
//   - Actual: 3 principales + 9 ambientales = 12 total
//
// GLOWS PRINCIPALES:
//   - alpha: 0.15, 0.10, 0.08
//   - radius: 45-55px
//
// GLOWS AMBIENTALES:
//   - alpha: 0.04-0.10
//   - radius: 25-60px
//   - Más sutiles que los principales
//
// PARTÍCULAS:
//   - alpha: 0.12-0.18
//   - radius: 1.0-1.4px
// ============================================================

class AmbientBackground extends StatefulWidget {
  final bool showParticles;

  const AmbientBackground({
    super.key,
    this.showParticles = true,
  });

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  bool _isAnimating = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      duration: const Duration(seconds: 14),
      vsync: this,
    )..repeat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_isAnimating) {
          _controller.repeat();
          _isAnimating = true;
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        if (_isAnimating) {
          _controller.stop();
          _isAnimating = false;
        }
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _AmbientBackgroundPainter(
              progress: _controller.value,
              showParticles: widget.showParticles,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _GlowConfig {
  final double xPercent;
  final double yPercent;
  final double radius;
  final double alpha;
  final double speedX;
  final double speedY;
  final double driftX;
  final double driftY;
  final Color color;

  const _GlowConfig({
    required this.xPercent,
    required this.yPercent,
    required this.radius,
    required this.alpha,
    required this.speedX,
    required this.speedY,
    required this.driftX,
    required this.driftY,
    required this.color,
  });
}

class _AmbientBackgroundPainter extends CustomPainter {
  final double progress;
  final bool showParticles;

  // Multiplicador global de opacidad - ajustar para más/menos intensidad
  static const double _globalAlphaMultiplier = 2.0;

  // Configuración de los 3 glows principales (más visibles)
  static const List<_GlowConfig> _mainGlows = [
    _GlowConfig(
      xPercent: 0.22,
      yPercent: 0.15,
      radius: 55,
      alpha: 0.15,
      speedX: 0.08,
      speedY: 0.06,
      driftX: 25,
      driftY: 20,
      color: AppTheme.primaryGreen,
    ),
    _GlowConfig(
      xPercent: 0.78,
      yPercent: 0.42,
      radius: 45,
      alpha: 0.10,
      speedX: 0.06,
      speedY: 0.08,
      driftX: 22,
      driftY: 18,
      color: AppTheme.lightGreen,
    ),
    _GlowConfig(
      xPercent: 0.50,
      yPercent: 0.82,
      radius: 50,
      alpha: 0.08,
      speedX: 0.10,
      speedY: 0.05,
      driftX: 28,
      driftY: 22,
      color: AppTheme.accentGreen,
    ),
  ];

  // Configuración de 9 glows ambientales adicionales (más sutiles)
  static const List<_GlowConfig> _ambientGlows = [
    _GlowConfig(
      xPercent: 0.85,
      yPercent: 0.12,
      radius: 35,
      alpha: 0.07,
      speedX: 0.12,
      speedY: 0.09,
      driftX: 15,
      driftY: 12,
      color: AppTheme.lightGreen,
    ),
    _GlowConfig(
      xPercent: 0.12,
      yPercent: 0.88,
      radius: 40,
      alpha: 0.06,
      speedX: 0.09,
      speedY: 0.11,
      driftX: 18,
      driftY: 14,
      color: AppTheme.accentGreen,
    ),
    _GlowConfig(
      xPercent: 0.50,
      yPercent: 0.08,
      radius: 30,
      alpha: 0.08,
      speedX: 0.15,
      speedY: 0.07,
      driftX: 12,
      driftY: 10,
      color: AppTheme.primaryGreen,
    ),
    _GlowConfig(
      xPercent: 0.15,
      yPercent: 0.50,
      radius: 38,
      alpha: 0.05,
      speedX: 0.07,
      speedY: 0.13,
      driftX: 16,
      driftY: 11,
      color: AppTheme.lightGreen,
    ),
    _GlowConfig(
      xPercent: 0.85,
      yPercent: 0.75,
      radius: 42,
      alpha: 0.05,
      speedX: 0.11,
      speedY: 0.08,
      driftX: 14,
      driftY: 16,
      color: AppTheme.primaryGreen,
    ),
    _GlowConfig(
      xPercent: 0.35,
      yPercent: 0.65,
      radius: 28,
      alpha: 0.09,
      speedX: 0.18,
      speedY: 0.10,
      driftX: 20,
      driftY: 15,
      color: AppTheme.accentGreen,
    ),
    _GlowConfig(
      xPercent: 0.65,
      yPercent: 0.25,
      radius: 32,
      alpha: 0.06,
      speedX: 0.14,
      speedY: 0.12,
      driftX: 13,
      driftY: 17,
      color: AppTheme.lightGreen,
    ),
    _GlowConfig(
      xPercent: 0.50,
      yPercent: 0.50,
      radius: 48,
      alpha: 0.04,
      speedX: 0.08,
      speedY: 0.09,
      driftX: 22,
      driftY: 18,
      color: AppTheme.primaryGreen,
    ),
    _GlowConfig(
      xPercent: 0.25,
      yPercent: 0.35,
      radius: 25,
      alpha: 0.07,
      speedX: 0.20,
      speedY: 0.14,
      driftX: 10,
      driftY: 8,
      color: AppTheme.accentGreen,
    ),
  ];

  _AmbientBackgroundPainter({
    required this.progress,
    required this.showParticles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final time = progress * 2 * math.pi;
    final scaleFactor = _getScaleFactor(size);

    // Dibujar los 3 glows principales
    for (final glow in _mainGlows) {
      _drawAmbientGlow(
        canvas,
        size,
        config: glow,
        time: time,
        scaleFactor: scaleFactor,
        alphaMultiplier: _globalAlphaMultiplier,
      );
    }

    // Dibujar los 9 glows ambientales adicionales
    for (final glow in _ambientGlows) {
      _drawAmbientGlow(
        canvas,
        size,
        config: glow,
        time: time,
        scaleFactor: scaleFactor,
        alphaMultiplier: _globalAlphaMultiplier,
      );
    }

    if (showParticles) {
      _drawParticles(canvas, size, time);
    }
  }

  double _getScaleFactor(Size size) {
    final minDimension = math.min(size.width, size.height);
    if (minDimension < 400) return 0.7;
    if (minDimension < 700) return 0.85;
    if (minDimension < 1000) return 1.0;
    return 1.15;
  }

  void _drawAmbientGlow(
    Canvas canvas,
    Size size, {
    required _GlowConfig config,
    required double time,
    required double scaleFactor,
    required double alphaMultiplier,
  }) {
    // Calcular posición base según porcentajes de pantalla
    final baseX = size.width * config.xPercent;
    final baseY = size.height * config.yPercent;

    // Movimiento sutil con diferentes velocidades por eje
    final driftX = math.sin(time * config.speedX) * config.driftX;
    final driftY = math.cos(time * config.speedY) * config.driftY;

    // Pulso de escala suave (respiración)
    final pulse = 0.97 + math.sin(time * config.speedX * 0.5) * 0.03;

    // Pulso de opacidad suave
    final alphaPulse = config.alpha * (0.85 + math.sin(time * config.speedY * 0.7) * 0.15);

    final x = (baseX + driftX).clamp(config.radius * 0.5, size.width - config.radius * 0.5);
    final y = (baseY + driftY).clamp(config.radius * 0.5, size.height - config.radius * 0.5);
    final radius = config.radius * scaleFactor * pulse;
    final alpha = alphaPulse * alphaMultiplier;

    // Gradiente radial con transición suave a transparente
    final gradient = RadialGradient(
      colors: [
        config.color.withValues(alpha: alpha),
        config.color.withValues(alpha: alpha * 0.6),
        config.color.withValues(alpha: alpha * 0.2),
        config.color.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.3, 0.7, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: Offset(x, y), radius: radius),
      );

    canvas.drawCircle(Offset(x, y), radius, paint);
  }

  void _drawParticles(Canvas canvas, Size size, double time) {
    final particlePaint = Paint()..style = PaintingStyle.fill;

    const particleCount = 10;
    final scaleFactor = _getScaleFactor(size);

    for (int i = 0; i < particleCount; i++) {
      final seed = i * 1.618033988749895;
      final speed = 0.04 + (i % 3) * 0.015;

      final normalizedX = i / particleCount;
      final baseX = size.width * (0.08 + normalizedX * 0.84);
      final baseY = size.height * (0.12 + ((i * 0.17) % 0.76));

      final driftX =
          math.sin(time * speed + seed) * 25 + math.sin(time * speed * 1.3 + seed) * 10;
      final driftY = math.cos(time * speed * 0.5 + seed * 1.3) * 20 +
          math.sin(time * speed * 1.1 + seed * 0.7) * 8;

      final alpha = 0.12 + (math.sin(time * 0.12 + seed) * 0.06).abs();
      final radius = (1.0 + (i % 3) * 0.2) * scaleFactor;

      particlePaint.color = AppTheme.primaryGreen.withValues(alpha: alpha);

      final x = (baseX + driftX).clamp(0.0, size.width);
      final y = (baseY + driftY).clamp(0.0, size.height);

      canvas.drawCircle(Offset(x, y), radius, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.showParticles != showParticles;
  }
}
