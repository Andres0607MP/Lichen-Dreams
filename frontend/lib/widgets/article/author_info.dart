import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/app_config.dart';
import '../../../widgets/app_theme.dart';

class AuthorInfo extends StatelessWidget {
  final String autor;
  final DateTime? fecha;
  final String? fotoPerfil;

  const AuthorInfo({
    Key? key,
    required this.autor,
    this.fecha,
    this.fotoPerfil,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AuthorAvatar(autor: autor, fotoPerfil: fotoPerfil, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Autor',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                autor,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (fecha != null) ...[
          const SizedBox(width: 12),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.borderColor,
                  width: 1,
                ),
              ),
              child: Text(
                _formatDate(fecha!),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ],
    );
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

class AuthorAvatar extends StatelessWidget {
  final String autor;
  final String? fotoPerfil;
  final double size;

  const AuthorAvatar({
    Key? key,
    required this.autor,
    this.fotoPerfil,
    this.size = 36,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final imagePath = fotoPerfil;

    if (imagePath != null && imagePath.isNotEmpty) {
      return _AuthorImageNetwork(
        imagePath: imagePath,
        autor: autor,
        size: size,
      );
    }

    return _InitialsAvatar(autor: autor, size: size);
  }
}

class _AuthorImageNetwork extends StatelessWidget {
  final String imagePath;
  final String autor;
  final double size;

  const _AuthorImageNetwork({
    required this.imagePath,
    required this.autor,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = AppConfig.getImageUrl(imagePath);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.primaryGreen.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(
                  color: AppTheme.borderColor,
                  width: 1,
                ),
              ),
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return _InitialsAvatar(
              autor: autor,
              size: size,
              fallback: true,
            );
          },
        ),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String autor;
  final double size;
  final bool fallback;

  const _InitialsAvatar({
    required this.autor,
    required this.size,
    this.fallback = false,
  });

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(autor);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGreen.withValues(alpha: fallback ? 0.15 : 0.2),
            AppTheme.lightGreen.withValues(alpha: fallback ? 0.08 : 0.1),
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.primaryGreen.withValues(alpha: fallback ? 0.2 : 0.3),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.poppins(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryGreen,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
