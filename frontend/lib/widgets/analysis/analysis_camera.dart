import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../app_theme.dart';

class AnalysisCamera extends StatefulWidget {
  final ValueChanged<File> onImageCaptured;

  const AnalysisCamera({super.key, required this.onImageCaptured});

  @override
  State<AnalysisCamera> createState() => _AnalysisCameraState();
}

class _AnalysisCameraState extends State<AnalysisCamera>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _captureTask;
  Future<void> _operationTail = Future<void>.value();
  bool _disposed = false;
  bool _isInitializing = true;
  bool _isCameraReady = false;
  bool _isPaused = false;
  bool _isTakingPicture = false;
  int _lifecycleVersion = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enqueueLifecycleOperation(_initializeCamera);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    if (state == AppLifecycleState.resumed) {
      _enqueueLifecycleOperation(_initializeCamera);
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _enqueueLifecycleOperation(_suspendCamera);
    }
  }

  void _enqueueLifecycleOperation(Future<void> Function() operation) {
    _operationTail = _operationTail.then((_) async {
      if (!mounted || _disposed) return;
      try {
        await operation();
      } catch (_) {}
    });
  }

  Future<void> _initializeCamera() async {
    if (!mounted || _disposed || _isInitializing || _isCameraReady) {
      return;
    }

    final existingController = _controller;
    if (existingController != null) {
      await _disposeController(existingController);
      if (identical(_controller, existingController)) {
        _controller = null;
      }
    }

    final lifecycleVersion = ++_lifecycleVersion;
    _safeSetState(() {
      _isInitializing = true;
      _isCameraReady = false;
      _isPaused = false;
      _errorMessage = null;
    });

    CameraController? controller;

    try {
      final cameras = await availableCameras();
      if (!mounted || _disposed || lifecycleVersion != _lifecycleVersion) {
        return;
      }

      if (cameras.isEmpty) {
        throw StateError('No camera available');
      }

      final cameraDescription = cameras.firstWhere(
        (candidate) => candidate.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      controller = CameraController(
        cameraDescription,
        ResolutionPreset.veryHigh,
        enableAudio: false,
      );
      _controller = controller;

      await controller.initialize();

      if (!mounted || _disposed || lifecycleVersion != _lifecycleVersion) {
        await _disposeController(controller);
        return;
      }

      _safeSetState(() {
        _isInitializing = false;
        _isCameraReady = true;
      });
    } on CameraException catch (error) {
      if (controller != null) {
        await _disposeController(controller);
      }
      if (!mounted || _disposed || lifecycleVersion != _lifecycleVersion) {
        return;
      }
      _safeSetState(() {
        _controller = null;
        _isInitializing = false;
        _isCameraReady = false;
        _errorMessage = _friendlyCameraError(error);
      });
    } catch (_) {
      if (controller != null) {
        await _disposeController(controller);
      }
      if (!mounted || _disposed || lifecycleVersion != _lifecycleVersion) {
        return;
      }
      _safeSetState(() {
        _controller = null;
        _isInitializing = false;
        _isCameraReady = false;
        _errorMessage = 'No se pudo iniciar la cámara. Intenta de nuevo.';
      });
    }
  }

  Future<void> _suspendCamera() async {
    final lifecycleVersion = ++_lifecycleVersion;
    final controller = _controller;
    final captureTask = _captureTask;

    _controller = null;
    _safeSetState(() {
      _isInitializing = false;
      _isCameraReady = false;
      _isPaused = true;
    });

    if (captureTask != null) {
      await captureTask.catchError((_) {});
    }

    if (controller != null) {
      await _disposeController(controller);
    }

    if (!mounted || _disposed || lifecycleVersion != _lifecycleVersion) {
      return;
    }

    _safeSetState(() {
      _isPaused = true;
    });
  }

  Future<void> _disposeController(CameraController controller) async {
    try {
      await controller.dispose();
    } on CameraException catch (_) {
      return;
    } catch (_) {
      return;
    }
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (_isTakingPicture ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }

    _safeSetState(() {
      _isTakingPicture = true;
    });

    final captureTask = _captureImage(controller);
    _captureTask = captureTask;

    try {
      await captureTask;
    } finally {
      if (mounted && !_disposed && identical(_captureTask, captureTask)) {
        _captureTask = null;
      }
      _safeSetState(() {
        _isTakingPicture = false;
      });
    }
  }

  Future<void> _captureImage(CameraController controller) async {
    try {
      final image = await controller.takePicture();
      if (!mounted || _disposed) return;

      widget.onImageCaptured(File(image.path));
    } on CameraException catch (error) {
      _safeSetState(() {
        _errorMessage = _friendlyCameraError(error);
      });
    } catch (_) {
      _safeSetState(() {
        _errorMessage = 'No se pudo capturar la imagen. Intenta de nuevo.';
      });
    }
  }

  String _friendlyCameraError(CameraException error) {
    if (error.code == 'CameraAccessDenied') {
      return 'Permite el acceso a la cámara para continuar.';
    }

    if (error.code == 'CameraAccessDeniedForever') {
      return 'El permiso de cámara está desactivado. Actívalo en los ajustes.';
    }

    return 'No se pudo usar la cámara. Intenta de nuevo.';
  }

  void _safeSetState(VoidCallback update) {
    if (!mounted || _disposed) return;
    setState(update);
  }

  @override
  void dispose() {
    _disposed = true;
    _lifecycleVersion++;
    WidgetsBinding.instance.removeObserver(this);

    final controller = _controller;
    _controller = null;
    if (controller != null) {
      unawaited(_disposeController(controller));
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 420.0;
        final previewWidth = availableWidth.clamp(0.0, 520.0).toDouble();
        final previewHeight = (previewWidth * 1.25).clamp(360.0, 520.0).toDouble();

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: previewWidth,
            height: previewHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildCameraBackground(),
                  if (_isCameraReady && _controller != null)
                    CameraPreview(_controller!),
                  if (_isCameraReady) ...[
                    _buildTopIndicator(),
                    _buildInstruction(),
                    _buildCaptureFrame(),
                    _buildCaptureButton(),
                  ] else
                    _buildCameraState(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCameraBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF17251B), Color(0xFF263B2A), Color(0xFF111D16)],
        ),
      ),
    );
  }

  Widget _buildTopIndicator() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF8FD47B),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Cámara activa',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 450.ms);
  }

  Widget _buildInstruction() {
    return Positioned(
      top: 58,
      left: 18,
      right: 18,
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.46),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Text(
            'Enmarca el liquen dentro de la guía',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 120.ms, duration: 450.ms);
  }

  Widget _buildCaptureFrame() {
    return Positioned.fill(
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.68,
          heightFactor: 0.54,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.025),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned(
                  top: -1,
                  left: -1,
                  child: _CameraCorner(
                    showTop: true,
                    showBottom: false,
                    showLeft: true,
                    showRight: false,
                  ),
                ),
                const Positioned(
                  top: -1,
                  right: -1,
                  child: _CameraCorner(
                    showTop: true,
                    showBottom: false,
                    showLeft: false,
                    showRight: true,
                  ),
                ),
                const Positioned(
                  bottom: -1,
                  left: -1,
                  child: _CameraCorner(
                    showTop: false,
                    showBottom: true,
                    showLeft: true,
                    showRight: false,
                  ),
                ),
                const Positioned(
                  bottom: -1,
                  right: -1,
                  child: _CameraCorner(
                    showTop: false,
                    showBottom: true,
                    showLeft: false,
                    showRight: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 220.ms, duration: 500.ms);
  }

  Widget _buildCaptureButton() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 18,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Semantics(
          label: 'Capturar fotografía',
          button: true,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _isTakingPicture ? null : _takePicture,
              child: Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.82),
                    width: 3,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 14,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _isTakingPicture
                          ? AppTheme.lightGreen
                          : AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: _isTakingPicture
                          ? SizedBox(
                              width: 25,
                              height: 25,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 29,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ).animate().scale(
      delay: 300.ms,
      begin: const Offset(0.82, 0.82),
      end: const Offset(1, 1),
      duration: 500.ms,
      curve: Curves.easeOutBack,
    );
  }

  Widget _buildCameraState() {
    final isPaused = _isPaused && !_isInitializing;
    final title = isPaused
        ? 'Cámara pausada'
        : _isInitializing
        ? 'Preparando cámara'
        : 'Cámara no disponible';
    final message = isPaused
        ? 'La cámara se reanudará automáticamente'
        : _errorMessage ?? 'Cargando la cámara trasera';

    return Positioned.fill(
      child: Container(
        color: const Color(0xFF17251B),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPaused
                      ? Icons.pause_circle_rounded
                      : _isInitializing
                      ? Icons.cameraswitch_rounded
                      : Icons.photo_camera_back_rounded,
                  color: AppTheme.lightGreen,
                  size: 44,
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                if (_isInitializing) ...[
                  const SizedBox(height: 22),
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.lightGreen,
                    ),
                  ),
                ],
                if (!_isInitializing &&
                    !_isPaused &&
                    _errorMessage != null) ...[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      _enqueueLifecycleOperation(_initializeCamera);
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 350.ms);
  }
}

