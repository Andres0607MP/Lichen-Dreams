import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/liquenpedia_article.dart';
import '../widgets/app_theme.dart';
import '../state/articles_state.dart';
import '../state/auth_state.dart';
import '../state/profile_state.dart';
import '../widgets/article/article_card.dart';
import '../widgets/shared/shimmer_placeholder.dart';
import '../widgets/shared/bottom_sheet_filter.dart';
import 'liquenpedia_detail_screen.dart';
import 'liquenpedia_form_screen.dart';

class LiquenpediaScreen extends StatefulWidget {
  const LiquenpediaScreen({super.key});

  @override
  State<LiquenpediaScreen> createState() => _LiquenpediaScreenState();
}

class _LiquenpediaScreenState extends State<LiquenpediaScreen> {
  String _searchQuery = '';
  String? _statusFilter;
  final List<int> _categoryFilterIds = [];
  String? _sortFilter;
  bool _isAdmin = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final articlesState = context.read<ArticlesState>();
    final authState = context.read<AuthState>();
    final profileState = context.read<ProfileState>();
    if (!articlesState.hasFreshData && !articlesState.loading) {
      await articlesState.loadArticles();
    }
    _isAdmin = authState.isAdmin;
    if (!profileState.hasFreshData && !profileState.loading) {
      await profileState.loadProfile();
    }
    debugPrint('LIQUENPEDIA_PROFILE_DEBUG profile=${profileState.profile} foto=${profileState.profile?['foto_perfil']}');
    if (mounted) setState(() {});
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  String _translateEstado(String estado) {
    const mapping = {
      'published': 'Publicado',
      'draft': 'Borrador',
      'archived': 'Archivado',
    };
    return mapping[estado] ?? estado;
  }

