import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/liquenpedia_article.dart';
import '../services/api_service.dart';
import '../widgets/app_theme.dart';
import '../widgets/modern_widgets.dart';
import 'liquenpedia_form_screen.dart';

class LiquenpediaDetailScreen extends StatelessWidget {
  final LiquenpediaArticle article;
  final bool isAdmin;

  const LiquenpediaDetailScreen({
    super.key,
    required this.article,
    required this.isAdmin,
  });

  // Función para traducir estado de publicación
  String _translateEstado(String estado) {
    const mapping = {
      'published': 'Publicado',
      'draft': 'Borrador',
      'archived': 'Archivado',
    };
    return mapping[estado] ?? estado;
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
                final apiService = ApiService();
                await apiService.deleteLiquenpediaArticle(article.id ?? 0);
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          // AppBar con imagen de fondo
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppTheme.primaryGreen,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
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
              if (isAdmin)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.edit_rounded, color: Colors.white),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                LiquenpediaFormScreen(articleToEdit: article),
                          ),
                        );
                        if (result == true) {
                          Navigator.pop(context, true);
                        }
                      },
                    ),
                  ),
                ),
              if (isAdmin)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
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
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  // Imagen o gradiente
                  if (article.imagenArticulo != null &&
                      article.imagenArticulo!.isNotEmpty)
                    Image.network(
                      article.imagenArticulo!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppTheme.primaryGreen,
                        child: const Icon(
                          Icons.image_not_supported_rounded,
                          size: 80,
                          color: Colors.white,
                        ),
                      ),
                    )
                  else
                    Container(
                      color: AppTheme.primaryGreen,
                      child: const Center(
                        child: Icon(
                          Icons.eco_rounded,
                          size: 120,
                          color: Colors.white30,
                        ),
                      ),
                    ),
                  // Gradiente oscuro
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppTheme.primaryGreen.withOpacity(0.7),
                          AppTheme.primaryGreen,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Contenido
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título y badges
                  Text(
                    article.titulo,
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.primaryGreen.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.category_rounded,
                              size: 16,
                              color: AppTheme.primaryGreen,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              article.categoria,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.publish_rounded,
                              size: 16,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _translateEstado(article.estadoPublicacion),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Información del artículo
                  ModernCard(
                    gradient: [
                      AppTheme.primaryGreen.withOpacity(0.08),
                      AppTheme.lightGreen.withOpacity(0.04),
                    ],
                    child: Column(
                      children: [
                        _buildInfoTile(
                          icon: Icons.person_rounded,
                          label: 'Autor',
                          value: article.autor,
                        ),
                        const Divider(height: 16),
                        if (article.fechaPublicacion != null)
                          _buildInfoTile(
                            icon: Icons.calendar_today_rounded,
                            label: 'Publicado',
                            value: _formatDate(article.fechaPublicacion!),
                          ),
                        if (article.fechaActualizacion != null) ...[
                          const Divider(height: 16),
                          _buildInfoTile(
                            icon: Icons.update_rounded,
                            label: 'Actualizado',
                            value: _formatDate(article.fechaActualizacion!),
                          ),
                        ],
                      ],
                    ),
                  ).animate().fadeIn(duration: 600.ms),
                  const SizedBox(height: 32),

                  // Contenido educativo
                  Text(
                    'Contenido Educativo',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppTheme.borderColor,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    child: Text(
                      article.contenido,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        height: 1.8,
                        color: AppTheme.textGray,
                      ),
                      textAlign: TextAlign.justify,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: AppTheme.primaryGreen),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textGray,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