class _CameraCorner extends StatelessWidget {
  final bool showTop;
  final bool showBottom;
  final bool showLeft;
  final bool showRight;

  const _CameraCorner({
    required this.showTop,
    required this.showBottom,
    required this.showLeft,
    required this.showRight,
  });

  @override
  Widget build(BuildContext context) {
    const length = 30.0;
    const thickness = 4.0;
    const color = Color(0xFFDCEBCF);

    return CustomPaint(
      size: const Size(length, length),
      painter: _CameraCornerPainter(
        showTop: showTop,
        showBottom: showBottom,
        showLeft: showLeft,
        showRight: showRight,
        stroke: thickness,
        color: color,
      ),
    );
  }
}

class _CameraCornerPainter extends CustomPainter {
  final bool showTop;
  final bool showBottom;
  final bool showLeft;
  final bool showRight;
  final double stroke;
  final Color color;

  _CameraCornerPainter({
    required this.showTop,
    required this.showBottom,
    required this.showLeft,
    required this.showRight,
    required this.stroke,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final half = stroke / 2;
    final inset = math.min(stroke, size.shortestSide / 3);

    if (showLeft) {
      canvas.drawLine(
        Offset(inset, showTop ? inset : size.height - half),
        Offset(inset, showBottom ? size.height - inset : half),
        paint,
      );
    }

    if (showRight) {
      canvas.drawLine(
        Offset(size.width - inset, showTop ? inset : size.height - half),
        Offset(size.width - inset, showBottom ? size.height - inset : half),
        paint,
      );
    }

    if (showTop) {
      canvas.drawLine(
        Offset(showLeft ? inset : half, inset),
        Offset(showRight ? size.width - inset : size.width - half, inset),
        paint,
      );
    }

    if (showBottom) {
      canvas.drawLine(
        Offset(showLeft ? inset : half, size.height - inset),
        Offset(
          showRight ? size.width - inset : size.width - half,
          size.height - inset,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CameraCornerPainter oldDelegate) {
    return oldDelegate.showTop != showTop ||
        oldDelegate.showBottom != showBottom ||
        oldDelegate.showLeft != showLeft ||
        oldDelegate.showRight != showRight ||
        oldDelegate.stroke != stroke ||
        oldDelegate.color != color;
  }
}
