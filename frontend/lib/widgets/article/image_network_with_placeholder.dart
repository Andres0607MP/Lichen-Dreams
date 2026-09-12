import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../services/api_service.dart';
import '../app_theme.dart';

class ImageNetworkWithPlaceholder extends StatefulWidget {
  final String? imageUrl;
  final double? height;
  final double? width;
  final BoxFit fit;
  final double borderRadius;
  const ImageNetworkWithPlaceholder({
    super.key,
    required this.imageUrl,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
  });

  @override
  State<ImageNetworkWithPlaceholder> createState() => _ImageNetworkWithPlaceholderState();
}

class _ImageNetworkWithPlaceholderState extends State<ImageNetworkWithPlaceholder> {
  Uint8List? _cachedBytes;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      _loadImage();
    }
  }

  @override
  void didUpdateWidget(covariant ImageNetworkWithPlaceholder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _cachedBytes = null;
      _hasError = false;
      if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
        _loadImage();
      }
    }
  }

  Future<void> _loadImage() async {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) return;

    final isPrivate = AppConfig.isPrivateImagePath(widget.imageUrl!);

    if (!isPrivate) {
      // Public image: use Image.network directly, no bytes caching needed
      return;
    }

    // Private image: download via authenticated endpoint
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final bytes = await apiService.downloadPrivateImageBytes(widget.imageUrl!);
      if (!mounted) return;
      setState(() {
        _cachedBytes = bytes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = widget.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildPlaceholder();
    }

    final String? resolvedNullable = AppConfig.getImageUrl(imageUrl);
    final isPrivate = AppConfig.isPrivateImagePath(imageUrl);

    if (resolvedNullable == null) {
      return _buildPlaceholder();
    }

    final String resolved = resolvedNullable;

    // Public image: use Image.network directly
    if (!isPrivate) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Image.network(
          resolved,
          height: widget.height,
          width: widget.width,
          fit: widget.fit,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              debugPrint('[IMG-DEBUG] Image.network carga completada: $resolved');
              return child;
            }
            return Stack(
              children: [
                Container(
                  color: AppTheme.borderColor.withValues(alpha: 0.15),
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                ),
                child,
              ],
            );
          },
          errorBuilder: (context, error, stackTrace) {
            debugPrint('[IMG-ERROR] Image.network falló: ${error.runtimeType}: $error\n$stackTrace');
            return _buildErrorPlaceholder();
          },
        ),
      );
    }

    // Private image: use cached bytes from downloadPrivateImageBytes
    if (_hasError) {
      return _buildErrorPlaceholder();
    }

    if (_isLoading || _cachedBytes == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Container(
          height: widget.height,
          width: widget.width,
          color: AppTheme.borderColor.withValues(alpha: 0.15),
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Image.memory(
        _cachedBytes!,
        height: widget.height,
        width: widget.width,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorPlaceholder();
        },
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      constraints: const BoxConstraints.expand(),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(color: AppTheme.borderColor, width: 1),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 48, color: AppTheme.textGray),
          SizedBox(height: 8),
          Text(
            'Sin imagen',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      constraints: const BoxConstraints.expand(),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(color: AppTheme.errorColor, width: 1),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_rounded,
            size: 48,
            color: AppTheme.errorColor,
          ),
          SizedBox(height: 8),
          Text(
            'Error al cargar imagen',
            style: TextStyle(fontSize: 12, color: AppTheme.errorColor),
          ),
        ],
      ),
    );
  }
}
