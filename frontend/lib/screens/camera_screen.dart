import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const Color _bg = Color(0xFF17251B);
const Color _cream = Color(0xFFF4F3EC);
const Color _sage = Color(0xFFAEB5A0);
const Color _moss = Color(0xFF7D896D);

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
  bool _isPressed = false; // UI-only for button press feedback

  double _zoomLevel = 1.0;
  double? _minZoom;
  double? _maxZoom;
  bool _showZoomIndicator = false;
  Timer? _zoomIndicatorTimer;
  double _baseZoomOnScale = 1.0;

  Offset? _focusPoint;
  bool _focusHiding = false;
  Timer? _focusTimer;

  bool _captureFeedback = false;

  final Stopwatch _ts = Stopwatch()..start();

  static const Duration _initTimeout = Duration(seconds: 15);

  static final List<Shadow> _textShadows = <Shadow>[
    Shadow(
      color: Colors.black.withValues(alpha: 0.32),
      blurRadius: 6,
      offset: const Offset(0, 1),
    ),
  ];

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

  Future<void> _initZoomRange() async {
    final controller = _controller;
    debugPrint('[ZOOM_DEBUG] ${_ts.elapsedMilliseconds}ms _initZoomRange start: '
        '_isCameraReady=$_isCameraReady, isInitialized=${controller?.value.isInitialized}, '
        '_minZoom=$_minZoom, _maxZoom=$_maxZoom');
    if (controller == null || !controller.value.isInitialized || _disposed) return;
    try {
      final minZ = await controller.getMinZoomLevel();
      final maxZ = await controller.getMaxZoomLevel();
      if (!mounted || _disposed) return;
      _safeSetState(() {
        _minZoom = minZ;
        _maxZoom = maxZ;
      });
      debugPrint('[ZOOM_DEBUG] ${_ts.elapsedMilliseconds}ms _initZoomRange ok: '
          'minZ=$minZ, maxZ=$maxZ, _isCameraReady=$_isCameraReady');
    } on CameraException catch (e) {
      debugPrint('[ZOOM_DEBUG] ${_ts.elapsedMilliseconds}ms _initZoomRange '
          'CameraException: ${e.code} / ${e.description}');
      if (!mounted || _disposed) return;
      _safeSetState(() {
        _minZoom = 1.0;
        _maxZoom = 3.0;
      });
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
      _captureFeedback = true;
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
        _captureFeedback = false;
      });
    } catch (_) {
      if (!mounted || _disposed) return;
      _safeSetState(() {
        _errorMessage = 'No se pudo capturar la imagen. Intenta de nuevo.';
        _isTakingPicture = false;
        _captureFeedback = false;
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

  void _dbg(PointerEvent e) {
    debugPrint('[PTR_DEBUG] ${e.runtimeType} '
        'pointer=${e.pointer} '
        'position=${e.position} '
        'buttons=${e.buttons} '
        'kind=${e.kind}');
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
    if (_isCameraReady && _minZoom == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _initZoomRange());
    }

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_isCameraReady && _controller != null)
            Positioned.fill(
              child: CameraPreview(_controller!),
            ),
          if (_isCameraReady && _controller != null)
            Positioned.fill(
              child: Listener(
                onPointerDown: _dbg,
                onPointerMove: _dbg,
                onPointerUp: _dbg,
                onPointerCancel: _dbg,
                onPointerPanZoomStart: _dbg,
                onPointerPanZoomUpdate: _dbg,
                onPointerPanZoomEnd: _dbg,
                child: const SizedBox.expand(),
              ),
            ),
          if (_isCameraReady && _controller != null)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (details) {
                  final controller = _controller;
                  if (controller == null || !controller.value.isInitialized) {
                    return;
                  }
                  final box =
                      context.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  final normalized = Offset(
                    details.localPosition.dx / box.size.width,
                    details.localPosition.dy / box.size.height,
                  );
                  controller
                      .setFocusPoint(normalized)
                      .catchError((_) {});
                  _focusTimer?.cancel();
                  setState(() {
                    _focusPoint = details.localPosition;
                    _focusHiding = false;
                  });
                  _focusTimer = Timer(
                      const Duration(milliseconds: 500), () {
                    if (!mounted || _disposed) return;
                    setState(() => _focusHiding = true);
                  });
                },
                onScaleStart: (details) {
                  _baseZoomOnScale = _zoomLevel;
                  _showZoomIndicator = true;
                  _zoomIndicatorTimer?.cancel();
                  _safeSetState(() {});
                  debugPrint('[ZOOM_DEBUG] ${_ts.elapsedMilliseconds}ms onScaleStart: '
                      '_zoomLevel=$_zoomLevel, _baseZoomOnScale=$_baseZoomOnScale, '
                      '_minZoom=$_minZoom, _maxZoom=$_maxZoom, '
                      '_isCameraReady=$_isCameraReady, '
                      'isInitialized=${_controller?.value.isInitialized}, '
                      'disposed=$_disposed');
                },
                onScaleUpdate: (details) {
                  final minZ = _minZoom;
                  final maxZ = _maxZoom;
                  if (minZ == null || maxZ == null) {
                    debugPrint('[ZOOM_DEBUG] ${_ts.elapsedMilliseconds}ms onScaleUpdate: '
                        'SKIP (range not init), details.scale=${details.scale}, '
                        '_zoomLevel=$_zoomLevel, _minZoom=$minZ, _maxZoom=$maxZ');
                    return;
                  }
                  final newZoom =
                      (_baseZoomOnScale * details.scale).clamp(minZ, maxZ);
                  final applied = newZoom != _zoomLevel;
                  if (applied) {
                    _zoomLevel = newZoom;
                    _controller
                        ?.setZoomLevel(newZoom)
                        .then((_) {
                          debugPrint('[ZOOM_DEBUG] ${_ts.elapsedMilliseconds}ms '
                              'setZoomLevel.then: requested=$newZoom');
                        })
                        .catchError((Object e, StackTrace st) {
                          debugPrint('[ZOOM_DEBUG] ${_ts.elapsedMilliseconds}ms '
                              'setZoomLevel.catchError: requested=$newZoom, '
                              'error=$e');
                        });
                    _safeSetState(() {});
                  }
                  debugPrint('[ZOOM_DEBUG] ${_ts.elapsedMilliseconds}ms onScaleUpdate: '
                      'details.scale=${details.scale}, _baseZoomOnScale=$_baseZoomOnScale, '
                      'minZ=$minZ, maxZ=$maxZ, _zoomLevel=$_zoomLevel, newZoom=$newZoom, '
                      'applied=$applied');
                },
                onScaleEnd: (_) {
                  _zoomIndicatorTimer?.cancel();
                  _zoomIndicatorTimer =
                      Timer(const Duration(seconds: 1), () {
                    if (!mounted || _disposed) return;
                    _safeSetState(() => _showZoomIndicator = false);
                  });
                  _safeSetState(() {});
                },
                child: const SizedBox.expand(),
              ),
            ),
          _buildZoomIndicator(),
          _buildFocusIndicator(),
          _buildCaptureFeedbackLine(),
          _buildTopScrim(),
          _buildBottomScrim(),
          _buildObservationArea(),
          _buildTopBar(),
          if (!_isCameraReady || _errorMessage != null) _buildCameraState(),
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildTopScrim() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 150,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _bg.withValues(alpha: 0.40),
                _bg.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomScrim() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: 290,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                _bg.withValues(alpha: 0.42),
                _bg.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned.fill(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _buildCloseButton(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: _buildCameraIndicator(),
              ),
            ],
          )
              .animate()
              .slideY(
                begin: -0.18,
                end: 0,
                duration: 420.ms,
                curve: Curves.easeOutCubic,
              ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return Semantics(
      label: 'Cerrar cámara',
      button: true,
      child: Material(
        color: _bg.withValues(alpha: 0.34),
        shape: CircleBorder(
          side: BorderSide(
            color: _cream.withValues(alpha: 0.16),
            width: 1,
          ),
        ),
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _closeWithoutCapture,
          splashColor: _cream.withValues(alpha: 0.12),
          highlightColor: _cream.withValues(alpha: 0.06),
          child: const SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Icon(
                LucideIcons.x,
                size: 22,
                color: _cream,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _moss,
          ),
        )
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .fade(
              begin: 0.5,
              end: 1.0,
              duration: 1800.ms,
              curve: Curves.easeInOut,
            ),
        const SizedBox(width: 7),
        Text(
          'LISTO',
          style: GoogleFonts.poppins(
            fontSize: 10.5,
            letterSpacing: 1.2,
            color: _cream.withValues(alpha: 0.9),
            fontWeight: FontWeight.w500,
            shadows: _textShadows,
          ),
        ),
      ],
    );
  }

  Widget _buildObservationArea() {
    return Positioned.fill(
      child: AnimatedScale(
        scale: _captureFeedback ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        child: CustomPaint(
          painter: _ObservationAreaPainter(
            showCaptureLine: _captureFeedback,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned.fill(
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.scan,
                  size: 20,
                  color: _sage.withValues(alpha: 0.9),
                ),
                const SizedBox(height: 10),
                Text(
                  'Enmarca el liquen',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    color: _cream,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    shadows: _textShadows,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Acércate y mantén el liquen enfocado',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: _sage,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.2,
                    shadows: _textShadows,
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  'Tocar para capturar',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: _sage.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.3,
                    shadows: _textShadows,
                  ),
                ),
                const SizedBox(height: 10),
                _buildCaptureButton(),
              ],
            ),
          )
              .animate()
              .slideY(
                begin: 0.08,
                end: 0,
                duration: 460.ms,
                curve: Curves.easeOutCubic,
              ),
        ),
      ),
    );
  }

  Widget _buildCameraState() {
    return Positioned.fill(
      child: Container(
        color: _bg.withValues(alpha: 0.86),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isInitializing) ...[
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(_cream),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Preparando visor',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: _cream,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Iniciando cámara...',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: _sage,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ] else if (_errorMessage != null) ...[
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _cream.withValues(alpha: 0.08),
                        border: Border.all(
                          color: _cream.withValues(alpha: 0.18),
                          width: 1,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          LucideIcons.triangleAlert,
                          size: 26,
                          color: _cream,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        color: _cream,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),
                    OutlinedButton(
                      onPressed: () => _enqueueOperation(_initializeCamera),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _cream,
                        side: BorderSide(
                          color: _cream.withValues(alpha: 0.4),
                          width: 1,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 11,
                        ),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        'Reintentar',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          color: _cream,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ],
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.96, 0.96),
                    end: const Offset(1, 1),
                    duration: 340.ms,
                    curve: Curves.easeOutCubic,
                  ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return Semantics(
      label: 'Capturar fotografía',
      button: true,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          splashColor: _cream.withValues(alpha: 0.10),
          highlightColor: _cream.withValues(alpha: 0.05),
          onTapDown: (_) {
            if (!_isTakingPicture) {
              setState(() => _isPressed = true);
            }
          },
          onTapUp: (_) {
            setState(() => _isPressed = false);
          },
          onTapCancel: () {
            setState(() => _isPressed = false);
          },
          onTap: _isTakingPicture ? null : _takePicture,
child: AnimatedOpacity(
            opacity: _isTakingPicture ? 0.55 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeIn,
            child: AnimatedScale(
              scale: _captureFeedback ? 0.88 : 1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeInOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeIn,
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _bg.withValues(alpha: 0.25),
                  border: Border.all(
                    color: _cream.withValues(alpha: 0.9),
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: AnimatedScale(
                  scale: _isPressed ? 0.92 : 1.0,
                  duration: const Duration(milliseconds: 110),
                  curve: Curves.easeInOut,
                  child: const Center(
                    child: Icon(
                      LucideIcons.camera,
                      size: 34,
                      color: _cream,
                    ),
                  ),
                ), // end inner AnimatedScale
              ), // end AnimatedContainer
            ), // end AnimatedScale (capture feedback)
          ), // end AnimatedOpacity
        ), // end InkWell
      ), // end Material
    ); // end Semantics
  }

  Widget _buildCaptureFeedbackLine() {
    if (!_captureFeedback) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _ObservationAreaPainter(
            showCaptureLine: true,
          ),
        ),
      ),
    );
  }

  Widget _buildZoomIndicator() {
    if (!_showZoomIndicator) return const SizedBox.shrink();
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 150,
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '${_zoomLevel.toStringAsFixed(1)}×',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: _cream,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFocusIndicator() {
    if (_focusPoint == null) return const SizedBox.shrink();

    const indicatorSize = 24.0;

    return Positioned(
      left: _focusPoint!.dx - indicatorSize / 2,
      top: _focusPoint!.dy - indicatorSize / 2,
      child: AnimatedScale(
        scale: _focusHiding ? 0.0 : 1.0,
        duration:
            Duration(milliseconds: _focusHiding ? 300 : 200),
        curve: Curves.easeInOut,
        onEnd: _focusHiding
            ? () {
                if (mounted && !_disposed) {
                  setState(() => _focusPoint = null);
                }
              }
            : null,
        child: SizedBox(
          width: indicatorSize,
          height: indicatorSize,
          child: CustomPaint(
            painter: _FocusCornerPainter(),
          ),
        ),
      ),
    );
  }
}

