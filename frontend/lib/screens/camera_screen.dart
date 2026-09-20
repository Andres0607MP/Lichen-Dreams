import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../widgets/app_theme.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _disposed = false;
  bool _isInitializing = false;
  bool _isCameraReady = false;
  bool _isTakingPicture = false;
  String? _errorMessage;
  Timer? _initTimeoutTimer;
  int _operationGeneration = 0;

  static const Duration _initTimeout = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _enqueueOperation(_initializeCamera);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed || !mounted) return;

    debugPrint('CAMERA LIFECYCLE: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        if (_isCameraReady) return;
        if (_isInitializing) return;
        _enqueueOperation(_initializeCamera);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _enqueueOperation(_suspendCamera);
        break;
    }
  }

  Future<void> _enqueueOperation(Future<void> Function() operation) async {
    final generation = ++_operationGeneration;
    debugPrint('CAMERA INIT: operation enqueued, generation=$generation');
    if (!mounted || _disposed) return;
    try {
      await operation();
    } on CameraException catch (error) {
      debugPrint('CAMERA INIT: CameraException generation=$generation, code=${error.code}');
      if (!mounted || _disposed) return;
      _safeSetState(() {
        _errorMessage = _friendlyCameraError(error);
        _isInitializing = false;
        _isCameraReady = false;
      });
    } catch (error, stackTrace) {
      debugPrint('CAMERA INIT: unexpected error generation=$generation, error=$error');
      debugPrint('CAMERA INIT: stackTrace=$stackTrace');
      if (!mounted || _disposed) return;
      _safeSetState(() {
        _errorMessage = 'No se pudo iniciar la cámara. Intenta de nuevo.';
        _isInitializing = false;
        _isCameraReady = false;
      });
    }
  }

  Future<void> _initializeCamera() async {
    final generation = _operationGeneration;
    debugPrint('CAMERA INIT: start, generation=$generation');

    if (_disposed || !mounted) {
      debugPrint('CAMERA INIT: early return disposed/mounted, generation=$generation');
      return;
    }

    if (_isInitializing || _isCameraReady) {
      debugPrint('CAMERA INIT: early return initializing/ready, generation=$generation');
      return;
    }

    _safeSetState(() {
      _isInitializing = true;
      _isCameraReady = false;
      _errorMessage = null;
    });

    debugPrint('CAMERA INIT: availableCameras start, generation=$generation');
    final cameras = await availableCameras();
    debugPrint('CAMERA INIT: availableCameras done, count=${cameras.length}, generation=$generation');

    if (!mounted || _disposed) {
      debugPrint('CAMERA INIT: disposed after availableCameras, generation=$generation');
      return;
    }

    if (cameras.isEmpty) {
      throw StateError('No camera available');
    }

    if (generation != _operationGeneration) {
      debugPrint('CAMERA INIT: invalidated after availableCameras, generation=$generation');
      return;
    }

    final cameraDescription = cameras.firstWhere(
      (candidate) => candidate.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    debugPrint('CAMERA INIT: controller created, generation=$generation');
    final controller = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _controller = controller;

    debugPrint('CAMERA INIT: initialize start, generation=$generation');
    _initTimeoutTimer?.cancel();
    _initTimeoutTimer = Timer(_initTimeout, () {
      if (!mounted || _disposed) return;
      debugPrint('CAMERA INIT: timeout fired, generation=$generation');
      _handleInitTimeout(generation);
    });

    try {
      await controller.initialize();
      debugPrint('CAMERA INIT: initialize done, generation=$generation');
    } on CameraException catch (error) {
      debugPrint('CAMERA INIT: initialize CameraException, generation=$generation, code=${error.code}');
      _initTimeoutTimer?.cancel();
      _initTimeoutTimer = null;
      await _disposeController(controller);
      if (!mounted || _disposed) return;
      _safeSetState(() {
        _controller = null;
        _isInitializing = false;
        _isCameraReady = false;
        _errorMessage = _friendlyCameraError(error);
      });
      return;
    } catch (error) {
      debugPrint('CAMERA INIT: initialize generic error, generation=$generation, error=$error');
      _initTimeoutTimer?.cancel();
      _initTimeoutTimer = null;
      await _disposeController(controller);
      if (!mounted || _disposed) return;
      _safeSetState(() {
        _controller = null;
        _isInitializing = false;
        _isCameraReady = false;
        _errorMessage = 'No se pudo iniciar la cámara. Intenta de nuevo.';
      });
      return;
    }

    _initTimeoutTimer?.cancel();
    _initTimeoutTimer = null;

    if (!mounted || _disposed) {
      await _disposeController(controller);
      debugPrint('CAMERA INIT: disposed after initialize, generation=$generation');
      return;
    }

    if (generation != _operationGeneration) {
      debugPrint('CAMERA INIT: invalidated after initialize, generation=$generation');
      await _disposeController(controller);
      return;
    }

    if (!identical(_controller, controller)) {
      debugPrint('CAMERA INIT: controller replaced, generation=$generation');
      await _disposeController(controller);
      return;
    }

    debugPrint('CAMERA INIT: ready, generation=$generation');
    _safeSetState(() {
      _isInitializing = false;
      _isCameraReady = true;
    });
  }

  void _handleInitTimeout(int generation) {
    if (_disposed || !mounted) return;
    debugPrint('CAMERA INIT: timeout handling, generation=$generation');
    _operationGeneration++;
    _controller?.dispose();
    _controller = null;
    _safeSetState(() {
      _isInitializing = false;
      _isCameraReady = false;
      _errorMessage = 'La cámara tardó demasiado en inicializar. Intenta de nuevo.';
    });
  }

  Future<void> _suspendCamera() async {
    debugPrint('CAMERA SUSPEND: start');
    final generation = _operationGeneration;
    _operationGeneration++;
    debugPrint('CAMERA SUSPEND: invalidated generation=$generation, new=$_operationGeneration');

    final controller = _controller;
    _controller = null;

    _safeSetState(() {
      _isInitializing = false;
      _isCameraReady = false;
    });

    debugPrint('CAMERA SUSPEND: disposing controller');
    if (controller != null) {
      await _disposeController(controller);
    }
    debugPrint('CAMERA SUSPEND: finished');
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

    try {
      final image = await controller.takePicture();
      if (!mounted || _disposed) return;
      Navigator.pop(context, File(image.path));
    } on CameraException catch (error) {
      if (!mounted || _disposed) return;
      _safeSetState(() {
        _errorMessage = _friendlyCameraError(error);
        _isTakingPicture = false;
      });
    } catch (_) {
      if (!mounted || _disposed) return;
      _safeSetState(() {
        _errorMessage = 'No se pudo capturar la imagen. Intenta de nuevo.';
        _isTakingPicture = false;
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

  Future<void> _closeWithoutCapture() async {
    _initTimeoutTimer?.cancel();
    _initTimeoutTimer = null;
    _operationGeneration++;
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      await _disposeController(controller);
    }
    if (mounted && !_disposed) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _initTimeoutTimer?.cancel();
    _initTimeoutTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF17251B),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraBackground(),
          if (_isCameraReady && _controller != null)
            Positioned.fill(child: CameraPreview(_controller!)),
          _buildTopBar(),
          if (_isCameraReady) _buildReticle(),
          if (!_isCameraReady || _errorMessage != null)
            _buildCameraState(),
          _buildCaptureButton(),
        ],
      ),
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

  Widget _buildTopBar() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Semantics(
            label: 'Cerrar cámara',
            button: true,
            child: Material(
              color: Colors.black.withValues(alpha: 0.4),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _closeWithoutCapture,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.close_rounded,
                      color: AppTheme.lightGreen,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isCameraReady)
            _buildCameraIndicator(),
        ],
      ),
    );
  }

  Widget _buildCameraIndicator() {
    return Container(
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
    ).animate().fadeIn(duration: 450.ms);
  }

  Widget _buildReticle() {
    return Positioned.fill(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enmarca el liquen',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w600,
                  ),
            ).animate().fadeIn(delay: 120.ms, duration: 450.ms),
            const SizedBox(height: 24),
            _CameraReticleFrame(),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraState() {
    final isInitializing = _isInitializing;
    final title = isInitializing
        ? 'Preparando cámara'
        : _errorMessage != null
            ? 'Error'
            : 'Cámara no disponible';
    final message = isInitializing
        ? 'Cargando la cámara trasera'
        : _errorMessage ?? 'Cargando la cámara trasera';

    return Positioned.fill(
      child: Container(
        color: const Color(0xFF17251B).withValues(alpha: 0.92),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isInitializing
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
                if (isInitializing) ...[
                  const SizedBox(height: 22),
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.lightGreen,
                    ),
                  ),
                ],
                if (!isInitializing && _errorMessage != null) ...[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      _enqueueOperation(_initializeCamera);
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

  Widget _buildCaptureButton() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 28,
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
                width: 78,
                height: 78,
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
}

class _CameraReticleFrame extends StatelessWidget {
  const _CameraReticleFrame();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: 200,
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
            child: _ReticleCorner(
              showTop: true,
              showBottom: false,
              showLeft: true,
              showRight: false,
            ),
          ),
          const Positioned(
            top: -1,
            right: -1,
            child: _ReticleCorner(
              showTop: true,
              showBottom: false,
              showLeft: false,
              showRight: true,
            ),
          ),
          const Positioned(
            bottom: -1,
            left: -1,
            child: _ReticleCorner(
              showTop: false,
              showBottom: true,
              showLeft: true,
              showRight: false,
            ),
          ),
          const Positioned(
            bottom: -1,
            right: -1,
            child: _ReticleCorner(
              showTop: false,
              showBottom: true,
              showLeft: false,
              showRight: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReticleCorner extends StatelessWidget {
  final bool showTop;
  final bool showBottom;
  final bool showLeft;
  final bool showRight;

  const _ReticleCorner({
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
      painter: _ReticleCornerPainter(
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

class _ReticleCornerPainter extends CustomPainter {
  final bool showTop;
  final bool showBottom;
  final bool showLeft;
  final bool showRight;
  final double stroke;
  final Color color;

  _ReticleCornerPainter({
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
    final inset = stroke / 2;

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
  bool shouldRepaint(covariant _ReticleCornerPainter oldDelegate) {
    return oldDelegate.showTop != showTop ||
        oldDelegate.showBottom != showBottom ||
        oldDelegate.showLeft != showLeft ||
        oldDelegate.showRight != showRight ||
        oldDelegate.stroke != stroke ||
        oldDelegate.color != color;
  }
}