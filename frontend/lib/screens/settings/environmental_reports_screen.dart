import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../widgets/lichen_scaffold.dart';
import '../../widgets/app_theme.dart';
import '../../state/reports_state.dart';
import 'environmental_report_screen.dart';

class EnvironmentalReportsScreen extends StatefulWidget {
  const EnvironmentalReportsScreen({super.key});

  @override
  State<EnvironmentalReportsScreen> createState() => _EnvironmentalReportsScreenState();
}

class _EnvironmentalReportsScreenState extends State<EnvironmentalReportsScreen> {
  late final ReportsState _reportsState;

  @override
  void initState() {
    super.initState();
    _reportsState = ReportsState(
      apiService: Provider.of<ApiService>(context, listen: false),
    );
    _reportsState.loadReports();
  }

  void _showSnack(String message, {required bool error}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: error ? AppTheme.errorColor : AppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String content,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        content: Text(
          content,
          style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: confirmColor),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmLabel,
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    return ok == true;
  }

  ColorScheme get colorScheme => Theme.of(context).colorScheme;

  String _defaultReportTitle() {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    return 'Resumen ambiental $day/$month/${now.year}';
  }

  Future<void> _generateNewReport() async {
    if (_reportsState.generating) return;
    final confirmed = await _confirm(
      context,
      title: 'Generar nuevo reporte',
      content:
          'Se generará un nuevo reporte ambiental utilizando tus análisis registrados. ¿Deseas continuar?',
      confirmLabel: 'Generar reporte',
      confirmColor: AppTheme.primaryGreen,
    );
    if (!confirmed || !mounted) return;

    final result = await _reportsState.generateReport(title: _defaultReportTitle());
    if (!mounted) return;
    if (result != null) {
      _showSnack('Reporte generado correctamente', error: false);
      final reportId = result['id_reporte'] as int?;
      if (reportId != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: _reportsState,
              child: EnvironmentalReportScreen(reportId: reportId),
            ),
          ),
        );
        if (mounted) _reportsState.loadReports();
      }
    } else {
      _showSnack(
        _reportsState.error ?? 'No se pudo generar el reporte',
        error: true,
      );
    }
  }

  Future<void> _confirmAndDelete(Map<String, dynamic> report) async {
    final reportId = report['id_reporte'] as int?;
    if (reportId == null || _reportsState.generating) return;

    final confirmed = await _confirm(
      context,
      title: 'Eliminar reporte',
      content:
          'Esta acción eliminará permanentemente este reporte. ¿Estás seguro de que deseas continuar?',
      confirmLabel: 'Eliminar',
      confirmColor: AppTheme.errorColor,
    );
    if (!confirmed || !mounted) return;

    final ok = await _reportsState.deleteReport(reportId);
    if (!mounted) return;
    if (ok) {
      _showSnack('Reporte eliminado correctamente', error: false);
    } else {
      _showSnack(
        _reportsState.error ?? 'No se pudo eliminar el reporte',
        error: true,
      );
    }
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
          'Mis reportes',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            onPressed: _reportsState.generating ? null : _generateNewReport,
            icon: _reportsState.generating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textDark),
                  )
                : const Icon(Icons.add_rounded, color: AppTheme.textDark),
            tooltip: 'Generar reporte',
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _reportsState,
        builder: (context, _) {
          final reportsState = _reportsState;

          if (reportsState.loading && reportsState.reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Cargando tus reportes…',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          if (reportsState.error != null && reportsState.reports.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.errorColor.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text(
                      'Error al cargar reportes',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      reportsState.error ?? 'Error desconocido',
                      style: GoogleFonts.poppins(color: colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: reportsState.loadReports,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                    ),
                  ],
                ),
              ),
            );
          }

          if (reportsState.reports.isEmpty) {
            return _buildEmptyState(colorScheme);
          }

          final recent = reportsState.reports.first;
          final previous = reportsState.reports.length > 1 ? reportsState.reports.sublist(1) : <Map<String, dynamic>>[];

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     _RecentReportCard(
                       report: recent,
                       colorScheme: colorScheme,
                       onTap: () async {
                         final reportId = recent['id_reporte'] as int?;
                         if (reportId == null) return;
                         final result = await Navigator.push(
                           context,
                           MaterialPageRoute(
                             builder: (_) => ChangeNotifierProvider.value(
                               value: reportsState,
                               child: EnvironmentalReportScreen(reportId: reportId),
                             ),
                           ),
                         );
                         if (result == true && context.mounted) {
                           reportsState.loadReports();
                         }
                       },
                       onDelete: () => _confirmAndDelete(recent),
                       reportsState: reportsState,
                     ),
                    const SizedBox(height: 20),
                    if (previous.isNotEmpty) ...[
                      _SectionTitle(title: 'Reportes anteriores', colorScheme: colorScheme),
                      const SizedBox(height: 8),
                      ...List.generate(previous.length, (index) {
                        final report = previous[index];
                        return Padding(
                          padding: EdgeInsets.only(bottom: index < previous.length - 1 ? 12 : 0),
                          child: _PreviousReportCard(
                            report: report,
                            colorScheme: colorScheme,
                            onTap: () async {
                              final reportId = report['id_reporte'] as int?;
                              if (reportId == null) return;
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChangeNotifierProvider.value(
                                    value: reportsState,
                                    child: EnvironmentalReportScreen(reportId: reportId),
                                  ),
                                ),
                              );
                              if (result == true && context.mounted) {
                                reportsState.loadReports();
                              }
                            },
                            onDelete: () => _confirmAndDelete(report),
                          ),
                        );
                      }),
                    ],
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

Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryGreen.withValues(alpha: 0.12),
                      AppTheme.lightGreen.withValues(alpha: 0.06),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.eco_rounded,
                  size: 44,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Aún no tienes reportes',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Genera un reporte ambiental a partir de tus análisis registrados.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 26),
              ElevatedButton.icon(
                onPressed: _reportsState.generating ? null : _generateNewReport,
                icon: _reportsState.generating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_graph_rounded),
                label: Text(
                  _reportsState.generating ? 'Generando…' : 'Generar reporte',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final ColorScheme colorScheme;

  const _SectionTitle({required this.title, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurfaceVariant,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _RecentReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final ColorScheme colorScheme;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final ReportsState reportsState;

  const _RecentReportCard({
    required this.report,
    required this.colorScheme,
    required this.onTap,
    this.onDelete,
    required this.reportsState,
  });

  @override
  Widget build(BuildContext context) {
    final fecha = DateTime.tryParse(report['fecha_generacion']?.toString() ?? '') ?? DateTime.now();
    final stats = report['datos_reporte'] is Map
        ? Map<String, dynamic>.from(report['datos_reporte'] as Map)
        : <String, dynamic>{};
    final reportId = report['id_reporte'] as int?;
    final title = report['titulo']?.toString() ?? 'Reporte ambiental';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadow08,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
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
                        padding: const EdgeInsets.all(12),
                        child: Image.asset(
                          'assets/images/vitacora.png',
                          width: 32,
                          height: 32,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reporte reciente',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryGreen,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen10,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _formatDate(fecha),
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onDelete != null)
                      Tooltip(
                        message: 'Eliminar reporte',
                        child: InkWell(
                          onTap: onDelete,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              size: 16,
                              color: AppTheme.errorColor.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1, thickness: 1),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _ModernStatChip(
                        icon: Icons.analytics_rounded,
                        label: 'Análisis',
                        value: '${stats['total_analisis'] ?? 0}',
                        colorScheme: colorScheme,
                      ),
                    ),
                    const SizedBox(width: 10),
                      Expanded(
                        child: _ModernStatChip(
                          icon: Icons.place_rounded,
                          label: 'Ubicaciones',
                          value: '${stats['ubicaciones_analizadas'] ?? 0}',
                          colorScheme: colorScheme,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ModernStatChip(
                          icon: Icons.circle_rounded,
                          label: 'Zonas',
                          value: '${stats['zonas_ambientales_count'] ?? 0}',
                          colorScheme: colorScheme,
                        ),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ModernStatChip(
                        icon: Icons.air_rounded,
                        label: 'Calidad',
                        value: _translateQuality(stats['calidad_aire_predominante']?.toString() ?? 'desconocida'),
                        colorScheme: colorScheme,
                        accentColor: _qualityColor(stats['calidad_aire_predominante']?.toString() ?? 'desconocida'),
                      ),
                    ),
                  ],
                ),
                if (reportId != null) ...[
                  const SizedBox(height: 18),
                  const Divider(height: 1, thickness: 1),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChangeNotifierProvider.value(
                              value: reportsState,
                              child: EnvironmentalReportScreen(reportId: reportId),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: Text(
                        'Ver reporte completo',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryGreen,
                        backgroundColor: AppTheme.primaryGreen10,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day $month $year · $hour:$minute';
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

  Color _qualityColor(String quality) {
    switch (quality.toLowerCase()) {
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

class _ModernStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme colorScheme;
  final Color? accentColor;

  const _ModernStatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.colorScheme,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accentColor ?? AppTheme.primaryGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: effectiveAccent),
              const SizedBox(width: 6),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviousReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final ColorScheme colorScheme;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _PreviousReportCard({
    required this.report,
    required this.colorScheme,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fecha = DateTime.tryParse(report['fecha_generacion']?.toString() ?? '') ?? DateTime.now();
    final stats = report['datos_reporte'] is Map
        ? Map<String, dynamic>.from(report['datos_reporte'] as Map)
        : <String, dynamic>{};
    final title = report['titulo']?.toString() ?? 'Reporte ambiental';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadow05,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryGreen.withValues(alpha: 0.10),
                        AppTheme.lightGreen.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(
                    'assets/images/vitacora.png',
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _CompactMetric(value: '${stats['total_analisis'] ?? 0}', label: 'análisis'),
                          const SizedBox(width: 10),
                          _CompactMetric(value: '${stats['zonas_ambientales_count'] ?? 0}', label: 'zonas'),
                          const SizedBox(width: 10),
                          Text(
                            _formatDate(fecha),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  Tooltip(
                    message: 'Eliminar reporte',
                    child: InkWell(
                      onTap: onDelete,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: AppTheme.errorColor.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    return '$day/$month/$year';
  }
}

class _CompactMetric extends StatelessWidget {
  final String value;
  final String label;

  const _CompactMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