class _ObservationAreaPainter extends CustomPainter {
  final bool showCaptureLine;

  const _ObservationAreaPainter({this.showCaptureLine = false});

  @override
  void paint(Canvas canvas, Size size) {
    final cornerPaint = Paint()
      ..color = _cream.withValues(alpha: 0.5)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    const inset = 24.0;
    const cornerLength = 22.0;

    final corners = <Offset>[
      const Offset(inset, inset),
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      Offset(size.width - inset, size.height - inset),
    ];

    for (final corner in corners) {
      final horizontalDirection = corner.dx < size.width / 2 ? 1.0 : -1.0;
      final verticalDirection = corner.dy < size.height / 2 ? 1.0 : -1.0;
      canvas.drawLine(
        corner,
        Offset(corner.dx + horizontalDirection * cornerLength, corner.dy),
        cornerPaint,
      );
      canvas.drawLine(
        corner,
        Offset(corner.dx, corner.dy + verticalDirection * cornerLength),
        cornerPaint,
      );
    }

    // Organic growth marks (subtle, asymmetrical)
    final organicPaint = Paint()
      ..color = _cream.withValues(alpha: 0.22)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(inset + cornerLength + 5, inset + 3),
      Offset(inset + cornerLength + 11, inset + 7),
      organicPaint,
    );
    canvas.drawLine(
      Offset(size.width - inset - cornerLength - 5, inset + 3),
      Offset(size.width - inset - cornerLength - 11, inset + 7),
      organicPaint,
    );
    canvas.drawLine(
      Offset(inset + cornerLength + 5, size.height - inset - 3),
      Offset(inset + cornerLength + 11, size.height - inset - 7),
      organicPaint,
    );
    canvas.drawLine(
      Offset(size.width - inset - cornerLength - 5, size.height - inset - 3),
      Offset(size.width - inset - cornerLength - 11, size.height - inset - 7),
      organicPaint,
    );

