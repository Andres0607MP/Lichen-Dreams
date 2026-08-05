import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../app_theme.dart';

class LichenCarousel extends StatefulWidget {
  const LichenCarousel({super.key});

  @override
  State<LichenCarousel> createState() => _LichenCarouselState();
}

class _LichenCarouselState extends State<LichenCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<String> _carouselImages = [
    'assets/background/liquenes.png',
    'assets/background/bioindicadores.png',
    'assets/logo/logo.png',
  ];

  final List<Map<String, dynamic>> _slides = [
    {
      'description':
          'Organismos formados por la unión de un hongo y un organismo fotosintético.',
      'color': AppTheme.primaryGreen,
    },
    {
      'description':
          'Los líquenes permiten conocer la calidad del aire porque reaccionan a los cambios ambientales.',
      'color': AppTheme.lightGreen,
    },
    {
      'description':
          'Explora cómo los líquenes ayudan a comprender nuestro entorno.',
      'color': AppTheme.darkGreen,
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page?.round() ?? 0;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 240,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final slide = _slides[index];
              return _buildSlide(slide, index);
            },
          ).animate().fadeIn(duration: 600.ms).scale(duration: 600.ms),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _slides.length,
            (index) {
              final isActive = _currentPage == index;
              final slideColor = _slides[index]['color'] as Color;
              return AnimatedContainer(
                duration: 300.ms,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: isActive ? 10 : 7,
                height: isActive ? 10 : 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? slideColor : Colors.transparent,
                  border: Border.all(
                    color: isActive ? slideColor : AppTheme.borderColor,
                    width: isActive ? 0 : 1.5,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildSlide(Map<String, dynamic> slide, int index) {
    final color = slide['color'] as Color;
    final imagePath = _carouselImages[index];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildFallbackBackground(color),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      color.withValues(alpha: 0.3),
                      color.withValues(alpha: 0.85),
                    ],
                    stops: const [0.0, 0.5, 0.7, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color.withValues(alpha: 0.0),
                      color.withValues(alpha: 0.25),
                    ],
                  ),
                ),
                child: Text(
                  slide['description'] as String,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackBackground(Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.2),
            color.withValues(alpha: 0.06),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.eco_rounded,
          size: 48,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}