import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/analysis_record.dart';
import '../models/environmental_quality.dart';
import '../routes/route_names.dart';
import '../screens/result_screen.dart';
import '../services/api_service.dart';
import '../services/navigation_service.dart';
import '../widgets/common_widgets.dart';
import '../widgets/lichen_scaffold.dart';
import '../widgets/app_theme.dart';
import '../state/analysis_state.dart';
import '../state/dashboard_state.dart';
import '../state/history_state.dart';
import '../state/map_state.dart';

class _MetricData {
  final String label;
  final double value;
  final Color color;
  const _MetricData(this.label, this.value, this.color);
}

class _FilterOption {
  final String key;
  final String label;
  final int count;
  const _FilterOption(this.key, this.label, this.count);
}

class _StatsSummary {
  final int total;
  final int saludables;
  final int moderados;
  final int criticos;
  const _StatsSummary({
    required this.total,
    required this.saludables,
    required this.moderados,
    required this.criticos,
  });
}

class _ThumbnailFallback extends StatelessWidget {
  const _ThumbnailFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(Icons.eco_rounded, size: 24, color: AppTheme.primaryGreen),
    );
  }
}

class _AnalysisThumbnailStateful extends StatefulWidget {
  final AnalysisRecord record;
  final ApiService apiService;
  const _AnalysisThumbnailStateful({required this.record, required this.apiService, Key? key}) : super(key: key);

  @override
  State<_AnalysisThumbnailStateful> createState() => _AnalysisThumbnailStatefulState();
}

class _AnalysisThumbnailStatefulState extends State<_AnalysisThumbnailStateful> {
  Uint8List? _bytes;
  bool _loading = true;
  static final Map<int?, Uint8List?> _bytesCache = {};

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final recordId = widget.record.id;

    if (recordId != null && _bytesCache.containsKey(recordId)) {
      _bytes = _bytesCache[recordId];
      if (mounted) setState(() => _loading = false);
      return;
    }

    final imageUrl = widget.record.imageUrl;
    final imageBase64 = widget.record.imageBase64;