    // Lichen-inspired organic details (branching, dots, curves)
    final lichenPaint = Paint()
      ..color = _sage.withValues(alpha: 0.28)
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final lichenDot = Paint()
      ..color = _sage.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    // Top-left corner area — small branching
    canvas.drawLine(
      Offset(inset - 3, inset + 18),
      Offset(inset - 6, inset + 22),
      lichenPaint,
    );
    canvas.drawLine(
      Offset(inset - 3, inset + 18),
      Offset(inset + 1, inset + 24),
      lichenPaint,
    );
    canvas.drawCircle(Offset(inset + 4, inset + 15), 0.7, lichenDot);
    canvas.drawCircle(Offset(inset - 4, inset + 26), 0.5, lichenDot);

    // Top-right corner area
    canvas.drawLine(
      Offset(size.width - inset + 3, inset + 18),
      Offset(size.width - inset + 6, inset + 22),
      lichenPaint,
    );
    canvas.drawLine(
      Offset(size.width - inset + 3, inset + 18),
      Offset(size.width - inset - 1, inset + 24),
      lichenPaint,
    );
    canvas.drawCircle(Offset(size.width - inset - 4, inset + 15), 0.7, lichenDot);
    canvas.drawCircle(Offset(size.width - inset + 4, inset + 26), 0.5, lichenDot);

