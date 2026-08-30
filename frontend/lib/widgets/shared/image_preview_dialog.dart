import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class ImagePreviewDialog extends StatefulWidget {
  final String imageUrl;
  final String? semanticLabel;

  const ImagePreviewDialog({
    super.key,
    required this.imageUrl,
    this.semanticLabel,
  });

  @override
  State<ImagePreviewDialog> createState() => _ImagePreviewDialogState();

  static void show(BuildContext context, String imageUrl, {String? semanticLabel}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      barrierDismissible: true,
      builder: (context) => ImagePreviewDialog(
        imageUrl: imageUrl,
        semanticLabel: semanticLabel,
      ),
    );
  }
}

class _ImagePreviewDialogState extends State<ImagePreviewDialog> {
  final TransformationController _controller = TransformationController();

  void _resetZoom() {
    _controller.value = Matrix4.identity();
  }

  void _handleDoubleTap() {
    _resetZoom();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                color: Colors.black.withValues(alpha: 0.85),
              ),
            ),
          ),
          Center(
            child: InteractiveViewer(
              transformationController: _controller,
              minScale: 1.0,
              maxScale: 4.0,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: GestureDetector(
                  onDoubleTap: _handleDoubleTap,
                  child: Image.network(
                    widget.imageUrl,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    semanticLabel: widget.semanticLabel,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.broken_image_rounded,
                            size: 48,
                            color: Colors.white70,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No se pudo cargar la imagen',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Semantics(
              button: true,
              label: 'Cerrar vista previa',
              child: Material(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(28),
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).scale(begin: const Offset(0.92, 0.92), end: const Offset(1, 1), duration: 250.ms);
  }
}
