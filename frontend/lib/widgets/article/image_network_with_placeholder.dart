import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../app_theme.dart';

class ImageNetworkWithPlaceholder extends StatelessWidget {
  final String? imageUrl;
  final double? height;
  final double? width;
  final BoxFit fit;
  final double borderRadius;

  const ImageNetworkWithPlaceholder({
    Key? key,
    required this.imageUrl,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
  }) : super(key: key);

  String? _resolveUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    return AppConfig.getImageUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolveUrl(imageUrl);
    if (resolved == null) {
      return _buildPlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        resolved,
        height: height,
        width: width,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
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
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: AppTheme.borderColor,
          width: 1,
        ),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: 48,
            color: AppTheme.textGray,
          ),
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
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: AppTheme.errorColor,
          width: 1,
        ),
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
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.errorColor,
            ),
          ),
        ],
      ),
    );
  }
}