    try {
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        final trimmed = imageBase64.trim();
        String? cleanBase64;
        if (trimmed.contains(',')) {
          final parts = trimmed.split(',');
          if (parts.last.isNotEmpty) cleanBase64 = parts.last;
        } else {
          cleanBase64 = trimmed;
        }
        if (cleanBase64 != null && cleanBase64.isNotEmpty) {
          _bytes = base64Decode(cleanBase64);
        }
      } else if (imageUrl != null && imageUrl.isNotEmpty) {
        _bytes = await widget.apiService.downloadPrivateImageBytes(imageUrl);
      }
    } catch (_) {
      _bytes = null;
    }

    if (recordId != null && _bytes != null) {
      _bytesCache[recordId] = _bytes;
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final child = _loading
        ? const _ThumbnailFallback()
        : _bytes != null
            ? Image.memory(_bytes!, fit: BoxFit.cover)
            : const _ThumbnailFallback();

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.6), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: child,
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = 'todos';
  String _searchQuery = '';
  String _sortMode = 'recent';
  final Set<int> _deletingIds = {};
  List<AnalysisRecord>? _cachedProcessedRecords;
  _StatsSummary? _cachedStats;
  int _cachedHistoryLength = -1;
  int _cachedHistoryVersion = -1;
  String _cachedFilter = 'todos';
  String _cachedSearchQuery = '';
  String _cachedSortMode = 'recent';
  int _lastProcessedDataVersion = 0;

  @override
  void initState() {
    super.initState();
    LichenNavigation.instance.sync(3);
    AnalysisState.addAnalysisCompletedListener(_onAnalysisCompleted);
    Future.microtask(() {
      if (mounted) {
        final historyState = context.read<HistoryState>();
        final analysisState = context.read<AnalysisState>();
        final currentDataVersion = analysisState.dataVersion;
        final hasNewData = currentDataVersion != _lastProcessedDataVersion;
        _lastProcessedDataVersion = currentDataVersion;
        if ((hasNewData || !historyState.hasLoaded) && !historyState.loading) {
          if (hasNewData) {
            historyState.invalidate();
          }
          historyState.loadHistory();
        }
      }
    });
  }

  @override
  void dispose() {
    AnalysisState.removeAnalysisCompletedListener(_onAnalysisCompleted);
    super.dispose();
  }

  void _onAnalysisCompleted() {
    if (!mounted) return;
    final historyState = context.read<HistoryState>();
    if (!historyState.loading) {
      historyState.invalidate();
      historyState.loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context, listen: false);

    return LichenScaffold(
      apiService: apiService,
      showBottomNav: true,
      onBottomNavTap: (index) {
        LichenNavigation.instance.navigateToTab(context, index);
      },
      showParticleBackground: false,
      body: Consumer<HistoryState>(
        builder: (context, historyState, _) {
          if (historyState.loading && historyState.history.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.eco_rounded,
                      size: 48,
                      color: AppTheme.primaryGreen,
                    ),
                  ).animate().scale(duration: 900.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 24),
                  Text(
                    'Analizando tu bitácora ambiental',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Esto puede tardar unos segundos...',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textGray,
                    ),
                  ),
                ],
              ),
            );
          }

          if (historyState.error != null && historyState.history.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.eco_rounded,
                      size: 48,
                      color: AppTheme.errorColor,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No pudimos cargar el historial',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(duration: 400.ms, curve: Curves.easeOut).slideY(begin: 0.08, end: 0, duration: 400.ms, curve: Curves.easeOut),
                    const SizedBox(height: 10),
                    Text(
                      historyState.error ?? 'Ocurrió un error inesperado.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textGray,
                      ),
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      onPressed: () => historyState.refresh(),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          final records = historyState.history;
          final needsRecalc = records.length != _cachedHistoryLength ||
              historyState.version != _cachedHistoryVersion ||
              _filter != _cachedFilter ||
              _searchQuery != _cachedSearchQuery ||
              _sortMode != _cachedSortMode;

          List<AnalysisRecord> processed;
          _StatsSummary stats;
          if (needsRecalc || _cachedProcessedRecords == null) {
            processed = _applyFilter(records);
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              processed = processed.where((r) {
                return r.title.toLowerCase().contains(q) ||
                    (r.ubicacion?.toLowerCase().contains(q) ?? false) ||
                    r.summary.toLowerCase().contains(q);
              }).toList();
            }
            processed = _sortRecords(processed);
            stats = _computeStats(records);
            _cachedProcessedRecords = processed;
            _cachedStats = stats;
            _cachedHistoryLength = records.length;
            _cachedHistoryVersion = historyState.version;
            _cachedFilter = _filter;
            _cachedSearchQuery = _searchQuery;
            _cachedSortMode = _sortMode;
          } else {
            processed = _cachedProcessedRecords!;
            stats = _cachedStats!;
          }

          if (records.isEmpty) {
            return _buildEmptyState();
          }

          if (processed.isEmpty) {
            return _buildFilteredEmptyState();
          }

          final last = records.first;

          return RefreshIndicator(
            onRefresh: () => historyState.refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              itemCount: processed.length + 4,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _HistoryHeader(
                    total: stats.total,
                    onChartTap: () => _showEnvironmentalChartSheet(records),
                  );
                }
                if (index == 1) {
                  return _buildFilterBar(records, stats: stats);
                }
                if (index == 2) {
                  return _CompactStatsCard(
                    stats: stats,
                    last: last,
                    onChartTap: () => _showEnvironmentalChartSheet(records),
                  );
                }
                if (index == 3) {
                  return _SearchAndSortBar(
                    query: _searchQuery,
                    sortMode: _sortMode,
                    onSearchChanged: (v) => setState(() => _searchQuery = v),
                    onSortChanged: (v) => setState(() => _sortMode = v),
                  );
                }
                final record = processed[index - 4];
                final statusColor = _getStatusColor(record);
                final confidence = _getConfidence(record.raw);
                final ubicacion = _getUbicacion(record);
                final humedad = record.humedad;
                final calidadAire = record.calidadDelAire;

                final card = _AnalysisCompactCard(
                  record: record,
                  statusColor: statusColor,
                  confidence: confidence,
                  ubicacion: ubicacion,
                  humedad: humedad,
                  calidadAire: calidadAire,
                  isDeleting: _deletingIds.contains(record.analysisId),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ResultScreen(analysis: record),
                    ),
                  ),
                  onDelete: () => _deleteRecord(record.analysisId),
                  onChartTap: () => _showEnvironmentalChartSheet([record], singleRecord: record),
                );

                return card;
              },
            ),
          );
        },
      ),
    );
  }

  Widget _HistoryHeader({required int total, required VoidCallback onChartTap}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Historial ambiental',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$total análisis registrados',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textGray,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filled(
            onPressed: onChartTap,
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.12),
              foregroundColor: AppTheme.primaryGreen,
              padding: const EdgeInsets.all(10),
            ),
            icon: const Icon(Icons.analytics_rounded, size: 20),
            tooltip: 'Ver perfil ambiental',
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, curve: Curves.easeOut).slideY(begin: -0.03, end: 0, duration: 400.ms, curve: Curves.easeOut);
  }

  Widget _CompactStatsCard({
    required _StatsSummary stats,
    required AnalysisRecord last,
    required VoidCallback onChartTap,
  }) {
    final statusColor = _getStatusColor(last);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryGreen.withValues(alpha: 0.12),
            AppTheme.lightGreen.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _MiniStat(label: 'Saludables', value: stats.saludables, color: AppTheme.successColor),
              const SizedBox(width: 10),
              _MiniStat(label: 'Moderados', value: stats.moderados, color: AppTheme.warningColor),
              const SizedBox(width: 10),
              _MiniStat(label: 'Críticos', value: stats.criticos, color: AppTheme.errorColor),
              const SizedBox(width: 10),
              _MiniStat(label: 'Total', value: stats.total, color: AppTheme.primaryGreen),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: AppTheme.textGray),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Último análisis: ${last.displayDate}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textGray,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _getStatusLabel(last),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: onChartTap,
                icon: Icon(Icons.bar_chart_rounded, size: 16),
                label: Text(
                  'Perfil',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, curve: Curves.easeOut).slideY(begin: -0.04, end: 0, duration: 500.ms, curve: Curves.easeOut);
  }

  Widget _MiniStat({required String label, required int value, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.18), width: 1),
        ),
                                 child: Column(
                                   mainAxisSize: MainAxisSize.min,
                                   children: [
            Text(
              '$value',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.textGray,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _SearchAndSortBar({
    required String query,
    required String sortMode,
    required ValueChanged<String> onSearchChanged,
    required ValueChanged<String> onSortChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Buscar por título, ubicación o resumen...',
              hintStyle: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textGray,
              ),
              prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppTheme.textGray),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      onPressed: () => onSearchChanged(''),
                      icon: Icon(Icons.clear_rounded, size: 18, color: AppTheme.textGray),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.surfaceColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.6)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.6)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
              ),
            ),
            onChanged: onSearchChanged,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.sort_rounded, size: 18, color: AppTheme.textGray),
              const SizedBox(width: 8),
              Text(
                'Ordenar:',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textGray,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.6)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: sortMode,
                      isDense: true,
                      icon: Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppTheme.textGray),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'recent', child: Text('Más recientes')),
                        DropdownMenuItem(value: 'oldest', child: Text('Más antiguos')),
                        DropdownMenuItem(value: 'confidence', child: Text('Mayor confianza IA')),
                        DropdownMenuItem(value: 'status', child: Text('Estado ambiental')),
                      ],
                      onChanged: (v) {
                        if (v != null) onSortChanged(v);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms, curve: Curves.easeOut);
  }

  Widget _AnalysisThumbnail({required AnalysisRecord record, required ApiService apiService}) {
    return _AnalysisThumbnailStateful(key: ValueKey(record.id), record: record, apiService: apiService);
  }

  Widget _AnalysisCompactCard({
    required AnalysisRecord record,
    required Color statusColor,
    double? confidence,
    String? ubicacion,
    double? humedad,
    String? calidadAire,
    bool isDeleting = false,
    required VoidCallback onTap,
    required VoidCallback onDelete,
    VoidCallback? onChartTap,
  }) {
    final summary = record.summary.isNotEmpty ? record.summary : record.status;
    final especieCientifica = record.raw['especie_nombre_cientifico']?.toString();
    final especieComun = record.raw['especie_nombre_comun']?.toString();

    return AnimatedOpacity(
      opacity: isDeleting ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeIn,
      child: AnimatedScale(
        scale: isDeleting ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeIn,
        child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        highlightColor: AppTheme.primaryGreen.withValues(alpha: 0.08),
        splashColor: AppTheme.primaryGreen.withValues(alpha: 0.12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.surfaceColor,
                AppTheme.surfaceColor.withValues(alpha: 0.94),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.8), width: 1.1),
            boxShadow: [
              BoxShadow(
                color: AppTheme.textGray.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AnalysisThumbnail(record: record, apiService: Provider.of<ApiService>(context, listen: false)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              record.title,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(record: record, color: statusColor, compact: true),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Text(
                            record.displayDate,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textGray,
                            ),
                          ),
                          if (ubicacion != null && ubicacion.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            Icon(Icons.place_rounded, size: 12, color: AppTheme.textGray),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                ubicacion,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textGray,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        summary,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textGray,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (confidence != null)
                            _InfoChip(
                              icon: Icons.psychology_rounded,
                              label: '${confidence.toStringAsFixed(0)}%',
                              color: AppTheme.primaryGreen,
                              compact: true,
                            ),
                          if (humedad != null)
                            _InfoChip(
                              icon: Icons.water_drop_rounded,
                              label: '${humedad.toStringAsFixed(1)}%',
                              color: AppTheme.lightGreen,
                              compact: true,
                            ),
                          if (calidadAire != null && calidadAire.isNotEmpty)
                            _InfoChip(
                              icon: Icons.air_rounded,
                              label: calidadAire,
                              color: AppTheme.textGray,
                              compact: true,
                            ),
                          if (especieCientifica != null && especieCientifica.isNotEmpty)
                            _InfoChip(
                              icon: Icons.biotech_rounded,
                              label:
                                  '${especieComun ?? especieCientifica} · seleccionada por ti',
                              color: const Color(0xFF5D4037),
                              compact: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                 const SizedBox(width: 10),
                  IconButton(
                    onPressed: onChartTap,
                    icon: Icon(Icons.show_chart_rounded, size: 18, color: AppTheme.primaryGreen),
                    tooltip: 'Ver perfil ambiental',
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    ),
                  ),
                  if (record.isShared)
                    IconButton(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.mapExplorer,
                        );
                      },
                      icon: Icon(Icons.map_rounded, size: 18, color: AppTheme.primaryGreen),
                      tooltip: 'Ver en mapa',
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      ),
                    ),
                  _DeleteButton(
                    onPressed: isDeleting ? null : onDelete,
                  ),
              ],
            ),
          ),
        ),
      ),
    )));
  }

  Future<void> _showEnvironmentalChartSheet(List<AnalysisRecord> records, {AnalysisRecord? singleRecord}) async {
    final radarValues = _calculateRadarValues(records, singleRecord: singleRecord);
    final chartMetrics = _buildMetricData(radarValues);
    final cardMetrics = chartMetrics.take(3).toList();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.72,
          ),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.eco_rounded, color: AppTheme.primaryGreen, size: 26),
                        const SizedBox(width: 12),
                        Text(
                          'Perfil ambiental',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close_rounded, color: AppTheme.textGray),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final size = math.min(constraints.maxWidth, 260.0);
                        return SizedBox(
                          width: double.infinity,
                          height: size,
                          child: CustomPaint(
                              painter: _RadarChartPainter(
                                values: radarValues,
                                labels: const [
                                  'Salud',
                                  'Aire',
                                  'IA',
                                  'Baja cont.',
                                  'Cond.',
                                ],
                                colors: chartMetrics.map((m) => m.color).toList(),
                                gridColor: AppTheme.textGray.withValues(alpha: 0.55),
                                textColor: AppTheme.textDark,
                              ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                     Row(
                       children: cardMetrics
                           .map(
                             (m) => Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: m.color.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: m.color.withValues(alpha: 0.18), width: 1),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.analytics_rounded, size: 14, color: m.color),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            m.label,
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.textDark,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 6,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: LinearProgressIndicator(
                                          value: m.value,
                                          backgroundColor: AppTheme.borderColor.withValues(alpha: 0.5),
                                          valueColor: AlwaysStoppedAnimation<Color>(m.color),
                                          minHeight: 6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getMetricStrokeColor(double value) {
    if (value >= 0.7) return AppTheme.successColor;
    if (value >= 0.4) return const Color(0xFFFFC107);
    return AppTheme.errorColor;
  }

  List<_MetricData> _buildMetricData(List<double> radarValues) {
    final labels = const ['Salud', 'Aire', 'IA', 'Baja cont.', 'Cond.'];
    return List.generate(labels.length, (index) {
      final value = radarValues[index];
      return _MetricData(
        labels[index],
        value,
        _getMetricStrokeColor(value),
      );
    });
  }

  List<double> _calculateRadarValues(List<AnalysisRecord> records, {AnalysisRecord? singleRecord}) {
    if (singleRecord != null) {
      return _calculateSingleRecordValues(singleRecord);
    }

    if (records.isEmpty) {
      return const [0.5, 0.5, 0.5, 0.5, 0.5];
    }

    double saludLichen = 0.0;
    double calidadAire = 0.0;
    double confianzaIA = 0.0;
    double bajaContaminacion = 0.0;
    double condiciones = 0.0;

    for (final record in records) {
      final summary = record.summary.toLowerCase();

      if (_isStatusHealthy(record)) {
        saludLichen += 0.9;
        calidadAire += 0.85;
        bajaContaminacion += 0.85;
      } else if (_isStatusModerate(record)) {
        saludLichen += 0.6;
        calidadAire += 0.6;
        bajaContaminacion += 0.55;
      } else if (_isStatusCritical(record)) {
        saludLichen += 0.25;
        calidadAire += 0.3;
        bajaContaminacion += 0.25;
      } else {
        saludLichen += 0.5;
        calidadAire += 0.5;
        bajaContaminacion += 0.5;
      }

      final confidenceRaw = record.raw['confianza'] ?? record.raw['confidence'] ?? record.raw['confianza_ia'];
      if (confidenceRaw != null) {
        final confidence = double.tryParse(confidenceRaw.toString());
        if (confidence != null) {
          confianzaIA += (confidence / 100).clamp(0.0, 1.0);
        } else {
          confianzaIA += saludLichen / records.length;
        }
      } else {
        confianzaIA += saludLichen / records.length;
      }

      if (summary.contains('temperatura') || summary.contains('humedad') || summary.contains('viento') || summary.contains('clima')) {
        condiciones += 0.8;
      } else if (summary.contains('urbano') || summary.contains('ciudad')) {
        condiciones += 0.5;
      } else {
        condiciones += saludLichen / records.length;
      }
    }

    return [
      (saludLichen / records.length).clamp(0.0, 1.0),
      (calidadAire / records.length).clamp(0.0, 1.0),
      (confianzaIA / records.length).clamp(0.0, 1.0),
      (bajaContaminacion / records.length).clamp(0.0, 1.0),
      (condiciones / records.length).clamp(0.0, 1.0),
    ];
  }

  List<double> _calculateSingleRecordValues(AnalysisRecord record) {
    final summary = record.summary.toLowerCase();

    double saludLichen;
    double calidadAire;
    double bajaContaminacion;
    double condiciones;

    if (_isStatusHealthy(record)) {
      saludLichen = 0.9;
      calidadAire = 0.85;
      bajaContaminacion = 0.85;
    } else if (_isStatusModerate(record)) {
      saludLichen = 0.6;
      calidadAire = 0.6;
      bajaContaminacion = 0.55;
    } else if (_isStatusCritical(record)) {
      saludLichen = 0.25;
      calidadAire = 0.3;
      bajaContaminacion = 0.25;
    } else {
      saludLichen = 0.5;
      calidadAire = 0.5;
      bajaContaminacion = 0.5;
    }

    if (summary.contains('temperatura') || summary.contains('humedad') || summary.contains('viento') || summary.contains('clima')) {
      condiciones = 0.8;
    } else if (summary.contains('urbano') || summary.contains('ciudad')) {
      condiciones = 0.5;
    } else {
      condiciones = saludLichen;
    }

    final confidenceRaw = record.raw['confianza'] ?? record.raw['confidence'] ?? record.raw['confianza_ia'];
    double confianzaIA = 0.5;
    if (confidenceRaw != null) {
      final confidence = double.tryParse(confidenceRaw.toString());
      if (confidence != null) {
        confianzaIA = (confidence / 100).clamp(0.0, 1.0);
      }
    }

    return [
      saludLichen.clamp(0.0, 1.0),
      calidadAire.clamp(0.0, 1.0),
      confianzaIA.clamp(0.0, 1.0),
      bajaContaminacion.clamp(0.0, 1.0),
      condiciones.clamp(0.0, 1.0),
    ];
  }

  EnvironmentalQuality _getQuality(AnalysisRecord record) {
    return record.environmentalQuality;
  }

  bool _isStatusHealthy(AnalysisRecord record) {
    final q = _getQuality(record);
    return q.level == EnvironmentalQualityLevel.excellent || q.level == EnvironmentalQualityLevel.good;
  }

  bool _isStatusModerate(AnalysisRecord record) {
    return _getQuality(record).level == EnvironmentalQualityLevel.moderate;
  }

  bool _isStatusCritical(AnalysisRecord record) {
    final q = _getQuality(record);
    return q.level == EnvironmentalQualityLevel.poor || q.level == EnvironmentalQualityLevel.critical;
  }

  Color _getStatusColor(AnalysisRecord record) {
    return _getQuality(record).primaryColor;
  }

  String _getStatusLabel(AnalysisRecord record) {
    return _getQuality(record).label;
  }

  List<AnalysisRecord> _applyFilter(List<AnalysisRecord> records) {
    if (_filter == 'todos') return records;
    return records.where((r) {
      if (_filter == 'saludables') {
        return _isStatusHealthy(r);
      }
      if (_filter == 'moderados') {
        return _isStatusModerate(r);
      }
      if (_filter == 'criticos') {
        return _isStatusCritical(r);
      }
      return true;
    }).toList();
  }

  _StatsSummary _computeStats(List<AnalysisRecord> records) {
    int saludables = 0;
    int moderados = 0;
    int criticos = 0;
    for (final r in records) {
      final q = r.environmentalQuality;
      print('[ANALYSIS FLOW] HistoryScreen: id=${r.id}, quality=${q.label}, level=${q.level.name}');
      if (_isStatusHealthy(r)) {
        saludables++;
      } else if (_isStatusModerate(r)) {
        moderados++;
      } else if (_isStatusCritical(r)) {
        criticos++;
      }
    }
    return _StatsSummary(
      total: records.length,
      saludables: saludables,
      moderados: moderados,
      criticos: criticos,
    );
  }

  List<AnalysisRecord> _sortRecords(List<AnalysisRecord> records) {
    final sorted = List<AnalysisRecord>.from(records);
    switch (_sortMode) {
      case 'oldest':
        sorted.sort((a, b) => (a.createdAt ?? DateTime(1900)).compareTo(b.createdAt ?? DateTime(1900)));
        break;
      case 'confidence':
        sorted.sort((a, b) {
          final ca = _getConfidence(a.raw) ?? 0;
          final cb = _getConfidence(b.raw) ?? 0;
          return cb.compareTo(ca);
        });
        break;
      case 'status':
         sorted.sort((a, b) => _statusSortValue(a).compareTo(_statusSortValue(b)));
        break;
      case 'recent':
      default:
        sorted.sort((a, b) => (b.createdAt ?? DateTime(1900)).compareTo(a.createdAt ?? DateTime(1900)));
        break;
    }
    return sorted;
  }

  int _statusSortValue(AnalysisRecord record) {
    final label = _getStatusLabel(record);
    if (label == 'Saludable') return 0;
    if (label == 'Moderado') return 1;
    return 2;
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.eco_rounded,
              size: 56,
              color: AppTheme.primaryGreen,
            ),
          ).animate().scale(duration: 800.ms, curve: Curves.elasticOut).then().scale(duration: 800.ms, curve: Curves.elasticOut),
          const SizedBox(height: 24),
          Text(
            'Tu bitácora está vacía',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Aún no hay análisis guardados.\nRealiza uno para empezar a ver tu historial aquí.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textGray,
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.analisis),
            child: const Text('Realizar análisis'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.filter_list_off_rounded,
            size: 56,
            color: AppTheme.textGray,
          ),
          const SizedBox(height: 24),
          Text(
            'No hay análisis con este filtro',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 400.ms, curve: Curves.easeOut).slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOut),
          const SizedBox(height: 10),
          Text(
            'Prueba cambiando el filtro actual para ver más registros.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textGray,
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            onPressed: () {
              if (_filter != 'todos') {
                setState(() => _filter = 'todos');
              }
              if (_searchQuery.isNotEmpty) {
                setState(() => _searchQuery = '');
              }
            },
            child: const Text('Ver todos los análisis'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(List<AnalysisRecord> records, {_StatsSummary? stats}) {
    final s = stats ?? _computeStats(records);
    final items = <_FilterOption>[
      _FilterOption('todos', 'Todos', s.total),
      _FilterOption('saludables', 'Saludables', s.saludables),
      _FilterOption('moderados', 'Moderados', s.moderados),
      _FilterOption('criticos', 'Críticos', s.criticos),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.7)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: items.map((item) {
            final isSelected = _filter == item.key;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text('${item.label} (${item.count})'),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _filter = item.key);
                  }
                },
                backgroundColor: AppTheme.surfaceColor,
                selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.22),
                checkmarkColor: AppTheme.primaryGreen,
                labelStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppTheme.primaryGreen : AppTheme.textDark,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  double? _getConfidence(Map<String, dynamic> raw) {
    final value = raw['confianza'] ?? raw['confidence'] ?? raw['confianza_ia'];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String? _getUbicacion(AnalysisRecord record) {
    return record.ubicacion?.toString().trim().isNotEmpty == true
        ? record.ubicacion!.trim()
        : null;
  }

  IconData _statusIcon(String status) {
    return _statusIconFromQuality(status);
  }

  IconData _statusIconFromQuality(String status) {
    final normalized = status.toLowerCase().trim();
    final quality = EnvironmentalQuality.fromStrings(result: status);
    if (quality.level != EnvironmentalQualityLevel.unknown) {
      return quality.icon;
    }
    if (normalized.contains('completado') ||
        normalized.contains('finalizado') ||
        normalized.contains('success')) {
      return Icons.eco_rounded;
    }
    if (normalized.contains('procesando') ||
        normalized.contains('pendiente') ||
        normalized.contains('processing')) {
      return Icons.show_chart_rounded;
    }
    if (normalized.contains('error') ||
        normalized.contains('fallido') ||
        normalized.contains('failed')) {
      return Icons.warning_rounded;
    }
    return Icons.account_tree_rounded;
  }

  Widget _StatusIconButton({required Color color, required String status, bool compact = false}) {
    final size = compact ? 36.0 : 42.0;
    final iconSize = compact ? 20.0 : 22.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.4),
      ),
      child: Icon(
        _statusIcon(status),
        size: iconSize,
        color: color,
      ),
    );
  }

  Widget _DeleteButton({VoidCallback? onPressed}) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Material(
        color: AppTheme.errorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(17),
          highlightColor: AppTheme.errorColor.withValues(alpha: 0.2),
          splashColor: AppTheme.errorColor.withValues(alpha: 0.12),
          child: const Icon(
            Icons.delete_rounded,
            color: AppTheme.errorColor,
            size: 17,
          ),
        ),
      ),
    );
  }

  Widget _StatusBadge({required AnalysisRecord record, required Color color, bool compact = false}) {
    final vertical = compact ? 3.0 : 4.0;
    final horizontal = compact ? 8.0 : 10.0;
    final fontSize = compact ? 10.0 : 11.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.1),
      ),
      child: Text(
        _getStatusLabel(record),
        style: GoogleFonts.poppins(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _InfoChip({required IconData icon, required String label, required Color color, bool compact = false}) {
    final vertical = compact ? 4.0 : 6.0;
    final horizontal = compact ? 8.0 : 10.0;
    final fontSize = compact ? 10.0 : 11.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRecord(int? id) async {
    if (id == null || id <= 0) return;
    if (_deletingIds.contains(id)) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar análisis'),
          content: const Text('¿Deseas eliminar este análisis del historial?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    setState(() => _deletingIds.add(id));

    try {
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;

      await context.read<HistoryState>().deleteRecord(id);

      if (mounted) {
        // Sincronizar el resto de estados que muestran análisis: mapa y
        // estadísticas del dashboard, para que reflejen la eliminación de
        // inmediato (sin datos cacheados desactualizados).
        context.read<MapState>().loadPoints();
        final dashboardState = context.read<DashboardState>();
        dashboardState.invalidate();
        unawaited(dashboardState.loadStats(force: true));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Análisis eliminado correctamente')),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _deletingIds.remove(id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar el análisis')),
        );
      }
    }
  }
}