    // Bottom-left corner area
    canvas.drawLine(
      Offset(inset - 3, size.height - inset - 18),
      Offset(inset - 6, size.height - inset - 22),
      lichenPaint,
    );
    canvas.drawLine(
      Offset(inset - 3, size.height - inset - 18),
      Offset(inset + 1, size.height - inset - 24),
      lichenPaint,
    );
    canvas.drawCircle(Offset(inset + 4, size.height - inset - 15), 0.7, lichenDot);
    canvas.drawCircle(Offset(inset - 4, size.height - inset - 26), 0.5, lichenDot);

    // Bottom-right corner area
    canvas.drawLine(
      Offset(size.width - inset + 3, size.height - inset - 18),
      Offset(size.width - inset + 6, size.height - inset - 22),
      lichenPaint,
    );
    canvas.drawLine(
      Offset(size.width - inset + 3, size.height - inset - 18),
      Offset(size.width - inset - 1, size.height - inset - 24),
      lichenPaint,
    );
    canvas.drawCircle(Offset(size.width - inset - 4, size.height - inset - 15), 0.7, lichenDot);
    canvas.drawCircle(Offset(size.width - inset + 4, size.height - inset - 26), 0.5, lichenDot);

    // Wavy curve near top edge (between corner markers)
    final curvePath = Path()
      ..moveTo(size.width / 2 - 40, inset - 4)
      ..quadraticBezierTo(size.width / 2 - 20, inset - 8, size.width / 2, inset - 4)
      ..quadraticBezierTo(size.width / 2 + 20, inset, size.width / 2 + 40, inset - 4);
    canvas.drawPath(curvePath, lichenPaint);

