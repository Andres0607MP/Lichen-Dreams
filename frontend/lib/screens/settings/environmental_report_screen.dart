import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../widgets/lichen_scaffold.dart';
import '../../widgets/app_theme.dart';
import '../../state/reports_state.dart';

class EnvironmentalReportScreen extends StatefulWidget {
  final int? reportId;

  const EnvironmentalReportScreen({super.key, this.reportId});

  @override
  State<EnvironmentalReportScreen> createState() => _EnvironmentalReportScreenState();
}

class _EnvironmentalReportScreenState extends State<EnvironmentalReportScreen> with SingleTickerProviderStateMixin {
  late final ReportsState _reportsState;
  late final AnimationController _heroController;
  late final Animation<double> _heroAnimation;

  @override
  void initState() {
    super.initState();
    _reportsState = ReportsState(
      apiService: Provider.of<ApiService>(context, listen: false),
    );
    if (widget.reportId != null) {
      _reportsState.getReportById(widget.reportId!);
    }

    _heroController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _heroAnimation = CurvedAnimation(parent: _heroController, curve: Curves.easeOutCubic);
    _heroController.forward();
  }

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LichenScaffold(
      apiService: Provider.of<ApiService>(context, listen: false),
      showBottomNav: false,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Resumen ambiental',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListenableBuilder(
        listenable: _reportsState,
        builder: (context, _) {
          final report = widget.reportId != null
              ? (_reportsState.currentReport?['id_reporte'] == widget.reportId
                  ? _reportsState.currentReport
                  : null)
              : _reportsState.currentReport;

          if (_reportsState.loading && report == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.primaryGreen),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando resumen…',
                    style: GoogleFonts.poppins(fontSize: 13, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }

          if (_reportsState.error != null && report == null) {
            return _buildErrorState(colorScheme);
          }

          if (report == null) {
            return _buildEmptyState(colorScheme);
          }

          final stats = report['datos_reporte'] is Map
              ? Map<String, dynamic>.from(report['datos_reporte'] as Map)
              : <String, dynamic>{};
          final fecha = DateTime.tryParse(report['fecha_generacion']?.toString() ?? '') ?? DateTime.now();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroSection(report: report, stats: stats, fecha: fecha, colorScheme: colorScheme, animation: _heroAnimation),
                    const SizedBox(height: 20),
                    _QuickStatsGrid(stats: stats, colorScheme: colorScheme),
                    const SizedBox(height: 20),
                    if (stats['liquidos_saludables'] != null || stats['liquidos_afectados'] != null || stats['liquidos_desconocidos'] != null)
                      _LichenDistributionSection(stats: stats, colorScheme: colorScheme),
                    if (stats['liquidos_saludables'] != null || stats['liquidos_afectados'] != null || stats['liquidos_desconocidos'] != null)
                      const SizedBox(height: 20),
                    _AirQualitySection(stats: stats, colorScheme: colorScheme),
                    const SizedBox(height: 20),
                    if (stats['temperatura_promedio'] != null || stats['humedad_promedio'] != null || stats['nivel_contaminacion_predominante'] != null)
                      _AmbientConditionsSection(stats: stats, colorScheme: colorScheme),
                    if (stats['temperatura_promedio'] != null || stats['humedad_promedio'] != null || stats['nivel_contaminacion_predominante'] != null)
                      const SizedBox(height: 20),
                    _InsightsSection(stats: stats, colorScheme: colorScheme),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(ColorScheme colorScheme) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 64, color: AppTheme.errorColor.withValues(alpha: 0.3)),
              const SizedBox(height: 24),
              Text(
                'No se pudo cargar el reporte',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _reportsState.error ?? 'Ocurrió un error inesperado.',
                style: GoogleFonts.poppins(fontSize: 14, color: colorScheme.onSurfaceVariant, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  if (widget.reportId != null) {
                    _reportsState.getReportById(widget.reportId!);
                  }
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.eco_rounded, size: 64, color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
              const SizedBox(height: 24),
              Text(
                'Genera tu primer resumen ambiental',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Necesitas tener análisis registrados para generar un resumen ambiental basado en tus resultados.',
                style: GoogleFonts.poppins(fontSize: 14, color: colorScheme.onSurfaceVariant, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  if (_reportsState.generating) return;
                  final now = DateTime.now();
                  final title = 'Resumen ambiental ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
                  _reportsState.generateReport(title: title).then((result) {
                    if (result == null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_reportsState.error ?? 'No se pudo generar el reporte'),
                          backgroundColor: AppTheme.errorColor,
                        ),
                      );
                    }
                  });
                },
                icon: _reportsState.generating
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_graph_rounded),
                label: Text(_reportsState.generating ? 'Generando...' : 'Generar resumen'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final Map<String, dynamic> report;
  final Map<String, dynamic> stats;
  final DateTime fecha;
  final ColorScheme colorScheme;
  final Animation<double> animation;

  const _HeroSection({
    required this.report,
    required this.stats,
    required this.fecha,
    required this.colorScheme,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final quality = (stats['calidad_aire_predominante']?.toString() ?? 'desconocida').toLowerCase();
    final qualityColor = _qualityColor(quality);
    final title = report['titulo']?.toString() ?? 'Resumen ambiental';

    return FadeTransition(
      opacity: animation,
      child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: AppTheme.shadow08, blurRadius: 28, offset: const Offset(0, 10)),
            ],
          ),
          child: Material(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 520;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _VitacoraAsset(size: 72),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Resumen ambiental',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryGreen,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                title,
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textDark,
                                  height: 1.25,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              _DateBadge(fecha: fecha),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        _QualityRadialGauge(quality: quality, color: qualityColor),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _VitacoraAsset(size: 56),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Resumen ambiental',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryGreen,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  title,
                                  style: GoogleFonts.poppins(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textDark,
                                    height: 1.25,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _DateBadge(fecha: fecha)),
                          const SizedBox(width: 12),
                          _QualityRadialGauge(quality: quality, color: qualityColor),
                        ],
                      ),
                    ],
                  );
                },
            ),
          ),
        ),
      ),
    );
  }

  Color _qualityColor(String quality) {
    switch (quality) {
      case 'buena':
        return AppTheme.successColor;
      case 'mala':
        return AppTheme.errorColor;
      case 'moderada':
        return AppTheme.warningColor;
      default:
        return AppTheme.textGray;
    }
  }
}

