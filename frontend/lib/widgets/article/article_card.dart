import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/liquenpedia_article.dart';
import '../../config/app_config.dart';
import '../app_theme.dart';
import 'image_network_with_placeholder.dart';
import 'status_badge.dart';
import 'author_info.dart';
import '../shared/image_preview_dialog.dart';

class ArticleCard extends StatelessWidget {
  final LiquenpediaArticle article;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ArticleCard({
    Key? key,
    required this.article,
    required this.isAdmin,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
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
                  ),
                ),
              ),
              Flexible(
                fit: FlexFit.loose,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusBadge(
                            label: article.categoria,
                            color: AppTheme.primaryGreen,
                            icon: Icons.category_rounded,
                          ),
                          StatusBadge(
                            label: _translateEstado(article.estadoPublicacion),
                            color: _getEstadoColor(article.estadoPublicacion),
                            icon: _estadoIcon(article.estadoPublicacion),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        article.titulo,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      AuthorInfo(
                        autor: article.autor,
                        fecha: article.fechaPublicacion,
                        fotoPerfil: article.fotoPerfilAutor,
                      ),
                      if (isAdmin) ...[
                        const SizedBox(height: 12),
                        _buildAdminActions(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminActions() {
    return Row(
      children: [
        if (onEdit != null)
          Expanded(
            child: _AdminActionButton(
              label: 'Editar',
              icon: Icons.edit_rounded,
              color: const Color(0xFF1E88E5),
              borderColor: const Color(0xFF90CAF9),
              onPressed: onEdit!,
            ),
          ),
        if (onEdit != null && onDelete != null) const SizedBox(width: 8),
        if (onDelete != null)
          Expanded(
            child: _AdminActionButton(
              label: 'Eliminar',
              icon: Icons.delete_rounded,
              color: AppTheme.errorColor,
              borderColor: AppTheme.errorColor.withValues(alpha: 0.5),
              onPressed: onDelete!,
            ),
          ),
      ],
    );
  }

  IconData _estadoIcon(String estado) {
    switch (estado) {
      case 'published':
        return Icons.public_rounded;
      case 'draft':
        return Icons.edit_note_rounded;
      case 'archived':
        return Icons.archive_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

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
}

class _AdminActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color borderColor;
  final VoidCallback onPressed;

  const _AdminActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.borderColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 14),
        label: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: borderColor, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
