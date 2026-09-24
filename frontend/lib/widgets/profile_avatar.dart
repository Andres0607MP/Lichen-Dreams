import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import 'app_theme.dart';

/// Widget reutilizable que muestra el avatar de un usuario.
///
/// Las fotos de perfil se almacenan en rutas privadas
/// (`/uploads/profiles/...`) y deben descargarse mediante el flujo
/// autenticado de [ApiService.downloadImageBytes] (que internamente usa
/// el endpoint `/images/file/...` cuando la ruta es privada).
///
/// Si la imagen no está disponible o la descarga falla, muestra un
/// ícono de persona por defecto.
class ProfileAvatar extends StatefulWidget {
  final String? imagePath;
  final double radius;
  final Color? backgroundColor;
  final Color? iconColor;
  final EdgeInsetsGeometry? margin;

  const ProfileAvatar({
    super.key,
    required this.imagePath,
    this.radius = 16,
    this.backgroundColor,
    this.iconColor,
    this.margin,
  });

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  Uint8List? _bytes;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final path = widget.imagePath;
    if (path == null || path.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);

    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      _bytes = await apiService.downloadImageBytes(path);
    } catch (_) {
      _bytes = null;
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.backgroundColor ?? AppTheme.primaryGreen.withValues(alpha: 0.15);
    final iconColor = widget.iconColor ?? AppTheme.primaryGreen;
    final iconSize = widget.radius * 0.875;

    return Container(
      margin: widget.margin,
      child: CircleAvatar(
        radius: widget.radius,
        backgroundColor: bg,
        backgroundImage: _bytes != null ? MemoryImage(_bytes!) : null,
        child: _loading || _bytes == null
            ? Icon(Icons.person_rounded, size: iconSize, color: iconColor)
            : null,
      ),
    );
  }
}