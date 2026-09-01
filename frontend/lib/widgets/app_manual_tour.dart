import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../routes/route_names.dart';

/// Manual interactivo de Lichen Dreams.
///
/// Tour secuencial clásico con PageView:
/// Acceso → Dashboard → Analizar → Imagen → Especie → Ubicación → IA →
/// Confirmar imagen → Resultado → Guardar → Historial → Mapa → Liquenpedia.
class AppManualTour {
  static void show(BuildContext context) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Material(
        color: Colors.black.withValues(alpha: 0.72),
        child: SafeArea(child: _TourScreen(onClose: () => entry.remove())),
      ),
    );
    overlay.insert(entry);
  }
}

class _TourScreen extends StatefulWidget {
  final VoidCallback onClose;
  const _TourScreen({required this.onClose});
  @override
  State<_TourScreen> createState() => _TourScreenState();
}

class _TourScreenState extends State<_TourScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _showingWelcome = true;
  bool _navigating = false;

  late final AnimationController _entranceController;
  late final Animation<double> _entranceFade;
  late final Animation<double> _entranceScale;
  late final Animation<Offset> _entranceSlide;

  static const List<_TourStep> _steps = [
    _TourStep(
      icon: Icons.login_rounded,
      title: 'Acceso',
      description: 'Inicia sesión o crea tu cuenta.',
      details:
          'Accede con tu correo y contraseña, o con Google. Sin cuenta no puedes '
          'guardar análisis ni consultar tu historial.',
      route: AppRoutes.login,
    ),
    _TourStep(
      icon: Icons.dashboard_rounded,
      title: 'Dashboard',
      description: 'Tu centro de control principal.',
      details:
          'El Dashboard reúne tus estadísticas, accesos rápidos y actividad '
          'reciente para empezar a analizar en un solo toque.',
      route: AppRoutes.dashboard,
    ),
    _TourStep(
      icon: Icons.document_scanner_rounded,
      title: 'Analizar',
      description: 'Inicia un análisis con un líquen.',
      details:
          'Pulsa "Analizar" para abrir la cámara y comenzar un nuevo análisis '
          'ambiental del líquen que observas.',
      route: AppRoutes.analisis,
    ),
    _TourStep(
      icon: Icons.camera_alt_rounded,
      title: 'Imagen',
      description: 'Captura o selecciona la fotografía.',
      details:
          'Toma una foto clara del líquen o selecciónala de tu galería. La '
          'imagen es la entrada que luego analiza la IA.',
    ),
    _TourStep(
      icon: Icons.category_rounded,
      title: 'Especie',
      description: 'Indica la especie que reconoces.',
      details:
          'Si reconoces el líquen, selecciónalo del catálogo de especies. '
          'La especie la eliges TÚ: no es un resultado de la IA.',
    ),
    _TourStep(
      icon: Icons.location_on_rounded,
      title: 'Ubicación',
      description: 'Registra dónde observaste el líquen.',
      details:
          'Agrega el punto GPS donde encontraste el líquen. La ubicación permite '
          'ubicar el análisis en el mapa y en las zonas ambientales.',
      route: AppRoutes.location,
    ),
    _TourStep(
      icon: Icons.smart_toy_rounded,
      title: 'IA',
      description: 'La IA analiza el estado del líquen.',
      details:
          'La IA evalúa si el líquen está saludable, contaminado o desconocido. '
          'No identifica especies.',
    ),
    _TourStep(
      icon: Icons.image_rounded,
      title: 'Confirmar imagen',
      description: 'Revisa que la foto sea correcta.',
      details:
          'Antes de enviar, confirma la imagen capturada para asegurar que el '
          'líquen se vea con claridad.',
    ),
    _TourStep(
      icon: Icons.assessment_rounded,
      title: 'Resultado',
      description: 'Observa el estado ambiental del líquen.',
      details:
          'El resultado indica la condición del líquen: saludable, afectado o '
          'desconocido, junto con el análisis detallado.',
    ),
    _TourStep(
      icon: Icons.save_rounded,
      title: 'Guardar',
      description: 'El análisis queda guardado.',
      details:
          'Al guardar, el análisis se registra para que puedas consultarlo '
          'después en el historial y verlo en el mapa.',
    ),
    _TourStep(
      icon: Icons.history_rounded,
      title: 'Historial',
      description: 'Consulta tus análisis anteriores.',
      details:
          'El historial agrupa todos tus análisis para revisar resultados, '
          'fechas y especies registradas.',
      route: AppRoutes.historial,
    ),
    _TourStep(
      icon: Icons.map_rounded,
      title: 'Mapa',
      description: 'Visualiza los análisis en el mapa.',
      details:
          'Los análisis compartidos aparecen como puntos ambientales en el mapa '
          'con su condición y ubicación geográfica.',
      route: AppRoutes.mapa,
    ),
    _TourStep(
      icon: Icons.menu_book_rounded,
      title: 'Liquenpedia',
      description: 'Aprende sobre los líquenes.',
      details:
          'Liquenpedia es la enciclopedia educativa del proyecto: descubre '
          'especies, hábitats y cómo interpretar la calidad del aire.',
      route: AppRoutes.liquenpedia,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _entranceFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _entranceScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );
    _entranceSlide =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
          ),
        );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!MediaQuery.of(context).disableAnimations) {
        _entranceController.forward();
      } else {
        _entranceController.value = 1.0;
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  bool get _disableAnimations => MediaQuery.of(context).disableAnimations;

  void _nextPage() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToStep(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _close() {
    if (_navigating) return;
    _navigating = true;
    widget.onClose();
  }

  void _goToSection(String route) {
    if (_navigating) return;
    _navigating = true;
    final navigator = Navigator.of(context, rootNavigator: true);
    widget.onClose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_navigating) return;
      try {
        navigator.pushNamed(route);
      } catch (_) {
        // Ruta no disponible: mantenemos la app abierta sin crashear.
      }
      _navigating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 8 : 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              height: size.height * 0.85,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: SafeArea(
                top: false,
                child: _showingWelcome
                    ? _buildWelcome()
                    : _buildTourContent(cs, isMobile, bottomPadding),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcome() {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        Positioned(top: 8, right: 8, child: _CloseButton(onClose: _close)),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomPadding),
          child: AnimatedBuilder(
            animation: _entranceController,
            builder: (context, child) {
              return Opacity(
                opacity: _entranceFade.value,
                child: Transform.scale(
                  scale: _entranceScale.value,
                  child: SlideTransition(
                    position: _entranceSlide,
                    child: child,
                  ),
                ),
              );
            },
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: const SizedBox(height: 56),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: isMobile ? 80 : 100,
                        height: isMobile ? 80 : 100,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              cs.primary.withValues(alpha: 0.65),
                              cs.primary.withValues(alpha: 0.18),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withValues(alpha: 0.35),
                              blurRadius: 28,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.eco_rounded,
                          size: isMobile ? 40 : 48,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                      SizedBox(height: isMobile ? 24 : 32),
                      Text(
                        'Conoce Lichen Dreams',
                        style: GoogleFonts.poppins(
                          fontSize: isMobile ? 22 : 26,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Descubre, en pocos pasos, cómo funciona el análisis '
                        'ambiental de líquenes en Lichen Dreams.',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isMobile ? 28 : 40),
                      FilledButton(
                        onPressed: () {
                          setState(() => _showingWelcome = false);
                          if (!_disableAnimations) {
                            _entranceController.forward(from: 0);
                          }
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Comenzar',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTourContent(
    ColorScheme cs,
    bool isMobile,
    double bottomPadding,
  ) {
    return Column(
      children: [
        _buildHeader(cs),
        _buildProgressIndicator(cs),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _steps.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) =>
                _buildStepCard(cs, index, isMobile),
          ),
        ),
        _buildNavigationBar(cs, isMobile, bottomPadding),
      ],
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, isMobile ? 12 : 16, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Manual interactivo',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ),
          _CloseButton(onClose: _close),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: List.generate(_steps.length, (index) {
          final isActive = index == _currentPage;
          final isCompleted = index < _currentPage;
          return Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: isActive || isCompleted ? cs.primary : cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepCard(ColorScheme cs, int index, bool isMobile) {
    final step = _steps[index];
    final hasRoute = step.route != null;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: isMobile ? 16 : 24),
          _buildStepIcon(cs, step, isMobile),
          SizedBox(height: isMobile ? 20 : 24),
          Text(
            step.title,
            style: GoogleFonts.poppins(
              fontSize: isMobile ? 20 : 22,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            step.description,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            step.details,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (hasRoute) ...[
            SizedBox(height: isMobile ? 20 : 28),
            FilledButton.icon(
              onPressed: () => _goToSection(step.route!),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(
                'Explorar esta función',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
          SizedBox(height: isMobile ? 16 : 20),
          if (_currentPage < _steps.length - 1)
            _buildNextStepsPreview(cs, index),
        ],
      ),
    );
  }

  Widget _buildStepIcon(ColorScheme cs, _TourStep step, bool isMobile) {
    return Container(
      width: isMobile ? 64 : 80,
      height: isMobile ? 64 : 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: 0.15),
            cs.primary.withValues(alpha: 0.05),
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: cs.primary.withValues(alpha: 0.3), width: 2),
      ),
      child: Icon(step.icon, size: isMobile ? 28 : 36, color: cs.primary),
    );
  }

  Widget _buildNextStepsPreview(ColorScheme cs, int currentIndex) {
    final nextSteps = _steps.skip(currentIndex + 1).take(3).toList();
    if (nextSteps.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 16),
        Divider(color: cs.outlineVariant.withValues(alpha: 0.5)),
        const SizedBox(height: 16),
        Text(
          'Próximos pasos',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: nextSteps.map((step) {
            return ActionChip(
              avatar: Icon(step.icon, size: 16, color: cs.onSurfaceVariant),
              label: Text(step.title, style: GoogleFonts.poppins(fontSize: 11)),
              backgroundColor: cs.surfaceContainerHighest,
              side: BorderSide(color: cs.outlineVariant),
              onPressed: () => _goToStep(_steps.indexOf(step)),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNavigationBar(
    ColorScheme cs,
    bool isMobile,
    double bottomPadding,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 20,
        12,
        isMobile ? 16 : 20,
        12 + bottomPadding,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentPage > 0)
              TextButton.icon(
                onPressed: _previousPage,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: Text(
                  'Anterior',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
              )
            else
              const SizedBox(width: 100),
            const Spacer(),
            Text(
              '${_currentPage + 1} / ${_steps.length}',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            if (_currentPage < _steps.length - 1)
              TextButton.icon(
                onPressed: _nextPage,
                icon: Text(
                  'Siguiente',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                label: const Icon(Icons.arrow_forward_rounded, size: 18),
              )
            else
              FilledButton(
                onPressed: _close,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Finalizar',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onClose;
  const _CloseButton({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Cerrar manual',
      child: Material(
        color: cs.surfaceContainer.withValues(alpha: 0.85),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onClose,
          customBorder: const CircleBorder(),
          child: Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            child: Icon(Icons.close_rounded, size: 26, color: cs.onSurface),
          ),
        ),
      ),
    );
  }
}

class _TourStep {
  final IconData icon;
  final String title;
  final String description;
  final String details;
  final String? route;

  const _TourStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.details,
    this.route,
  });
}
