import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/liquenpedia_article.dart';
import '../config/app_config.dart';
import '../widgets/app_theme.dart';
import '../state/articles_state.dart';
import '../widgets/article/image_network_with_placeholder.dart';
import '../widgets/article/status_badge.dart';
import '../widgets/article/author_info.dart';
import '../widgets/shared/image_preview_dialog.dart';
import 'liquenpedia_form_screen.dart';

class LiquenpediaDetailScreen extends StatefulWidget {
  final LiquenpediaArticle article;
  final bool isAdmin;

  const LiquenpediaDetailScreen({
    super.key,
    required this.article,
    required this.isAdmin,
  });

  @override
  State<LiquenpediaDetailScreen> createState() => _LiquenpediaDetailScreenState();
}

class _LiquenpediaDetailScreenState extends State<LiquenpediaDetailScreen> {
  late LiquenpediaArticle article = widget.article;

  String _translateEstado(String estado) {
    const mapping = {
      'published': 'Publicado',
      'draft': 'Borrador',
      'archived': 'Archivado',
    };
    return mapping[estado] ?? estado;
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'published':
        return AppTheme.warningColor;
      case 'draft':
        return AppTheme.lightGreen;
      case 'archived':
        return AppTheme.borderColor;
      default:
        return AppTheme.textGray;
    }
  }

  void _deleteArticle(BuildContext context) {
    showDialog(
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
            onPressed: () async {
              Navigator.pop(context);
              try {
                await context.read<ArticlesState>().deleteArticle(article.id ?? 0);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Artículo eliminado')),
                );
                Navigator.pop(context, true);
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
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final expandedHeight = (screenWidth * 9 / 16).clamp(210.0, 380.0);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: expandedHeight,
            pinned: true,
            backgroundColor: AppTheme.darkGreen,
            scrolledUnderElevation: 4,
            shadowColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppTheme.primaryGreen,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              if (widget.isAdmin)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Tooltip(
                    message: 'Editar artículo',
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.edit_rounded, color: Colors.white),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  LiquenpediaFormScreen(articleToEdit: article),
                            ),
                          );
                          if (!mounted) return;
                          final state = context.read<ArticlesState>();
                          LiquenpediaArticle? updated;
                          for (final a in state.articles) {
                            if (a.id == widget.article.id) {
                              updated = a;
                              break;
                            }
                          }
                          if (updated != null) {
                            setState(() => article = updated!);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              if (widget.isAdmin)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Tooltip(
                    message: 'Eliminar artículo',
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.delete_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => _deleteArticle(context),
                      ),
                    ),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                article.titulo,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              centerTitle: false,
              background: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        final imageUrl = article.imagenArticulo;
                        if (imageUrl != null && imageUrl.isNotEmpty) {
                          final resolved = AppConfig.getImageUrl(imageUrl);
                          ImagePreviewDialog.show(context, resolved);
                        }
                      },
                      child: ImageNetworkWithPlaceholder(
                        imageUrl: article.imagenArticulo,
                        fit: BoxFit.cover,
                        borderRadius: 0,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.4, 0.75, 1.0],
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              AppTheme.darkGreen.withValues(alpha: 0.45),
                              AppTheme.darkGreen.withValues(alpha: 0.95),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            article.categoria,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Semantics(
                      label: 'Ampliar imagen',
                      child: IgnorePointer(
                        ignoring: false,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.zoom_out_map_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            article.titulo,
                            style: GoogleFonts.poppins(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textDark,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              StatusBadge(
                                label: article.categoria,
                                color: AppTheme.primaryGreen,
                              ),
                              StatusBadge(
                                label: _translateEstado(article.estadoPublicacion),
                                color: _getEstadoColor(article.estadoPublicacion),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                           AuthorInfo(
                             autor: article.autor,
                             fecha: article.fechaPublicacion,
                             fotoPerfil: article.fotoPerfilAutor,
                           ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0),
                    const SizedBox(height: 8),
                    _buildAboutSection(),
                    const SizedBox(height: 16),
                    _buildContentSection(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    final items = <_AboutItem>[];

    items.add(_AboutItem(
      icon: Icons.category_rounded,
      label: 'Categoría',
      value: article.categoria,
      color: AppTheme.primaryGreen,
    ));

    items.add(_AboutItem(
      icon: Icons.publish_rounded,
      label: 'Estado',
      value: _translateEstado(article.estadoPublicacion),
      color: _getEstadoColor(article.estadoPublicacion),
    ));

    items.add(_AboutItem(
      icon: Icons.person_rounded,
      label: 'Autor',
      value: article.autor,
      color: AppTheme.lightGreen,
      imagePath: article.fotoPerfilAutor,
    ));

    if (article.fechaPublicacion != null) {
      items.add(_AboutItem(
        icon: Icons.calendar_today_rounded,
        label: 'Publicado',
        value: _formatDate(article.fechaPublicacion!),
        color: AppTheme.accentGreen,
      ));
    }

    if (article.fechaActualizacion != null) {
      items.add(_AboutItem(
        icon: Icons.update_rounded,
        label: 'Actualizado',
        value: _formatDate(article.fechaActualizacion!),
        color: AppTheme.darkGreen,
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGreen.withValues(alpha: 0.04),
            AppTheme.lightGreen.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.borderColor.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryGreen.withValues(alpha: 0.15),
                      AppTheme.lightGreen.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.info_rounded,
                  size: 20,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Sobre este artículo',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(items.length, (index) {
            final item = items[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < items.length - 1 ? 12 : 0,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: item.imagePath != null && item.imagePath!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              AppConfig.getImageUrl(item.imagePath!),
                              fit: BoxFit.cover,
                              width: 32,
                              height: 32,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(item.icon, size: 16, color: item.color);
                              },
                            ),
                          )
                        : Icon(item.icon, size: 16, color: item.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textGray,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          item.value,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildContentSection() {
    final paragraphs = article.contenido
        .split('\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    final isEmpty = paragraphs.isEmpty || article.contenido.trim().isEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryGreen.withValues(alpha: 0.15),
                      AppTheme.lightGreen.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  size: 20,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Contenido Educativo',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isEmpty)
            Text(
              'Este artículo aún no tiene contenido.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textGray,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ...List.generate(paragraphs.length, (index) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < paragraphs.length - 1 ? 12 : 0,
                ),
                child: Text(
                  paragraphs[index],
                  style: GoogleFonts.poppins(
                    fontSize: 14.5,
                    height: 1.7,
                    color: AppTheme.textGray,
                  ),
                  textAlign: TextAlign.start,
                ),
              );
            }),
        ],
      ),
    ).animate().fadeIn(duration: 700.ms);
  }

  String _formatDate(DateTime date) {
    final months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return '${date.day} de ${months[date.month - 1]} de ${date.year}';
  }
}

class _AboutItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? imagePath;

  const _AboutItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.imagePath,
  });
}
