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
    'assets/background/liquenes.jpg',
    'assets/background/bioindicadores.jpg',
    'assets/logo/loguito.png',
  ];

  final List<Map<String, dynamic>> _slides = [
    {
      'title': '¿Qué son los líquenes?',
      'description':
          'Organismos formados por la unión de un hongo y un organismo fotosintético.',
      'color': AppTheme.darkGreen,
    },
    {
      'title': 'Bioindicadores Naturales',
      'description':
          'Los líquenes permiten conocer la calidad del aire porque reaccionan a los cambios ambientales.',
      'color': AppTheme.darkGreen,
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
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final adaptiveMaxHeight = 280.0 + (textScale - 1) * 100;
    return Column(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: 220,
            maxHeight: adaptiveMaxHeight,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final carouselHeight = constraints.maxHeight.clamp(220.0, adaptiveMaxHeight);
              return Container(
                height: carouselHeight,
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
              );
            },
          ),
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
                    stops: const [0.0, 0.4, 0.7, 1.0],
                  ),
                ),
              ),
            ),
if (slide['title'] != null)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment(0, -0.25),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      slide['title'] as String,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.3,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      softWrap: true,
                    ),
                  ),
                ),
              ),
              Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        color.withValues(alpha: 0.0),
                        color.withValues(alpha: 0.3),
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
                      height: 1.4,
                    ),
                    maxLines: 4,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                  ),
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