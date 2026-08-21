import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/navigation_service.dart';
import '../widgets/app_theme.dart';
import '../widgets/lichen_app_bar.dart';
import '../widgets/lichen_bottom_nav.dart';
import '../widgets/lichen_drawer.dart';

class LichenScaffold extends StatefulWidget {
  final Widget body;
  final String? userRole;
  final ApiService? apiService;
  final int? bottomNavIndex;
  final ValueChanged<int>? onBottomNavTap;
  final bool showBottomNav;
  final bool showDrawer;
  final bool showParticleBackground;
  final bool isFullScreen;
  final PreferredSizeWidget? appBar;
  final bool bodyIsScrollable;

  const LichenScaffold({
    super.key,
    required this.body,
    this.userRole,
    this.apiService,
    this.bottomNavIndex,
    this.onBottomNavTap,
    this.showBottomNav = true,
    this.showDrawer = true,
    this.showParticleBackground = false,
    this.isFullScreen = false,
    this.appBar,
    this.bodyIsScrollable = false,
  });

  @override
  State<LichenScaffold> createState() => _LichenScaffoldState();
}

class _LichenScaffoldState extends State<LichenScaffold> with TickerProviderStateMixin {
  bool _isBottomNavVisible = true;
  late AnimationController _bottomNavController;

  @override
  void initState() {
    super.initState();
    _bottomNavController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    if (_isBottomNavVisible && widget.showBottomNav) {
      _bottomNavController.value = 1.0;
    } else {
      _bottomNavController.value = 0.0;
    }
  }

  @override
  void didUpdateWidget(covariant LichenScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showBottomNav != oldWidget.showBottomNav) {
      if (widget.showBottomNav) {
        _isBottomNavVisible = true;
        _bottomNavController.animateTo(1.0);
      } else {
        _isBottomNavVisible = false;
        _bottomNavController.animateTo(0.0);
      }
    }
  }

  @override
  void dispose() {
    _bottomNavController.dispose();
    super.dispose();
  }

  double get _bottomNavOffset {
    if (!widget.showBottomNav) return -140;
    final value = _bottomNavController.value;
    return -140 * (1 - value);
  }

  void _toggleBottomNav(bool visible) {
    if (_isBottomNavVisible == visible) return;
    _isBottomNavVisible = visible;
    if (visible) {
      _bottomNavController.animateTo(1.0);
    } else {
      _bottomNavController.animateTo(0.0);
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final axisDirection = notification.metrics.axisDirection;
      final isVertical = axisDirection == AxisDirection.down ||
          axisDirection == AxisDirection.up;
      if (!isVertical) return false;

      final delta = notification.scrollDelta ?? 0;
      if (delta.abs() < 0.5) return false;

      if (delta > 0 && _isBottomNavVisible) {
        _toggleBottomNav(false);
      } else if (delta < 0 && !_isBottomNavVisible) {
        _toggleBottomNav(true);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isScrollable = _isScrollableWidget(widget.body);
    Widget bodyContent;
    if (widget.isFullScreen) {
      bodyContent = SizedBox.expand(child: widget.body);
    } else if (!isScrollable && !widget.bodyIsScrollable) {
      bodyContent = SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: widget.body,
      );
    } else {
      bodyContent = widget.body;
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: widget.appBar ?? const LichenAppBar(),
      endDrawer: widget.showDrawer
          ? ValueListenableBuilder<int>(
              valueListenable: LichenNavigation.instance.selectedIndex,
              builder: (context, currentIndex, child) {
                return LichenDrawer(
                  userRole: widget.userRole,
                  apiService: widget.apiService ?? Provider.of<ApiService>(context, listen: false),
                  selectedIndex: currentIndex,
                );
              },
            )
          : null,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          if (widget.showParticleBackground) ...[
            Positioned.fill(
              child: IgnorePointer(
                child: ParticleBackground(),
              ),
            ),
          ],
          AnimatedBuilder(
            animation: _bottomNavController,
            child: bodyContent,
            builder: (context, child) {
              final bottomPadding = widget.showBottomNav
                  ? (16 + 84 * _bottomNavController.value)
                  : 0.0;
              final padding = EdgeInsets.fromLTRB(16, 16, 16, bottomPadding);

              return Positioned.fill(
                child: SafeArea(
                  bottom: false,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onScrollNotification,
                    child: Padding(padding: padding, child: child),
                  ),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _bottomNavController,
            builder: (context, child) {
              return Positioned(
                left: 0,
                right: 0,
                bottom: _bottomNavOffset,
                child: IgnorePointer(
                  ignoring: !_isBottomNavVisible || !widget.showBottomNav,
                  child: child!,
                ),
              );
            },
            child: ValueListenableBuilder<int>(
              valueListenable: LichenNavigation.instance.selectedIndex,
              builder: (context, currentIndex, child) {
                return LichenBottomNav(
                  currentIndex: currentIndex,
                  onTap: (index) {
                    widget.onBottomNavTap?.call(index);
                    _toggleBottomNav(true);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _isScrollableWidget(Widget widget) {
    return widget is ListView ||
        widget is GridView ||
        widget is CustomScrollView ||
        widget is SingleChildScrollView ||
        widget is NestedScrollView ||
        widget is RefreshIndicator ||
        widget is Consumer ||
        widget is Selector ||
        widget is AnimatedBuilder ||
        widget is ValueListenableBuilder;
  }
}

class ParticleBackground extends StatefulWidget {
  const ParticleBackground({super.key});

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
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