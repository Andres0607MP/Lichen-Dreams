import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../widgets/app_theme.dart';
import '../../../state/profile_state.dart';
import '../../../state/auth_state.dart';
import '../../../services/api_service.dart';

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
                  color: AppTheme.textGray,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                autor,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textDark,
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
                color: AppTheme.surfaceColor,
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
                  color: AppTheme.textDark,
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
    final authState = context.watch<AuthState>();
    final profileState = context.watch<ProfileState>();

    final isCurrentUser = authState.userName != null &&
        authState.userName!.trim().toLowerCase() == autor.trim().toLowerCase();

    final rawFoto = profileState.profile?['foto_perfil'];
    final imagePath = isCurrentUser
        ? rawFoto?.toString()
        : fotoPerfil;

    if (imagePath != null && imagePath.isNotEmpty) {
      return _CachedAuthorImage(imagePath: imagePath, size: size);
    }

    return _InitialsAvatar(autor: autor, size: size);
  }
}

class _CachedAuthorImage extends StatefulWidget {
  final String imagePath;
  final double size;

  const _CachedAuthorImage({
    required this.imagePath,
    required this.size,
  });

  @override
  State<_CachedAuthorImage> createState() => _CachedAuthorImageState();
}

class _CachedAuthorImageState extends State<_CachedAuthorImage> {
  Uint8List? _bytes;
  bool _loading = true;
  static final Map<String, Uint8List?> _cache = {};

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant _CachedAuthorImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    debugPrint('AUTHOR_AVATAR_DEBUG loading imagePath=${widget.imagePath}');
    if (_cache.containsKey(widget.imagePath)) {
      _bytes = _cache[widget.imagePath];
      if (mounted) setState(() => _loading = false);
      debugPrint('AUTHOR_AVATAR_DEBUG cache hit');
      return;
    }

    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      _bytes = await apiService.downloadImageBytes(widget.imagePath);
      debugPrint('AUTHOR_AVATAR_DEBUG downloaded bytes=${_bytes?.length}');
      if (_bytes != null) {
        _cache[widget.imagePath] = _bytes;
      }
    } catch (e) {
      _bytes = null;
      debugPrint('AUTHOR_AVATAR_DEBUG download error=$e');
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.surfaceColor,
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
    }

    if (_bytes != null) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.primaryGreen.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: ClipOval(
          child: Image.memory(
            _bytes!,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return _InitialsAvatar(
      autor: '',
      size: widget.size,
      fallback: true,
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
