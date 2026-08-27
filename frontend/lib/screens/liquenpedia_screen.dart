import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/liquenpedia_article.dart';
import '../config/app_config.dart';
import '../widgets/app_theme.dart';
import '../widgets/modern_widgets.dart';
import 'liquenpedia_detail_screen.dart';
import 'liquenpedia_form_screen.dart';
import '../state/articles_state.dart';
import '../state/auth_state.dart';

class LiquenpediaScreen extends StatefulWidget {
  const LiquenpediaScreen({super.key});

  @override
  State<LiquenpediaScreen> createState() => _LiquenpediaScreenState();
}

class _LiquenpediaScreenState extends State<LiquenpediaScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        final articlesState = context.read<ArticlesState>();
        if (!articlesState.hasFreshData && !articlesState.loading) {
          articlesState.loadArticles();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final articlesState = context.watch<ArticlesState>();
    final authState = context.watch<AuthState>();
    final isAdmin = authState.isAdmin;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LichenPedia',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            Text(
              'Biomonitores de la naturaleza',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppTheme.textGray,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryGreen.withValues(alpha: 0.2),
                      AppTheme.lightGreen.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.add_rounded,
                    color: AppTheme.primaryGreen,
                  ),
                  tooltip: 'Nuevo artículo',
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LiquenpediaFormScreen(),
                      ),
                    );
                    if (result == true) {
                      await articlesState.refresh();
                    }
                  },
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEducativeHeader().animate().fadeIn(duration: 500.ms),
            const SizedBox(height: 24),
            _buildSearchField(context, articlesState),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text(
                'Artículos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildArticlesList(context, articlesState, isAdmin),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildEducativeHeader() {
    return ModernCard(
      gradient: [
        AppTheme.primaryGreen.withValues(alpha: 0.12),
        AppTheme.lightGreen.withValues(alpha: 0.06),
        AppTheme.backgroundColor.withValues(alpha: 0.5),
      ],
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryGreen.withValues(alpha: 0.2),
                  AppTheme.lightGreen.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: const Icon(
              Icons.eco_rounded,
              color: AppTheme.primaryGreen,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Biomonitores naturales',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Los líquenes revelan la calidad del aire que respiramos',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textGray,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.96, 0.96), end: Offset.zero, duration: 500.ms);
  }

  Widget _buildSearchField(BuildContext context, ArticlesState articlesState) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Buscar especie, categoría...',
          hintStyle: GoogleFonts.poppins(
            color: AppTheme.textGray,
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppTheme.primaryGreen,
            size: 22,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppTheme.surfaceColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildArticlesList(BuildContext context, ArticlesState articlesState, bool isAdmin) {
    final articles = _searchQuery.isEmpty 
        ? articlesState.articles 
        : articlesState.search(_searchQuery);

    if (articlesState.loading && articles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            ...List.generate(3, (index) {
              return Container(
                height: 140,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const ShimmerEffect(),
              );
            }),
          ],
        ),
      );
    }

    if (articlesState.error != null && articles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                  color: AppTheme.errorColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Error al cargar artículos',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Verifica tu conexión e intenta de nuevo',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textGray,
                ),
              ),
              const SizedBox(height: 20),
              ModernButton(
                label: 'Reintentar',
                onPressed: () => articlesState.refresh(),
                color: AppTheme.primaryGreen,
              ),
            ],
          ),
        ),
      );
    }

    if (articles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryGreen.withValues(alpha: 0.1),
                      AppTheme.lightGreen.withValues(alpha: 0.05),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.search_rounded,
                  size: 48,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No hay artículos',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Aún no hay contenido disponible',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textGray,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => articlesState.refresh(),
      color: AppTheme.primaryGreen,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: articles.length,
        itemBuilder: (_, index) {
          return _buildArticleCard(context, articles[index], index, isAdmin, articlesState);
        },
      ),
    );
  }

  Widget _buildArticleCard(BuildContext context, LiquenpediaArticle article, int index, bool isAdmin, ArticlesState articlesState) {
    final imageUrl = article.imagenArticulo;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ModernCard(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  LiquenpediaDetailScreen(article: article, isAdmin: isAdmin),
            ),
          );
          if (result == true) {
            await articlesState.refresh();
          }
        },
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.all(20),
        gradient: [
          AppTheme.surfaceColor,
          AppTheme.primaryGreen.withValues(alpha: 0.02),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  height: 180,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.05),
                  ),
                  child: Image.network(
                    AppConfig.getImageUrl(imageUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryGreen.withValues(alpha: 0.2),
                              AppTheme.lightGreen.withValues(alpha: 0.1),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.eco_rounded,
                            size: 56,
                            color: AppTheme.primaryGreen.withValues(alpha: 0.35),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 140,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryGreen.withValues(alpha: 0.18),
                      AppTheme.lightGreen.withValues(alpha: 0.1),
                      AppTheme.accentGreen.withValues(alpha: 0.06),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.eco_rounded,
                        size: 48,
                        color: AppTheme.primaryGreen.withValues(alpha: 0.35),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          article.categoria,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              article.titulo,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryGreen.withValues(alpha: 0.15),
                        AppTheme.primaryGreen.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    article.categoria,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.warningColor.withValues(alpha: 0.15),
                        AppTheme.warningColor.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _translateEstado(article.estadoPublicacion),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warningColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.person_rounded,
                  size: 14,
                  color: AppTheme.textGray.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    article.autor,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textGray,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isAdmin)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildAdminIconButton(
                        icon: Icons.edit_rounded,
                        color: Colors.blue,
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LiquenpediaFormScreen(
                                articleToEdit: article,
                              ),
                            ),
                          );
                          if (result == true) {
                            await articlesState.refresh();
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      _buildAdminIconButton(
                        icon: Icons.delete_rounded,
                        color: Colors.red,
                        onTap: () async =>
                            _deleteArticle(context, article.id ?? 0, article.titulo, articlesState),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  String _translateEstado(String estado) {
    const mapping = {
      'published': 'Publicado',
      'draft': 'Borrador',
      'archived': 'Archivado',
      'publicado': 'Publicado',
      'borrador': 'Borrador',
      'archivado': 'Archivado',
    };
    return mapping[estado] ?? estado;
  }

  Future<void> _deleteArticle(BuildContext context, int id, String title, ArticlesState articlesState) async {
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar artículo'),
        content: Text('¿Deseas eliminar "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await articlesState.deleteArticle(id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Artículo eliminado')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class ShimmerEffect extends StatefulWidget {
  const ShimmerEffect({super.key});

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.borderColor.withValues(alpha: 0.3 * _animation.value),
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }
}
