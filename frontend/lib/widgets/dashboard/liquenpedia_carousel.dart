import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../models/liquenpedia_article.dart';
import '../../state/articles_state.dart';
import '../../state/auth_state.dart';
import '../../config/app_config.dart';
import '../../screens/liquenpedia_detail_screen.dart';
import '../../routes/route_names.dart';
import '../app_theme.dart';

Color _getCategoryColor(String categoria) {
  final normalized = categoria.toLowerCase().trim();
  if (normalized.contains('saludable') ||
      normalized.contains('healthy') ||
      normalized.contains('buena') ||
      normalized.contains('good') ||
      normalized.contains('excelente') ||
      normalized.contains('excellent')) {
    return AppTheme.articleHealthy;
  }
  if (normalized.contains('moderada') ||
      normalized.contains('moderate') ||
      normalized.contains('regular') ||
      normalized.contains('media')) {
    return AppTheme.articleModerate;
  }
  if (normalized.contains('crítica') ||
      normalized.contains('critical') ||
      normalized.contains('mala') ||
      normalized.contains('bad') ||
      normalized.contains('poor') ||
      normalized.contains('afectada') ||
      normalized.contains('affected')) {
    return AppTheme.articleCritical;
  }
  return AppTheme.articleDefault;
}

class LiquenpediaCarousel extends StatefulWidget {
  const LiquenpediaCarousel({super.key});

  @override
  State<LiquenpediaCarousel> createState() => _LiquenpediaCarouselState();
}

class _LiquenpediaCarouselState extends State<LiquenpediaCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final articlesState = context.read<ArticlesState>();
      final published = articlesState.articles
          .where((a) => a.estadoPublicacion == 'published')
          .take(5)
          .toList();
      if (published.isEmpty) return;
      final currentPage = _pageController.hasClients ? _pageController.page?.toInt() ?? 0 : 0;
      final next = (currentPage + 1) % published.length;
      _pageController.animateToPage(
        next,
        duration: 400.ms,
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _navigateToArticle(LiquenpediaArticle article) {
    final authState = context.read<AuthState>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiquenpediaDetailScreen(
          article: article,
          isAdmin: authState.isAdmin,
        ),
      ),
    );
  }

  void _navigateToAllArticles() {
    Navigator.pushNamed(context, AppRoutes.liquenpedia);
  }

  @override
  Widget build(BuildContext context) {
    final articlesState = context.watch<ArticlesState>();
    final published = articlesState.articles
        .where((a) => a.estadoPublicacion == 'published')
        .take(5)
        .toList();

    if (_currentPage >= published.length) {
      _currentPage = 0;
    }

    if (articlesState.loading && published.isEmpty) {
      return Container(
        height: 200,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryGreen),
        ),
      );
    }

    if (published.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.articleDefault.withValues(alpha: 0.06),
              AppTheme.articleHealthy.withValues(alpha: 0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.borderColor.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_rounded,
              size: 40,
              color: AppTheme.articleDefault.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No hay artículos publicados',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 240,
            maxHeight: 300,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final carouselHeight = constraints.maxHeight.clamp(240.0, 300.0);
              return Container(
                height: carouselHeight,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: published.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return _buildArticleCard(published[index], index);
                  },
                ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.96, 0.96), duration: 600.ms),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            published.length,
            (index) {
              final isActive = _currentPage == index;
              final categoryColor = _getCategoryColor(published[index].categoria);
              return AnimatedContainer(
                duration: 300.ms,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: isActive ? 10 : 7,
                height: isActive ? 10 : 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? categoryColor : Colors.transparent,
                  border: Border.all(
                    color: isActive ? categoryColor : AppTheme.borderColor,
                    width: isActive ? 0 : 1.5,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          button: true,
          label: 'Ver todos los artículos',
          child: TextButton(
            onPressed: _navigateToAllArticles,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.articleDefault,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ver todos los artículos',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded, size: 16),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildArticleCard(LiquenpediaArticle article, int index) {
    final categoryColor = _getCategoryColor(article.categoria);
    final imageUrl = article.imagenArticulo;
    final imageUrlResolved = imageUrl != null && imageUrl.isNotEmpty ? AppConfig.getImageUrl(imageUrl) : null;
    return Semantics(
      button: true,
      label: 'Artículo ${index + 1}: ${article.titulo}. Categoría: ${article.categoria}',
      child: GestureDetector(
        onTap: () => _navigateToArticle(article),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                categoryColor.withValues(alpha: 0.08),
                categoryColor.withValues(alpha: 0.04),
                Theme.of(context).colorScheme.surface,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: categoryColor.withValues(alpha: 0.4),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: categoryColor.withValues(alpha: 0.08),
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
                  AspectRatio(
                    aspectRatio: 16 / 6,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.05),
                      ),
                      child: imageUrlResolved != null
                          ? Image.network(
                              imageUrlResolved,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildPlaceholderCover(categoryColor);
                              },
                            )
                          : _buildPlaceholderCover(categoryColor),
                    ),
                  )
                else
                  AspectRatio(
                    aspectRatio: 16 / 6,
                    child: _buildPlaceholderCover(categoryColor),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        article.titulo,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              article.categoria,
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: categoryColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        article.contenido.length > 80
                            ? '${article.contenido.substring(0, 80)}...'
                            : article.contenido,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Por ${article.autor}',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 500.ms, delay: (index * 80).ms),
      ),
    );
  }

  Widget _buildPlaceholderCover(Color color) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.eco_rounded,
          size: 36,
          color: color.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