    // Wavy curve near bottom edge
    final bottomCurve = Path()
      ..moveTo(size.width / 2 - 30, size.height - inset + 4)
      ..quadraticBezierTo(size.width / 2 - 15, size.height - inset + 8, size.width / 2, size.height - inset + 4)
      ..quadraticBezierTo(size.width / 2 + 15, size.height - inset, size.width / 2 + 30, size.height - inset + 4);
    canvas.drawPath(bottomCurve, lichenPaint);

    // Center marker (small dot)
    final centerPaint = Paint()
      ..color = _cream.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      1.6,
      centerPaint,
    );

    // Capture feedback: thin line around observation area
    if (showCaptureLine) {
      final capturePaint = Paint()
        ..color = _cream.withValues(alpha: 0.55)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawRect(
        Rect.fromLTRB(inset, inset, size.width - inset, size.height - inset),
        capturePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ObservationAreaPainter oldDelegate) =>
      oldDelegate.showCaptureLine != showCaptureLine;
}

class _FocusCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _cream
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const inset = 2.0;
    const gap = 3.0;

    // Top-left
    canvas.drawLine(Offset(inset, inset + gap), Offset(inset, inset), paint);
    canvas.drawLine(Offset(inset, inset), Offset(inset + gap, inset), paint);
    // Top-right
    canvas.drawLine(
        Offset(size.width - inset - gap, inset),
        Offset(size.width - inset, inset),
        paint);
    canvas.drawLine(
        Offset(size.width - inset, inset),
        Offset(size.width - inset, inset + gap),
        paint);
    // Bottom-left
    canvas.drawLine(
        Offset(inset, size.height - inset - gap),
        Offset(inset, size.height - inset),
        paint);
    canvas.drawLine(
        Offset(inset, size.height - inset),
        Offset(inset + gap, size.height - inset),
        paint);
    // Bottom-right
    canvas.drawLine(
        Offset(size.width - inset - gap, size.height - inset),
        Offset(size.width - inset, size.height - inset),
        paint);
    canvas.drawLine(
        Offset(size.width - inset, size.height - inset),
        Offset(size.width - inset, size.height - inset - gap),
        paint);
  }

  @override
  bool shouldRepaint(covariant _FocusCornerPainter oldDelegate) => false;
}