class _VitacoraAsset extends StatelessWidget {
  final double size;
  const _VitacoraAsset({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGreen.withValues(alpha: 0.12),
            AppTheme.lightGreen.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.22),
        child: Image.asset(
          'assets/images/vitacora.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  final DateTime fecha;
  const _DateBadge({required this.fecha});

  @override
  Widget build(BuildContext context) {
    const months = ['Ene','Feb','Mar','Abr','Mayo','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    final day = fecha.day.toString().padLeft(2, '0');
    final month = months[fecha.month - 1];
    final year = fecha.year;
    final hour = fecha.hour.toString().padLeft(2, '0');
    final minute = fecha.minute.toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen10,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$day $month $year · $hour:$minute',
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppTheme.primaryGreen,
        ),
      ),
    );
  }
}

class _QualityRadialGauge extends StatelessWidget {
  final String quality;
  final Color color;

  const _QualityRadialGauge({required this.quality, required this.color});

  @override
  Widget build(BuildContext context) {
    final label = _translateQuality(quality);
    final displayQuality = label.length > 10 ? label.substring(0, 10) : label;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return SizedBox(
          width: 120,
          height: 120,
          child: CustomPaint(
            painter: _RadialGaugePainter(
              progress: value,
              color: color,
              backgroundColor: AppTheme.borderColor.withValues(alpha: 0.25),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    displayQuality,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'CALIDAD',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textGray,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _translateQuality(String quality) {
    const map = {
      'buena': 'Buena',
      'mala': 'Mala',
      'moderada': 'Moderada',
      'desconocida': 'N/D',
    };
    return map[quality.toLowerCase()] ?? quality;
  }
}

class _RadialGaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _RadialGaugePainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final startAngle = math.pi * 0.75;
    final sweepAngle = math.pi * 1.5;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadialGaugePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _QuickStatsGrid extends StatelessWidget {
  final Map<String, dynamic> stats;
  final ColorScheme colorScheme;

  const _QuickStatsGrid({required this.stats, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final items = [
      _QuickStatItem(label: 'Análisis', value: '${stats['total_analisis'] ?? 0}', icon: Icons.analytics_rounded, color: AppTheme.primaryGreen),
      _QuickStatItem(label: 'Zonas', value: '${stats['zonas_analizadas'] ?? 0}', icon: Icons.place_rounded, color: AppTheme.mapaPrimary),
      _QuickStatItem(label: 'Saludables', value: '${stats['liquidos_saludables'] ?? 0}', icon: Icons.favorite_rounded, color: AppTheme.successColor),
      _QuickStatItem(label: 'Afectados', value: '${stats['liquidos_afectados'] ?? 0}', icon: Icons.warning_amber_rounded, color: AppTheme.errorColor),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 480 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.05,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 16 * (1 - value)),
                  child: Opacity(opacity: value, child: items[index]),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _QuickStatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _QuickStatItem({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: AppTheme.shadow05, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textGray,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LichenDistributionSection extends StatelessWidget {
  final Map<String, dynamic> stats;
  final ColorScheme colorScheme;

  const _LichenDistributionSection({required this.stats, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final healthy = (stats['liquidos_saludables'] ?? 0) is int
        ? stats['liquidos_saludables'] as int
        : int.tryParse('${stats['liquidos_saludables'] ?? 0}') ?? 0;
    final affected = (stats['liquidos_afectados'] ?? 0) is int
        ? stats['liquidos_afectados'] as int
        : int.tryParse('${stats['liquidos_afectados'] ?? 0}') ?? 0;
    final unknown = (stats['liquidos_desconocidos'] ?? 0) is int
        ? stats['liquidos_desconocidos'] as int
        : int.tryParse('${stats['liquidos_desconocidos'] ?? 0}') ?? 0;
    final total = healthy + affected + unknown;

    if (total == 0) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppTheme.shadow05, blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 420;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estado de los líquenes',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Distribución de resultados',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppTheme.textGray,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _LichenLegend(label: 'Saludables', value: healthy, total: total, color: AppTheme.successColor),
                          const SizedBox(height: 12),
                          _LichenLegend(label: 'Afectados', value: affected, total: total, color: AppTheme.errorColor),
                          const SizedBox(height: 12),
                          _LichenLegend(label: 'Desconocidos', value: unknown, total: total, color: AppTheme.textGray),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: _DonutChart(healthy: healthy, affected: affected, unknown: unknown),
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estado de los líquenes',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Distribución de resultados',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppTheme.textGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        height: 110,
                        child: _DonutChart(healthy: healthy, affected: affected, unknown: unknown),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _LichenLegend(label: 'Saludables', value: healthy, total: total, color: AppTheme.successColor),
                  const SizedBox(height: 10),
                  _LichenLegend(label: 'Afectados', value: affected, total: total, color: AppTheme.errorColor),
                  const SizedBox(height: 10),
                  _LichenLegend(label: 'Desconocidos', value: unknown, total: total, color: AppTheme.textGray),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LichenLegend extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;

  const _LichenLegend({required this.label, required this.value, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? value / total : 0.0;
    final percentage = total > 0 ? '${(fraction * 100).round()}%' : '0%';

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textDark,
            ),
          ),
        ),
        Text(
          '$value',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          percentage,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textGray,
          ),
        ),
      ],
    );
  }
}

class _DonutChart extends StatelessWidget {
  final int healthy;
  final int affected;
  final int unknown;

  const _DonutChart({required this.healthy, required this.affected, required this.unknown});

  @override
  Widget build(BuildContext context) {
    final total = healthy + affected + unknown;
    if (total == 0) return const SizedBox.shrink();

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return CustomPaint(
          painter: _DonutChartPainter(
            healthy: healthy.toDouble(),
            affected: affected.toDouble(),
            unknown: unknown.toDouble(),
            progress: value,
          ),
        );
      },
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final double healthy;
  final double affected;
  final double unknown;
  final double progress;

  _DonutChartPainter({
    required this.healthy,
    required this.affected,
    required this.unknown,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final strokeWidth = 14.0;
    final startAngle = -math.pi / 2;
    final total = healthy + affected + unknown;

    final segments = <double>[
      healthy / total,
      affected / total,
      unknown / total,
    ];

    final colors = <Color>[
      AppTheme.successColor,
      AppTheme.errorColor,
      AppTheme.textGray,
    ];

    var currentStart = startAngle;
    final sweep = math.pi * 2 * progress;

    for (var i = 0; i < segments.length; i++) {
      final sweepAngle = segments[i] * sweep;
      if (sweepAngle <= 0) continue;

      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentStart,
        sweepAngle,
        false,
        paint,
      );

      currentStart += sweepAngle + 0.04;
    }

    final holePaint = Paint()..color = AppTheme.surfaceColor;
    canvas.drawCircle(center, radius - strokeWidth / 2, holePaint);
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _AirQualitySection extends StatelessWidget {
  final Map<String, dynamic> stats;
  final ColorScheme colorScheme;

  const _AirQualitySection({required this.stats, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final quality = (stats['calidad_aire_predominante']?.toString() ?? 'desconocida').toLowerCase();
    final color = _qualityColor(quality);
    final label = _translateQuality(quality);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppTheme.shadow05, blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.air_rounded, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calidad del aire',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textGray,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              if (stats['nivel_contaminacion_predominante'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.warningEnvironmental.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    stats['nivel_contaminacion_predominante'].toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warningEnvironmental,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _translateQuality(String quality) {
    const map = {
      'buena': 'Buena',
      'mala': 'Mala',
      'moderada': 'Moderada',
      'desconocida': 'N/D',
    };
    return map[quality] ?? quality;
  }

  Color _qualityColor(String quality) {
    switch (quality) {
      case 'buena':
        return AppTheme.primaryGreen;
      case 'mala':
        return AppTheme.errorColor;
      case 'moderada':
        return AppTheme.warningColor;
      default:
        return AppTheme.textGray;
    }
  }
}

class _AmbientConditionsSection extends StatelessWidget {
  final Map<String, dynamic> stats;
  final ColorScheme colorScheme;

  const _AmbientConditionsSection({required this.stats, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    if (stats['temperatura_promedio'] != null) {
      items.add(_AmbientChip(
        icon: Icons.thermostat_rounded,
        label: 'Temperatura',
        value: '${stats['temperatura_promedio']} °C',
        color: AppTheme.alertColor,
      ));
    }
    if (stats['humedad_promedio'] != null) {
      items.add(_AmbientChip(
        icon: Icons.water_drop_rounded,
        label: 'Humedad',
        value: '${stats['humedad_promedio']} %',
        color: AppTheme.mapaPrimary,
      ));
    }
    if (stats['nivel_contaminacion_predominante'] != null) {
      items.add(_AmbientChip(
        icon: Icons.cloud_rounded,
        label: 'Contaminación',
        value: stats['nivel_contaminacion_predominante'].toString(),
        color: AppTheme.warningEnvironmental,
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppTheme.shadow05, blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Condiciones ambientales',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 360;
                  if (isWide) {
                    return Row(
                      children: [
                        for (final item in items) ...[
                          Expanded(child: item),
                          if (item != items.last) const SizedBox(width: 12),
                        ],
                      ],
                    );
                  }
                  return Column(
                    children: [
                      for (final item in items) ...[
                        SizedBox(width: double.infinity, child: item),
                        if (item != items.last) const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmbientChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _AmbientChip({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textGray,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsSection extends StatelessWidget {
  final Map<String, dynamic> stats;
  final ColorScheme colorScheme;

  const _InsightsSection({required this.stats, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final insights = <_Insight>[];

    final healthy = (stats['liquidos_saludables'] ?? 0) is int
        ? stats['liquidos_saludables'] as int
        : int.tryParse('${stats['liquidos_saludables'] ?? 0}') ?? 0;
    final affected = (stats['liquidos_afectados'] ?? 0) is int
        ? stats['liquidos_afectados'] as int
        : int.tryParse('${stats['liquidos_afectados'] ?? 0}') ?? 0;
    final total = healthy + affected;

    if (healthy > affected && total > 0) {
      insights.add(_Insight(
        icon: Icons.eco_rounded,
        title: 'Buena presencia de líquenes',
        description: 'La mayoría de los análisis registrados corresponden a líquenes saludables.',
        color: AppTheme.successColor,
      ));
    } else if (affected > healthy && total > 0) {
      insights.add(_Insight(
        icon: Icons.warning_amber_rounded,
        title: 'Líquenes afectados detectados',
        description: 'Se encontraron análisis con indicios de contaminación. Revisa las zonas más expuestas.',
        color: AppTheme.errorColor,
      ));
    }

    final zonas = stats['zonas_analizadas'] ?? 0;
    if (zonas > 0) {
      insights.add(_Insight(
        icon: Icons.place_rounded,
        title: 'Cobertura ambiental',
        description: 'Se analizaron $zonas ${zonas == 1 ? 'zona diferente' : 'zonas diferentes'}.',
        color: AppTheme.mapaPrimary,
      ));
    }

    if (insights.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppTheme.shadow05, blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lo que encontramos',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 14),
              ...insights.map((insight) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: insight.color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(insight.icon, size: 18, color: insight.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            insight.title,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            insight.description,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppTheme.textGray,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _Insight {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _Insight({required this.icon, required this.title, required this.description, required this.color});
}