class _RadarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final List<Color> colors;
  final Color gridColor;
  final Color textColor;

  _RadarChartPainter({
    required this.values,
    required this.labels,
    required this.colors,
    required this.gridColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2 - 36;
    final sides = labels.length;
    final angleStep = (2 * math.pi) / sides;
    final startAngle = -math.pi / 2;

    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    for (final record in [0.2, 0.4, 0.6, 0.8, 1.0]) {
      final path = Path();
      for (int i = 0; i < sides; i++) {
        final angle = startAngle + i * angleStep;
        final x = center.dx + math.cos(angle) * maxRadius * record;
        final y = center.dy + math.sin(angle) * maxRadius * record;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    final axisPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    for (int i = 0; i < sides; i++) {
      final angle = startAngle + i * angleStep;
      final x = center.dx + math.cos(angle) * maxRadius;
      final y = center.dy + math.sin(angle) * maxRadius;
      canvas.drawLine(center, Offset(x, y), axisPaint);
    }

    final dataPaint = Paint()
      ..shader = LinearGradient(
        colors: [colors.first.withValues(alpha: 0.55), colors.last.withValues(alpha: 0.25)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..style = PaintingStyle.fill;

    final dataPath = Path();
    for (int i = 0; i < sides; i++) {
      final angle = startAngle + i * angleStep;
      final value = values[i].clamp(0.0, 1.0);
      final x = center.dx + math.cos(angle) * maxRadius * value;
      final y = center.dy + math.sin(angle) * maxRadius * value;
      if (i == 0) {
        dataPath.moveTo(x, y);
      } else {
        dataPath.lineTo(x, y);
      }
    }
    dataPath.close();
    canvas.drawPath(dataPath, dataPaint);

    final borderPaint = Paint()
      ..color = colors.first
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2;

    canvas.drawPath(dataPath, borderPaint);

    for (int i = 0; i < sides; i++) {
      final angle = startAngle + i * angleStep;
      final value = values[i].clamp(0.0, 1.0);
      final x = center.dx + math.cos(angle) * maxRadius * value;
      final y = center.dy + math.sin(angle) * maxRadius * value;
      final indicatorColor = colors[i];

      canvas.drawCircle(Offset(x, y), 7, Paint()..color = indicatorColor);
      canvas.drawCircle(Offset(x, y), 7, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.5);

      final labelX = center.dx + math.cos(angle) * (maxRadius + 30);
      final labelY = center.dy + math.sin(angle) * (maxRadius + 30);

      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout();
      final offset = Offset(labelX - textPainter.width / 2, labelY - textPainter.height / 2);
      textPainter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.labels != labels ||
        oldDelegate.colors != colors;
  }
}
