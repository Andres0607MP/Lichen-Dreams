import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/dashboard_stats_detail.dart';
import '../state/history_state.dart';
import '../state/dashboard_state.dart';
import '../widgets/app_theme.dart';
import '../widgets/modern_widgets.dart';

class DashboardStatsDetailSheet extends StatelessWidget {
  const DashboardStatsDetailSheet({super.key});
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const DashboardStatsDetailSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: const _StatsDetailContent(),
        );
      },
    );
  }
}

class _StatsDetailContent extends StatelessWidget {
  const _StatsDetailContent();
  @override
  Widget build(BuildContext context) {
    return Consumer2<HistoryState, DashboardState>(
      builder: (context, historyState, dashboardState, child) {
        if (historyState.loading && historyState.history.isEmpty) {
          return const _LoadingView();
        }
        if (historyState.error != null && historyState.history.isEmpty) {
          return _ErrorView(error: historyState.error!);
        }
        final detail = DashboardStatsDetail.fromHistory(
          history: historyState.history,
          stats: dashboardState.stats,
        );
        return Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  _HeroCard(detail: detail),
                  const SizedBox(height: 16),
                  _ActivityChart(detail: detail),
                  const SizedBox(height: 16),
                  _EnvironmentalDistributionChart(
                    distribution: detail.environmentalDistribution,
                  ),
                  const SizedBox(height: 16),
                  _MetricsGrid(detail: detail),
                  if (detail.totalAnalyses == 0) _EmptyState(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.historialPrimary.withValues(alpha: 0.08),
            Theme.of(context).scaffoldBackgroundColor,
          ],
        ),
        border: const Border(
          bottom: BorderSide(color: AppTheme.borderColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.historialPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.eco_rounded,
              size: 24,
              color: AppTheme.historialPrimary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumen de actividad',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Estado general de tus exploraciones',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 24),
            onPressed: () => Navigator.pop(context),
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final DashboardStatsDetail detail;
  const _HeroCard({required this.detail});
  @override
  Widget build(BuildContext context) {
    final predominantQuality = _getPredominantQuality(
      detail.environmentalDistribution,
    );
    final lastActivityText = _getLastActivityText(detail.lastAnalysisDate);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            predominantQuality.color.withValues(alpha: 0.12),
            predominantQuality.color.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: predominantQuality.color.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: predominantQuality.color.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: predominantQuality.color,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: predominantQuality.color.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  predominantQuality.icon,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${detail.totalAnalyses}',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: predominantQuality.color,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'análisis realizados',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calidad predominante',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        predominantQuality.label,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: predominantQuality.color,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 32, color: AppTheme.borderColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Última actividad',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lastActivityText,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _PredominantQualityInfo _getPredominantQuality(
    EnvironmentalDistribution distribution,
  ) {
    if (distribution.healthy >= distribution.moderate &&
        distribution.healthy >= distribution.critical) {
      return _PredominantQualityInfo(
        label: 'Saludable',
        color: AppTheme.articleHealthy,
        icon: Icons.check_circle_rounded,
      );
    } else if (distribution.moderate >= distribution.critical) {
      return _PredominantQualityInfo(
        label: 'Moderada',
        color: AppTheme.articleModerate,
        icon: Icons.warning_rounded,
      );
    } else if (distribution.critical > 0) {
      return _PredominantQualityInfo(
        label: 'Crítica',
        color: AppTheme.articleCritical,
        icon: Icons.error_rounded,
      );
    }
    return _PredominantQualityInfo(
      label: 'Sin datos',
      color: AppTheme.textGray,
      icon: Icons.help_rounded,
    );
  }

  String _getLastActivityText(DateTime? date) {
    if (date == null) return 'Sin actividad';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Hoy';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return '${diff.inDays} días';
    return '${(diff.inDays / 7).floor()} sem.';
  }
}

class _PredominantQualityInfo {
  final String label;
  final Color color;
  final IconData icon;
  _PredominantQualityInfo({
    required this.label,
    required this.color,
    required this.icon,
  });
}

class _MetricsGrid extends StatelessWidget {
  final DashboardStatsDetail detail;
  const _MetricsGrid({required this.detail});
  @override
  Widget build(BuildContext context) {
    final metrics = <Widget>[];
    if (detail.zoneCount > 0) {
      metrics.add(
        _MetricItem(
          icon: Icons.location_on_rounded,
          label: 'Zonas',
          value: '${detail.zoneCount}',
          subtitle: 'exploradas',
          color: AppTheme.mapaPrimary,
        ),
      );
    }
    if (detail.averageHumidity != null) {
      final humidityText = detail.averageHumidity! % 1 == 0
          ? detail.averageHumidity!.toInt().toString()
          : detail.averageHumidity!.toStringAsFixed(1);
      metrics.add(
        _MetricItem(
          icon: Icons.water_drop_rounded,
          label: 'Humedad',
          value: '$humidityText%',
          subtitle: 'promedio',
          color: AppTheme.infoColor,
        ),
      );
    }
    if (detail.averageConfidence != null) {
      final confidenceText = detail.averageConfidence! % 1 == 0
          ? detail.averageConfidence!.toInt().toString()
          : detail.averageConfidence!.toStringAsFixed(1);
      metrics.add(
        _MetricItem(
          icon: Icons.psychology_rounded,
          label: 'Confianza',
          value: '$confidenceText%',
          subtitle: 'modelo IA',
          color: AppTheme.infoColor,
        ),
      );
    }
    if (metrics.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: metrics.map((metric) {
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 44) / 2,
          child: metric,
        );
      }).toList(),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color color;
  const _MetricItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(color: AppTheme.primaryGreen),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  const _ErrorView({required this.error});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No se pudieron cargar las estadísticas',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityChart extends StatelessWidget {
  final DashboardStatsDetail detail;
  const _ActivityChart({required this.detail});
  @override
  Widget build(BuildContext context) {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.historialPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.show_chart_rounded,
                  size: 20,
                  color: AppTheme.historialPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Actividad de análisis',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Análisis realizados a lo largo del tiempo',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (detail.dailyActivity.isEmpty)
            _buildNoDataMessage(
              'Necesitas más análisis para mostrar una tendencia.',
            )
          else
            _buildChart(),
          const SizedBox(height: 12),
          _buildInterpretation(),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final maxCount = detail.dailyActivity
        .map((e) => e.count)
        .reduce((a, b) => a > b ? a : b);
    return LayoutBuilder(
      builder: (context, constraints) {
        final barCount = detail.dailyActivity.length;
        final chartHeight = (constraints.maxWidth / barCount * 0.6).clamp(
          60.0,
          100.0,
        );
        return SizedBox(
          height: chartHeight + 24,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: detail.dailyActivity.map((stat) {
              final heightFraction = maxCount > 0 ? stat.count / maxCount : 0.0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: FractionallySizedBox(
                          heightFactor: heightFraction.clamp(0.1, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppTheme.historialPrimary,
                                  AppTheme.historialIcon,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${stat.date.day}',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildInterpretation() {
    final total = detail.dailyActivity.fold<int>(
      0,
      (sum, stat) => sum + stat.count,
    );
    String text;
    if (detail.dailyActivity.isEmpty) {
      text = 'Sin datos suficientes.';
    } else if (detail.dailyActivity.length == 1) {
      text = '$total análisis en el último día.';
    } else {
      text =
          '$total análisis en los últimos ${detail.dailyActivity.length} días.';
    }
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppTheme.historialPrimary,
      ),
    );
  }

  Widget _buildNoDataMessage(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          message,
          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textGray),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _EnvironmentalDistributionChart extends StatelessWidget {
  final EnvironmentalDistribution distribution;
  const _EnvironmentalDistributionChart({required this.distribution});
  @override
  Widget build(BuildContext context) {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.articleHealthy.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.pie_chart_outline_rounded,
                  size: 20,
                  color: AppTheme.articleHealthy,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Distribución ambiental',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!distribution.hasData)
            _buildNoDataMessage()
          else
            _buildDistributionContent(),
        ],
      ),
    );
  }

  Widget _buildNoDataMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          'Realiza análisis para ver la distribución ambiental.',
          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textGray),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildDistributionContent() {
    return Column(
      children: [
        _buildDonutChart(),
        const SizedBox(height: 16),
        _buildLegend(),
      ],
    );
  }

  Widget _buildDonutChart() {
    final total = distribution.total.toDouble();
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final donutSize = (availableWidth * 0.3).clamp(80.0, 120.0);
        return Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          children: [
            CustomPaint(
              size: Size(donutSize, donutSize),
              painter: _DonutChartPainter(
                distribution: distribution,
                total: total,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$total',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Flexible(
                  child: Text(
                    'análisis totales',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildLegend() {
    return Column(
      children: [
        _LegendItem(
          color: AppTheme.articleHealthy,
          label: 'Saludable',
          count: distribution.healthy,
        ),
        const SizedBox(height: 8),
        _LegendItem(
          color: AppTheme.articleModerate,
          label: 'Moderada',
          count: distribution.moderate,
        ),
        const SizedBox(height: 8),
        _LegendItem(
          color: AppTheme.articleCritical,
          label: 'Crítica',
          count: distribution.critical,
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final EnvironmentalDistribution distribution;
  final double total;
  _DonutChartPainter({required this.distribution, required this.total});
  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 20.0;
    final segments = <_Segment>[
      _Segment(AppTheme.articleHealthy, distribution.healthy / total),
      _Segment(AppTheme.articleModerate, distribution.moderate / total),
      _Segment(AppTheme.articleCritical, distribution.critical / total),
    ];
    double startAngle = -90 * 3.14159 / 180;
    for (final segment in segments) {
      if (segment.fraction <= 0) continue;
      final sweepAngle = segment.fraction * 2 * 3.14159;
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _Segment {
  final Color color;
  final double fraction;
  _Segment(this.color, this.fraction);
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  const _LegendItem({
    required this.color,
    required this.label,
    required this.count,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const Spacer(),
        Text(
          '$count',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ModernCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 48,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Realiza algunos análisis para comenzar a ver tus estadísticas.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
