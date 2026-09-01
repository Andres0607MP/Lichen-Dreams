import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../routes/route_names.dart';

class AppManualTour {
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) => const _TourSheet(),
    );
  }
}

class _TourSheet extends StatefulWidget {
  const _TourSheet();

  @override
  State<_TourSheet> createState() => _TourSheetState();
}

class _TourSheetState extends State<_TourSheet> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _showingWelcome = true;

  static const List<_TourStep> _steps = [
    _TourStep(
      icon: Icons.login_rounded,
      title: 'Acceso',
      description:
          'Inicia sesión o crea una cuenta para comenzar a explorar el mundo de los líquenes.',
      route: AppRoutes.login,
    ),
    _TourStep(
      icon: Icons.dashboard_rounded,
      title: 'Dashboard',
      description:
          'Tu centro de control. Accede a todas las funcionalidades y consulta tu actividad reciente.',
      route: AppRoutes.dashboard,
    ),
    _TourStep(
      icon: Icons.document_scanner_rounded,
      title: 'Analizar un líquen',
      description:
          'Captura o selecciona una imagen de un líquen para comenzar el análisis con inteligencia artificial.',
      route: AppRoutes.analisis,
    ),
    _TourStep(
      icon: Icons.camera_alt_rounded,
      title: 'Imagen',
      description:
          'Toma una foto con tu cámara o selecciona una imagen de tu galería. La imagen debe mostrar claramente el líquen.',
    ),
    _TourStep(
      icon: Icons.location_on_rounded,
      title: 'Ubicación',
      description:
          'La ubicación contextualiza tu análisis y permite mapear la calidad ambiental de tu zona.',
      route: AppRoutes.location,
    ),
    _TourStep(
      icon: Icons.smart_toy_rounded,
      title: 'Inteligencia Artificial',
      description:
          'Nuestro modelo de IA analiza la imagen para identificar la especie y evaluar la calidad ambiental.',
    ),
    _TourStep(
      icon: Icons.assessment_rounded,
      title: 'Resultado',
      description:
          'Obtén un informe detallado con la especie identificada, nivel de calidad ambiental y recomendaciones.',
    ),
    _TourStep(
      icon: Icons.save_rounded,
      title: 'Guardar análisis',
      description:
          'Guarda tus análisis para consultarlos después y llevar un registro de tus observaciones.',
    ),
    _TourStep(
      icon: Icons.history_rounded,
      title: 'Historial',
      description:
          'Consulta todos tus análisis anteriores, filtralos y revisa la evolución ambiental de tus zonas.',
      route: AppRoutes.historial,
    ),
    _TourStep(
      icon: Icons.map_rounded,
      title: 'Mapa',
      description:
          'Visualiza tus análisis y los de la comunidad en un mapa interactivo de calidad ambiental.',
      route: AppRoutes.mapa,
    ),
    _TourStep(
      icon: Icons.menu_book_rounded,
      title: 'Liquenpedia',
      description:
          'Consulta artículos, estudios y el conocimiento colectivo sobre especies de líquenes.',
      route: AppRoutes.liquenpedia,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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

  void _close() => Navigator.of(context).pop();

  void _goToSection(String route) {
    Navigator.of(context).pop();
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: _showingWelcome
            ? _WelcomeScreen(
                onStart: () => setState(() => _showingWelcome = false),
                onClose: _close,
              )
            : _buildTourContent(colorScheme, bottomPadding),
      ),
    );
  }

  Widget _buildTourContent(ColorScheme colorScheme, double bottomPadding) {
    return Column(
      children: [
        _buildHeader(colorScheme),
        _buildProgressIndicator(colorScheme),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _steps.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) => _buildStepCard(colorScheme, index),
          ),
        ),
        _buildNavigationBar(colorScheme, bottomPadding),
      ],
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Recorrido',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            onPressed: _close,
            icon: Icon(
              Icons.close_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Cerrar',
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: List.generate(_steps.length, (index) {
          final isActive = index == _currentPage;
          final isCompleted = index < _currentPage;
          return Expanded(
            child:
                Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: isActive || isCompleted
                            ? colorScheme.primary
                            : colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    )
                    .animate(target: isActive ? 1 : 0)
                    .scaleX(
                      begin: index == _currentPage ? 0.5 : 1,
                      duration: 200.ms,
                    ),
          );
        }),
      ),
    );
  }

  Widget _buildStepCard(ColorScheme colorScheme, int index) {
    final step = _steps[index];
    final hasRoute = step.route != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          _buildStepIcon(colorScheme, step, index),
          const SizedBox(height: 24),
          Text(
            step.title,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: 12),
          Text(
                step.description,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              )
              .animate()
              .fadeIn(duration: 300.ms, delay: 100.ms)
              .slideY(begin: 0.1, end: 0),
          if (hasRoute) ...[
            const SizedBox(height: 28),
            FilledButton.icon(
                  onPressed: () => _goToSection(step.route!),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(
                    'Ir allí',
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
                )
                .animate()
                .fadeIn(duration: 300.ms, delay: 200.ms)
                .slideY(begin: 0.1, end: 0),
          ],
          const SizedBox(height: 20),
          if (_currentPage < _steps.length - 1)
            _buildNextStepsPreview(colorScheme, index),
        ],
      ),
    );
  }

  Widget _buildStepIcon(ColorScheme colorScheme, _TourStep step, int index) {
    return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary.withValues(alpha: 0.15),
                colorScheme.primary.withValues(alpha: 0.05),
              ],
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Icon(step.icon, size: 36, color: colorScheme.primary),
        )
        .animate()
        .scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1, 1),
          duration: 400.ms,
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: 300.ms);
  }

  Widget _buildNextStepsPreview(ColorScheme colorScheme, int currentIndex) {
    final nextSteps = _steps.skip(currentIndex + 1).take(3).toList();
    if (nextSteps.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 16),
        Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        const SizedBox(height: 16),
        Text(
          'Próximos pasos',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: nextSteps.asMap().entries.map((entry) {
            final step = entry.value;
            return ActionChip(
              avatar: Icon(
                step.icon,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              label: Text(step.title, style: GoogleFonts.poppins(fontSize: 11)),
              backgroundColor: colorScheme.surfaceContainerHighest,
              side: BorderSide(color: colorScheme.outlineVariant),
              onPressed: () => _goToStep(_steps.indexOf(step)),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNavigationBar(ColorScheme colorScheme, double bottomPadding) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomPadding),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
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
              color: colorScheme.onSurfaceVariant,
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
    );
  }
}

class _WelcomeScreen extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onClose;

  const _WelcomeScreen({required this.onStart, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomPadding),
      child: Column(
        children: [
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              onPressed: onClose,
              icon: Icon(
                Icons.close_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
              tooltip: 'Cerrar',
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.primary.withValues(alpha: 0.2),
                            colorScheme.primary.withValues(alpha: 0.05),
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.eco_rounded,
                        size: 48,
                        color: colorScheme.primary,
                      ),
                    )
                    .animate()
                    .scale(
                      begin: const Offset(0.5, 0.5),
                      end: const Offset(1, 1),
                      duration: 600.ms,
                      curve: Curves.elasticOut,
                    )
                    .fadeIn(duration: 400.ms),
                const SizedBox(height: 32),
                Text(
                      'Conoce Lichen Dreams',
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 200.ms)
                    .slideY(begin: 0.1, end: 0),
                const SizedBox(height: 12),
                Text(
                      'Te mostramos paso a paso cómo aprovechar la aplicación.',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 300.ms)
                    .slideY(begin: 0.1, end: 0),
                const SizedBox(height: 40),
                FilledButton(
                      onPressed: onStart,
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
                        'Comenzar recorrido',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 400.ms)
                    .slideY(begin: 0.1, end: 0),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TourStep {
  final IconData icon;
  final String title;
  final String description;
  final String? route;

  const _TourStep({
    required this.icon,
    required this.title,
    required this.description,
    this.route,
  });
}
