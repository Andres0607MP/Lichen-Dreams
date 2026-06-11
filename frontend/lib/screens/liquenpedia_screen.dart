import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/liquenpedia_article.dart';
import '../services/api_service.dart';
import '../widgets/app_theme.dart';
import '../widgets/modern_widgets.dart';
import 'liquenpedia_detail_screen.dart';
import 'liquenpedia_form_screen.dart';

class LiquenpediaScreen extends StatefulWidget {
  const LiquenpediaScreen({super.key});

  @override
  State<LiquenpediaScreen> createState() => _LiquenpediaScreenState();
}

class _LiquenpediaScreenState extends State<LiquenpediaScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<LiquenpediaArticle>> _articlesFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadArticles();
    _checkAdminRole();
  }

  Future<void> _checkAdminRole() async {
    final role = await _apiService.getSavedRole();
    setState(() {
      _isAdmin = role == 'admin';
    });
  }

  void _loadArticles() {
    _articlesFuture = _apiService.getLiquenpediaArticles().then((items) {
      return items.map((json) => LiquenpediaArticle.fromJson(json)).toList();
    });
  }

  Future<void> _refreshArticles() async {
    setState(() {
      _loadArticles();
    });
  }

  void _deleteArticle(int id, String title) {
    showDialog(
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
                await _apiService.deleteLiquenpediaArticle(id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Artículo eliminado')),
                );
                _refreshArticles();
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              'Aprende sobre los líquenes',
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
          if (_isAdmin)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
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
                      _refreshArticles();
                    }
                  },
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header educativo
            _buildEducativeHeader().animate().fadeIn(duration: 500.ms),
            const SizedBox(height: 24),

            // Búsqueda
            _buildSearchField(),
            const SizedBox(height: 20),

            // Artículos
            _buildArticlesList(),
          ],
        ),
      ),
    );
  }

  Widget _buildEducativeHeader() {
    return ModernCard(
      gradient: [
        AppTheme.primaryGreen.withOpacity(0.1),
        AppTheme.lightGreen.withOpacity(0.05),
      ],
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(12),
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
                  'Biomonitores de la naturaleza',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Los líquenes son excelentes indicadores de la calidad del aire',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar especie, categoría...',
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppTheme.primaryGreen,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppTheme.surfaceColor,
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value.toLowerCase());
        },
      ),
    );
  }

  Widget _buildArticlesList() {
    return FutureBuilder<List<LiquenpediaArticle>>(
      future: _articlesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: CircularProgressIndicator(color: AppTheme.primaryGreen),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppTheme.errorColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar artículos',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshArticles,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        List<LiquenpediaArticle> articles = snapshot.data ?? [];

        if (_searchQuery.isNotEmpty) {
          articles = articles
              .where(
                (article) =>
                    article.titulo.toLowerCase().contains(_searchQuery) ||
                    article.categoria.toLowerCase().contains(_searchQuery),
              )
              .toList();
        }

        if (articles.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Icon(
                    Icons.auto_awesome_motion_rounded,
                    size: 80,
                    color: AppTheme.primaryGreen.withOpacity(0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay artículos disponibles',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'para: "$_searchQuery"',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppTheme.textGray,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshArticles,
          color: AppTheme.primaryGreen,
          child: ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: articles.length,
            itemBuilder: (_, index) {
              return _buildArticleCard(articles[index], index)
                  .animate()
                  .fadeIn(duration: 500.ms, delay: (index * 100).ms)
                  .slideY(begin: 0.2, end: 0);
            },
          ),
        );
      },
    );
  }

  Widget _buildArticleCard(LiquenpediaArticle article, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ModernCard(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  LiquenpediaDetailScreen(article: article, isAdmin: _isAdmin),
            ),
          );
          if (result == true) {
            _refreshArticles();
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen
            if (article.imagenArticulo != null &&
                article.imagenArticulo!.isNotEmpty)
              Container(
                width: double.infinity,
                height: 180,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                ),
                child: Image.network(
                  article.imagenArticulo!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(
                      Icons.image_not_supported_rounded,
                      color: AppTheme.primaryGreen.withOpacity(0.3),
                      size: 48,
                    ),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 120,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryGreen.withOpacity(0.3),
                      AppTheme.lightGreen.withOpacity(0.2),
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.eco_rounded,
                    size: 64,
                    color: AppTheme.primaryGreen.withOpacity(0.4),
                  ),
                ),
              ),
            // Contenido
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.titulo,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
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
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              article.estadoPublicacion,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Por ${article.autor}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.textGray,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isAdmin)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.edit_rounded,
                            color: Colors.blue,
                            size: 20,
                          ),
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LiquenpediaFormScreen(
                                  articleToEdit: article,
                                ),
                              ),
                            );
                            if (result == true) {
                              _refreshArticles();
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.delete_rounded,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () =>
                              _deleteArticle(article.id ?? 0, article.titulo),
                        ),
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
}