  /// Puntos de vista derivados del estado global de [ArticlesState].
  /// Se recalcula en cada build, por lo que refleja inmediatamente
  /// creaciones, ediciones y eliminaciones sin depender de copias locales.
  List<LiquenpediaArticle> _computeFilteredList(ArticlesState state) {
    var articles = state.articles;
    if (_searchQuery.isNotEmpty) {
      articles = state.search(_searchQuery);
    }
    if (_categoryFilterIds.isNotEmpty) {
      articles = articles
          .where((a) =>
              a.idCategoria != null && _categoryFilterIds.contains(a.idCategoria))
          .toList();
    }
    if (_statusFilter != null) {
      articles = articles
          .where((a) => _translateEstado(a.estadoPublicacion) == _statusFilter)
          .toList();
    }
    final sorted = List<LiquenpediaArticle>.of(articles);
    switch (_sortFilter) {
      case 'Más reciente':
        sorted.sort((a, b) => (b.fechaPublicacion ?? DateTime(0))
            .compareTo(a.fechaPublicacion ?? DateTime(0)));
        break;
      case 'Más antiguo':
        sorted.sort((a, b) => (a.fechaPublicacion ?? DateTime(0))
            .compareTo(b.fechaPublicacion ?? DateTime(0)));
        break;
      case 'Título A-Z':
        sorted.sort((a, b) => a.titulo
            .toLowerCase()
            .compareTo(b.titulo.toLowerCase()));
        break;
      case 'Título Z-A':
        sorted.sort((a, b) => b.titulo
            .toLowerCase()
            .compareTo(a.titulo.toLowerCase()));
        break;
    }
    return sorted;
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _categoryFilterIds.isNotEmpty ||
      _statusFilter != null;

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _statusFilter = null;
      _categoryFilterIds.clear();
      _sortFilter = null;
    });
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.82,
          ),
          child: SafeArea(
            top: false,
            child: BottomSheetFilter(
              initialStatus: _statusFilter,
              initialCategoryIds: _categoryFilterIds,
              initialSort: _sortFilter,
              onApply: (status, categoryIds, sort) {
                setState(() {
                  _statusFilter = status;
                  _categoryFilterIds.clear();
                  _categoryFilterIds.addAll(categoryIds);
                  _sortFilter = sort;
                });
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCreateForm(ArticlesState articlesState) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LiquenpediaFormScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final articlesState = context.watch<ArticlesState>();
    final authState = context.watch<AuthState>();
    _isAdmin = authState.isAdmin;

    final filteredArticles = _computeFilteredList(articlesState);

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
          // Filter button for all users
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Tooltip(
              message: 'Filtrar artículos',
              child: IconButton(
                icon: const Icon(Icons.filter_list_rounded),
                color: AppTheme.primaryGreen,
                onPressed: _showFilterBottomSheet,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Admin button: show text + icon if enough space, else just icon
          LayoutBuilder(
            builder: (context, constraints) {
              if (_isAdmin && constraints.maxWidth >= 100) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Tooltip(
                    message: 'Nuevo artículo',
                    child: ElevatedButton.icon(
                      onPressed: () => _openCreateForm(articlesState),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('Nuevo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                );
              } else if (_isAdmin) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Tooltip(
                    message: 'Nuevo artículo',
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
                        onPressed: () => _openCreateForm(articlesState),
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Educative header
            _buildEducativeHeader(),
            const SizedBox(height: 20),
            // Search field
            _buildSearchField(context),
            const SizedBox(height: 16),
            // Articles header with live count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Artículos',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${filteredArticles.length}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_hasActiveFilters)
                    TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: Text(
                        'Limpiar',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textGray,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Articles list
            Expanded(
              child: _buildArticlesList(
                context,
                articlesState,
                filteredArticles,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEducativeHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGreen.withValues(alpha: 0.08),
            AppTheme.lightGreen.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryGreen.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 360;
          final textScaler = MediaQuery.textScalerOf(context).scale(1.0);
          final imageSize = (constraints.maxWidth * 0.26).clamp(64.0, 104.0);

          if (isNarrow) {
            return Column(
              children: [
                Image.asset(
                  'assets/images/pedia.png',
                  fit: BoxFit.contain,
                  width: imageSize,
                  height: imageSize,
                  semanticLabel: 'Ilustración de líquenes',
                ),
                const SizedBox(height: 12),
                Text(
                  'Descubre el mundo de los líquenes',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Aprende cómo nos ayudan a conocer la calidad de nuestro entorno',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textGray,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            );
          }

          return Row(
            children: [
              Image.asset(
                'assets/images/pedia.png',
                fit: BoxFit.contain,
                width: imageSize,
                height: imageSize,
                semanticLabel: 'Ilustración de líquenes',
                
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Descubre el mundo de los líquenes',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Aprende cómo nos ayudan a conocer la calidad de nuestro entorno',
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
          );
        },
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Buscar por título, categoría o autor',
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
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildArticlesList(
    BuildContext context,
    ArticlesState articlesState,
    List<LiquenpediaArticle> articles,
  ) {
    if (articlesState.loading && articlesState.articles.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: 6,
        itemBuilder: (context, index) => const ArticleShimmerPlaceholder(),
      );
    }

    if (articlesState.error != null && articlesState.articles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              ElevatedButton(
                onPressed: () => articlesState.refresh(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (articles.isEmpty) {
      return _buildEmptyState(context, articlesState);
    }

    return RefreshIndicator(
      onRefresh: () => articlesState.refresh(),
      color: AppTheme.primaryGreen,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gridWidth = constraints.maxWidth;
          final columnCount = _columnCountForWidth(gridWidth);
          const spacing = 16.0;
          final textScaler = MediaQuery.textScalerOf(context).scale(1.0);
          final double cardWidth = (gridWidth - 32 - (columnCount - 1) * spacing) / columnCount;
          final isAdmin = _isAdmin;
          final double imageH = cardWidth * 9 / 16;
          final double contentH = (isAdmin ? 200.0 : 150.0) * textScaler;
          final double cellH = imageH + contentH;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columnCount,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  mainAxisExtent: cellH,
                ),
                itemCount: articles.length,
                itemBuilder: (context, index) {
                  final article = articles[index];
                  return ArticleCard(
                    article: article,
                    isAdmin: _isAdmin,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LiquenpediaDetailScreen(
                            article: article,
                            isAdmin: _isAdmin,
                          ),
                        ),
                      );
                    },
                    onEdit: _isAdmin
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LiquenpediaFormScreen(
                                  articleToEdit: article,
                                ),
                              ),
                            );
                          }
                        : null,
                    onDelete: _isAdmin
                        ? () => _confirmDelete(context, articlesState, article)
                        : null,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  int _columnCountForWidth(double width) {
    if (width < 640) return 1;
    if (width < 1000) return 2;
    return 3;
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ArticlesState articlesState,
    LiquenpediaArticle article,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar artículo'),
        content: Text('¿Deseas eliminar "${article.titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await articlesState.deleteArticle(article.id ?? 0);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Artículo eliminado correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildEmptyState(BuildContext context, ArticlesState articlesState) {
    final noArticlesAtAll = articlesState.articles.isEmpty;
    final emptyTitle = noArticlesAtAll
        ? 'Tu LichenPedia está esperando su primer artículo'
        : 'No encontramos artículos';
    final emptyMessage = noArticlesAtAll
        ? 'Crea contenido educativo sobre líquenes y compártelo con la comunidad.'
        : 'Prueba con otro título, categoría o autor.';

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryGreen.withValues(alpha: 0.1),
                            AppTheme.lightGreen.withValues(alpha: 0.05),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        noArticlesAtAll
                            ? Icons.eco_rounded
                            : Icons.search_off_rounded,
                        size: 44,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      emptyTitle,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      emptyMessage,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.textGray,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (noArticlesAtAll && _isAdmin)
                      ElevatedButton.icon(
                        onPressed: () => _openCreateForm(articlesState),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Crear artículo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      )
                    else if (noArticlesAtAll)
                      ElevatedButton.icon(
                        onPressed: () => articlesState.refresh(),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Explorar LichenPedia'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      )
                    else
                      TextButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Limpiar filtros'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}