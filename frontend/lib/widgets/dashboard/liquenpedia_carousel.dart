import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/liquenpedia_article.dart';
import '../../services/api_service.dart';
import '../../config/app_config.dart';
import '../app_theme.dart';

class LiquenpediaCarousel extends StatefulWidget {
  const LiquenpediaCarousel({super.key});

  @override
  State<LiquenpediaCarousel> createState() => _LiquenpediaCarouselState();
}

class _LiquenpediaCarouselState extends State<LiquenpediaCarousel> {
  final PageController _pageController = PageController();
  final ApiService _apiService = ApiService();
  int _currentPage = 0;
  List<LiquenpediaArticle> _articles = [];
  bool _loading = true;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  Future<void> _loadArticles() async {
    try {
      final items = await _apiService.getLiquenpediaArticles();
      final published = items
          .map((json) => LiquenpediaArticle.fromJson(json))
          .where((a) => a.estadoPublicacion == 'published')
          .toList();

      setState(() {
        _articles = published.take(5).toList();
        _loading = false;
      });

      _startAutoScroll();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_articles.isEmpty) return;
      final next = (_currentPage + 1) % _articles.length;
      _pageController.animateToPage(
        next,
        duration: 400.ms,
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 240,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryGreen),
        ),
      );
    }

    if (_articles.isEmpty) {
      return Container(
        height: 240,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryGreen.withValues(alpha: 0.06),
              AppTheme.lightGreen.withValues(alpha: 0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.borderColor.withValues(alpha: 0.5),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.school_rounded,
                size: 40,
                color: AppTheme.primaryGreen.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 12),
              Text(
                'No hay artículos publicados',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textGray,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          height: 240,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: PageView.builder(
            controller: _pageController,
            itemCount: _articles.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              return _buildArticleCard(_articles[index], index);
            },
          ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.96, 0.96), duration: 600.ms),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _articles.length,
            (index) {
              final isActive = _currentPage == index;
              return AnimatedContainer(
                duration: 300.ms,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: isActive ? 10 : 7,
                height: isActive ? 10 : 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? AppTheme.primaryGreen : Colors.transparent,
                  border: Border.all(
                    color: isActive ? AppTheme.primaryGreen : AppTheme.borderColor,
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

  Widget _buildArticleCard(LiquenpediaArticle article, int index) {
    final imageUrl = article.imagenArticulo;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryGreen.withValues(alpha: 0.10),
            AppTheme.lightGreen.withValues(alpha: 0.05),
            AppTheme.accentGreen.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.primaryGreen.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             if (imageUrl != null && imageUrl.isNotEmpty)
               Container(
                 height: 110,
                 width: double.infinity,
                 decoration: BoxDecoration(
                   color: AppTheme.primaryGreen.withValues(alpha: 0.05),
                 ),
                child: Image.network(
                  AppConfig.getImageUrl(imageUrl),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    print('[Image.network error] liquenpedia_carousel: $imageUrl\n$error');
                    return _buildPlaceholderCover();
                  },
                ),
             )
             else
               _buildPlaceholderCover(),
             Expanded(
               child: Container(
                 padding: const EdgeInsets.symmetric(
                   horizontal: 16,
                   vertical: 10,
                 ),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(
                       article.titulo,
                       style: GoogleFonts.poppins(
                         fontSize: 15,
                         fontWeight: FontWeight.w700,
                         color: AppTheme.textDark,
                         height: 1.3,
                       ),
                       maxLines: 2,
                       overflow: TextOverflow.ellipsis,
                     ),
                     const SizedBox(height: 4),
                     Text(
                       article.categoria,
                       style: GoogleFonts.poppins(
                         fontSize: 9,
                         fontWeight: FontWeight.w600,
                         color: AppTheme.primaryGreen,
                       ),
                       maxLines: 1,
                       overflow: TextOverflow.ellipsis,
                     ),
                     const SizedBox(height: 4),
                     Text(
                       article.contenido.length > 60
                           ? '${article.contenido.substring(0, 60)}...'
                           : article.contenido,
                       style: GoogleFonts.poppins(
                         fontSize: 10,
                         fontWeight: FontWeight.w400,
                         color: AppTheme.textGray,
                         height: 1.3,
                       ),
                       maxLines: 2,
                       overflow: TextOverflow.ellipsis,
                     ),
                     const SizedBox(height: 4),
                     Text(
                       'Por ${article.autor}',
                       style: GoogleFonts.poppins(
                         fontSize: 9,
                         fontWeight: FontWeight.w400,
                         color: AppTheme.textGray.withValues(alpha: 0.7),
                       ),
                       maxLines: 1,
                       overflow: TextOverflow.ellipsis,
                     ),
                   ],
                 ),
               ),
             ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: (index * 80).ms);
  }

  Widget _buildPlaceholderCover() {
    return Container(
      height: 110,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryGreen.withValues(alpha: 0.15),
            AppTheme.lightGreen.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.eco_rounded,
          size: 36,
          color: AppTheme.primaryGreen.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}