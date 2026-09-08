import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/ia_diagnostic.dart';
import '../models/ia_event.dart';
import '../state/auth_state.dart';
import '../state/ia_monitoring_state.dart';
import '../widgets/ambient_background.dart';
import '../widgets/app_theme.dart';
import '../widgets/ia_monitor_status.dart';

/// Centro de observabilidad de la IA en tiempo real (solo administradores).
class IaMonitoringScreen extends StatefulWidget {
  const IaMonitoringScreen({super.key});

  @override
  State<IaMonitoringScreen> createState() => _IaMonitoringScreenState();
}

class _IaMonitoringScreenState extends State<IaMonitoringScreen> {
  IaMonitoringState? _monitorState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<IaMonitoringState>();
      _monitorState = state;
      state.refreshData();
      state.startPeriodicRefresh();
      state.connectSse();
    });
  }

  @override
  void dispose() {
    _monitorState?.disconnectSse();
    _monitorState?.stopPeriodicRefresh();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();
    if (!authState.isAdmin) return _AdminGuard();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AmbientBackground(showParticles: true),
            ),
          ),
          Consumer<IaMonitoringState>(
            builder: (context, state, _) => CustomScrollView(
              slivers: [
                _buildAppBar(context, state),
                SliverToBoxAdapter(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxWidth =
                          constraints.maxWidth > 960 ? 1000.0 : constraints.maxWidth;
                      return Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxWidth),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 8),
                                MonitoringHero(state: state),
                                if (state.hasActiveAnalysis) ...[
                                  const SizedBox(height: AppTheme.spaceXL),
                                  _buildActiveAnalysisCard(context, state),
                                ],
                                const SizedBox(height: AppTheme.spaceXL),
                                _MetricsSection(state: state),
                                const SizedBox(height: AppTheme.spaceXL),
                                _CollapsibleSection(
                                  id: 'performance',
                                  icon: Icons.speed_rounded,
                                  title: 'PERFORMANCE',
                                  summary: _performanceSummary(state),
                                  child: _PerformancePanel(state: state),
                                ),
                                const SizedBox(height: AppTheme.spaceLG),
                                _CollapsibleSection(
                                  id: 'model',
                                  icon: Icons.psychology_rounded,
                                  title: 'MODEL ANALYTICS',
                                  summary: _modelSummary(state),
                                  child: _ModelAnalyticsPanel(state: state),
                                ),
                                const SizedBox(height: AppTheme.spaceLG),
                                _CollapsibleSection(
                                  id: 'events',
                                  icon: Icons.timeline_rounded,
                                  title: 'LIVE EVENTS',
                                  summary: '${state.events.length} eventos recientes',
                                  badge: state.events.isEmpty ? null : state.events.length.toString(),
                                  child: _LiveEventsPanel(events: state.events),
                                ),
                                const SizedBox(height: AppTheme.spaceLG),
                                _CollapsibleSection(
                                  id: 'diagnostic',
                                  icon: Icons.health_and_safety_rounded,
                                  title: 'IA DIAGNOSTIC',
                                  summary: _diagnosticSummary(state),
                                  child: _DiagnosticPanel(state: state),
                                ),
                                const SizedBox(height: AppTheme.spaceLG),
                                _CollapsibleSection(
                                  id: 'services',
                                  icon: Icons.dns_rounded,
                                  title: 'SERVICE HEALTH',
                                  summary: 'API · IA · DB · SSE',
                                  child: _ServiceHealthPanel(state: state),
                                ),
                                const SizedBox(height: AppTheme.spaceXXL),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, IaMonitoringState state) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = _resolveStatus(state);
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      pinned: true,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Monitor IA',
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: AppTheme.spaceSM),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: status.color.withValues(alpha: 0.1),
            borderRadius: AppTheme.radiusFullBorder,
            border: Border.all(color: status.color.withValues(alpha: 0.3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LiveDot(status: status, active: state.hasActiveAnalysis),
              const SizedBox(width: 6),
              Text(
                status.label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: status.color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _performanceSummary(IaMonitoringState state) {
    final m = state.metrics;
    if (m == null) return 'Sin datos';
    final lat = m.p95LatencyMs?.toStringAsFixed(0) ?? '—';
    final req = m.requestsPerMinute;
    return '$lat ms p95 · $req/min';
  }

  String _modelSummary(IaMonitoringState state) {
    final m = state.metrics;
    if (m == null) return 'Sin datos';
    final conf = m.averageConfidence == null
        ? '—'
        : '${(m.averageConfidence! * 100).toStringAsFixed(1)}%';
    return 'Confianza $conf · ${m.predictions.total} predicciones';
  }

  String _diagnosticSummary(IaMonitoringState state) {
    final d = state.diagnostics;
    if (d == null) {
      return state.diagnosticsError != null
          ? 'Diagnóstico no disponible'
          : 'Calculando…';
    }
    return '${d.status.toUpperCase()} · ${d.score.toStringAsFixed(0)}/100';
  }

  IaMonitorStatus _resolveStatus(IaMonitoringState state) {
    return IaMonitorStatus.resolve(
      live: state.isLive,
      hasData: state.hasData,
      stale: state.dataStale,
      healthStatus: state.healthDisplayValid ? state.health?.status : null,
      diagnosticStatus:
          state.diagnosticsDisplayValid ? state.diagnostics?.status : null,
    );
  }

  Widget _buildActiveAnalysisCard(BuildContext context, IaMonitoringState state) {
    final colorScheme = Theme.of(context).colorScheme;
    final event = state.activeAnalysis;
    if (event == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.05),
        borderRadius: AppTheme.radiusXXLBorder,
        border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.3), width: 2),
        boxShadow: [AppTheme.shadowMedium],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _SystemHeart(status: IaMonitorLevel.warning, processing: true),
                const SizedBox(width: AppTheme.spaceMD),
                Text(
                  'IA PROCESANDO',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.warningColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceLG),
            Text(
              'Análisis #${event.analysisId ?? 0}',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Procesando imagen con el modelo de IA…',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (event.activeInferences != null)
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.spaceMD),
                child: Text(
                  'Análisis activos: ${event.activeInferences}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
//  HERO
// ===========================================================================

class MonitoringHero extends StatelessWidget {
  const MonitoringHero({super.key, required this.state});

  final IaMonitoringState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = IaMonitorStatus.resolve(
      live: state.isLive,
      hasData: state.hasData,
      stale: state.dataStale,
      healthStatus: state.healthDisplayValid ? state.health?.status : null,
      diagnosticStatus:
          state.diagnosticsDisplayValid ? state.diagnostics?.status : null,
    );
    final score = state.diagnostics != null &&
            state.diagnosticsDisplayValid
        ? state.diagnostics!.score
        : null;
    final health = state.healthDisplayValid ? state.health : null;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surface,
            status.color.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: AppTheme.radiusXXLBorder,
        border: Border.all(color: status.color.withValues(alpha: 0.35), width: 1.6),
        boxShadow: [AppTheme.shadowMedium],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'IA MONITORING',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Inteligencia artificial\n${status.description.toLowerCase()}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          height: 1.25,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                ServerStatusPill(status: status),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _SystemHeart(
                  status: status.level,
                  processing: state.hasActiveAnalysis,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SYSTEM HEALTH',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.1,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        score != null ? '${score.toStringAsFixed(1)}%' : '—',
                        style: GoogleFonts.poppins(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                          color: status.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (health != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _MiniInfo('MODELO', health.modelName ?? '—')),
                  const SizedBox(width: 12),
                  Expanded(child: _MiniInfo('VERSIÓN', health.modelVersion ?? 'v?')),
                ],
              ),
            ],
            const SizedBox(height: 16),
            _UpdatedAgoText(
              lastUpdatedAt: state.lastUpdatedAt,
              stale: state.dataStale,
              offline: !state.hasData,
            ),
          ],
        ),
      ),
    );
  }
}

class ServerStatusPill extends StatelessWidget {
  const ServerStatusPill({super.key, required this.status});

  final IaMonitorStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: AppTheme.radiusFullBorder,
        border: Border.all(color: status.color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LiveDot(status: status, active: false),
          const SizedBox(width: 6),
          Text(
            '● ${status.label}',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: status.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final String label;
  final String value;
  const _MiniInfo(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

/// "Actualizado hace Xs" con detección de datos desactualizados/offline.
class _UpdatedAgoText extends StatefulWidget {
  final DateTime? lastUpdatedAt;
  final bool stale;
  final bool offline;
  const _UpdatedAgoText({
    required this.lastUpdatedAt,
    required this.stale,
    required this.offline,
  });

  @override
  State<_UpdatedAgoText> createState() => _UpdatedAgoTextState();
}

class _UpdatedAgoTextState extends State<_UpdatedAgoText> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final String text;
    Color color;
    IconData icon = Icons.schedule_rounded;

    if (widget.offline) {
      color = colorScheme.error;
      icon = Icons.cloud_off_rounded;
      text = 'OFFLINE · esperando datos del servidor…';
    } else {
      final last = widget.lastUpdatedAt;
      final ago =
          last == null ? '—' : _agoText(DateTime.now().difference(last));
      if (widget.stale) {
        color = AppTheme.warningColor;
        icon = Icons.history_rounded;
        text = 'STALE DATA · última actualización $ago';
      } else {
        color = colorScheme.onSurfaceVariant;
        text = 'Updated $ago';
      }
    }

    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  String _agoText(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    final m = d.inMinutes;
    return m < 60 ? '${m}min ago' : '${d.inHours}h ago';
  }
}

// ===========================================================================
//  CORAZÓN / LIVE DOT
// ===========================================================================

class _SystemHeart extends StatefulWidget {
  final IaMonitorLevel status;
  final bool processing;
  const _SystemHeart({required this.status, this.processing = false});

  @override
  State<_SystemHeart> createState() => _SystemHeartState();
}

class _SystemHeartState extends State<_SystemHeart>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Duration _duration;

  @override
  void initState() {
    super.initState();
    _applyDuration();
  }

  void _applyDuration() {
    switch (widget.status) {
      case IaMonitorLevel.healthy:
        _duration = const Duration(milliseconds: 900);
      case IaMonitorLevel.warning:
      case IaMonitorLevel.degraded:
        _duration = const Duration(milliseconds: 1600);
      case IaMonitorLevel.critical:
        _duration = const Duration(milliseconds: 600);
      case IaMonitorLevel.offline:
        _duration = const Duration(milliseconds: 1200);
    }
    _controller = AnimationController(vsync: this, duration: _duration)
      ..value = 1.0;
    if (widget.status != IaMonitorLevel.offline) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _SystemHeart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status ||
        oldWidget.processing != widget.processing) {
      _controller.dispose();
      _applyDuration();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color heartColor;
    switch (widget.status) {
      case IaMonitorLevel.healthy:
        heartColor = AppTheme.successColor;
      case IaMonitorLevel.warning:
      case IaMonitorLevel.degraded:
        heartColor = AppTheme.warningColor;
      case IaMonitorLevel.critical:
        heartColor = AppTheme.errorColor;
      case IaMonitorLevel.offline:
        heartColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final animate = widget.status != IaMonitorLevel.offline;
        final beat = animate ? _controller.value : 0.85;
        final scale =
            widget.processing ? 1.0 + 0.16 * beat : 1.0 + 0.10 * beat;
        final glow = widget.processing
            ? 22 * _controller.value
            : animate
                ? 14 * _controller.value
                : 0.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: heartColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: heartColor.withValues(alpha: 0.5), width: 1.6),
              boxShadow: [
                BoxShadow(
                  color: heartColor.withValues(alpha: 0.35),
                  blurRadius: glow,
                  spreadRadius: glow > 0 ? 1 : 0,
                ),
              ],
            ),
            child: Icon(Icons.favorite_rounded, size: 28, color: heartColor),
          ),
        );
      },
    );
  }
}

class _LiveDot extends StatefulWidget {
  final IaMonitorStatus status;
  final bool active;
  const _LiveDot({required this.status, this.active = false});

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final speed = widget.active
        ? const Duration(milliseconds: 650)
        : (widget.status.level == IaMonitorLevel.healthy
            ? const Duration(milliseconds: 1100)
            : const Duration(milliseconds: 1600));
    _controller = AnimationController(vsync: this, duration: speed)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offline = widget.status.level == IaMonitorLevel.offline;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final color = offline
            ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
            : widget.status.color;
        final opacity = offline ? 0.4 : 0.55 + 0.45 * _controller.value;
        final grow = offline ? 0.0 : (widget.active ? 2.5 : 1.0) * _controller.value;
        final size = 8.0 + grow;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withValues(alpha: opacity),
            shape: BoxShape.circle,
            boxShadow: offline
                ? null
                : [BoxShadow(color: widget.status.color, blurRadius: 6, spreadRadius: 1)],
          ),
        );
      },
    );
  }
}

// ===========================================================================
//  SECCIONES DESPLEGABLES
// ===========================================================================

class _CollapsibleSection extends StatefulWidget {
  final String id;
  final IconData icon;
  final String title;
  final String summary;
  final String? badge;
  final Widget child;

  const _CollapsibleSection({
    required this.id,
    required this.icon,
    required this.title,
    required this.summary,
    this.badge,
    required this.child,
  });

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: AppTheme.radiusXLBorder,
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [AppTheme.shadowSmall],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: AppTheme.radiusXLBorder,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(widget.icon, size: 18, color: AppTheme.primaryGreen),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        if (!_expanded)
                          Text(
                            widget.summary,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (widget.badge != null)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                        borderRadius: AppTheme.radiusFullBorder,
                      ),
                      child: Text(
                        widget.badge!,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: widget.child,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
//  MÉTRICAS
// ===========================================================================

class _MetricsSection extends StatelessWidget {
  final IaMonitoringState state;
  const _MetricsSection({required this.state});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final m = state.metrics;
    if (m == null && state.metricsError == null) {
      return const _MetricsSkeleton();
    }
    if (m == null) {
      return _InlineMessage(
        icon: Icons.error_outline_rounded,
        text: 'Métricas no disponibles',
        color: colorScheme.error,
      );
    }
    final cards = [
      _StatCard(value: '${m.totalInferences}', label: 'Análisis', icon: Icons.analytics_rounded, color: colorScheme.primary),
      _StatCard(value: '${m.requestsPerMinute}', label: '/minuto', icon: Icons.trending_up_rounded, color: AppTheme.primaryGreen),
      _StatCard(value: '${m.activeInferences}', label: 'Activos', icon: Icons.flash_on_rounded, color: AppTheme.warningColor),
      _StatCard(value: '${m.successfulInferences}', label: 'Exitosos', icon: Icons.check_circle_rounded, color: AppTheme.successColor),
      _StatCard(value: '${m.failedInferences}', label: 'Errores', icon: Icons.error_rounded, color: colorScheme.error),
      _StatCard(value: _fmtMs(m.averageInferenceTimeMs), label: 'Latencia', icon: Icons.timer_rounded, color: colorScheme.secondary),
      _StatCard(value: _fmtMs(m.p95LatencyMs), label: 'P95', icon: Icons.speed_rounded, color: AppTheme.warningColor),
      _StatCard(value: _fmtPct(m.averageConfidence), label: 'Confianza', icon: Icons.psychology_rounded, color: AppTheme.primaryGreen),
      _StatCard(value: _fmtRate(m.throughputPerSecond), label: 'Throughput', icon: Icons.compare_arrows_rounded, color: colorScheme.primary),
      _StatCard(value: _fmtPct(m.errorRate), label: 'Tasa error', icon: Icons.trending_down_rounded, color: colorScheme.error),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 420
            ? 1
            : constraints.maxWidth < 720
                ? 3
                : 4;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppTheme.spaceMD,
            mainAxisSpacing: AppTheme.spaceMD,
            childAspectRatio: columns == 1 ? 2.6 : 1.25,
          ),
          itemCount: cards.length,
          itemBuilder: (context, i) => cards[i],
        );
      },
    );
  }
}

class _MetricsSkeleton extends StatelessWidget {
  const _MetricsSkeleton();
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 420 ? 2 : 4;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppTheme.spaceMD,
            mainAxisSpacing: AppTheme.spaceMD,
            childAspectRatio: 1.25,
          ),
          itemCount: 8,
          itemBuilder: (context, i) => Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: AppTheme.radiusMDBorder,
              border: Border.all(color: colorScheme.outlineVariant, width: 1),
            ),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: _LoadingBar(),
            ),
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _StatCard({required this.value, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppTheme.radiusMDBorder,
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3), width: 1),
        boxShadow: [AppTheme.shadowSmall],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
//  PERFORMANCE (gráficas)
// ===========================================================================

class _PerformancePanel extends StatelessWidget {
  final IaMonitoringState state;
  const _PerformancePanel({required this.state});

  @override
  Widget build(BuildContext context) {
    final m = state.metrics;
    final colorScheme = Theme.of(context).colorScheme;
    if (m == null || m.series.isEmpty) {
      return _InlineMessage(
        icon: Icons.show_chart_rounded,
        text: m == null
            ? 'No hay datos de rendimiento todavía'
            : 'Sin historia reciente de métricas',
        color: colorScheme.onSurfaceVariant,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('ANÁLISIS / MINUTO'),
        const SizedBox(height: 8),
        MonitoringBarChart(
          values: m.series.map((s) => s.requests.toDouble()).toList(),
          labels: m.series.map((s) => _timeLabel(s.timestamp)).toList(),
          color: AppTheme.primaryGreen,
        ),
        const SizedBox(height: 16),
        _SectionLabel('LATENCIA (ms) — promedio y p95'),
        const SizedBox(height: 8),
        MonitoringLineChart(
          seriesA: m.series.map((s) => s.avgLatencyMs).toList(),
          seriesB: m.series.map((s) => s.p95LatencyMs).toList(),
          labels: m.series.map((s) => _timeLabel(s.timestamp)).toList(),
          colorA: colorScheme.secondary,
          colorB: AppTheme.warningColor,
          unit: 'ms',
        ),
        const SizedBox(height: 16),
        _SectionLabel('CONFIANZA PROMEDIO'),
        const SizedBox(height: 8),
        MonitoringLineChart(
          seriesA: m.series.map((s) => s.avgConfidence).toList(),
          labels: m.series.map((s) => _timeLabel(s.timestamp)).toList(),
          colorA: AppTheme.successColor,
          unit: '%',
          asPercent: true,
        ),
      ],
    );
  }
}

// ===========================================================================
//  MODEL ANALYTICS
// ===========================================================================

class _ModelAnalyticsPanel extends StatelessWidget {
  final IaMonitoringState state;
  const _ModelAnalyticsPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    final m = state.metrics;
    final colorScheme = Theme.of(context).colorScheme;
    if (m == null) {
      return _InlineMessage(
        icon: Icons.psychology_rounded,
        text: 'Sin datos de predicciones',
        color: colorScheme.onSurfaceVariant,
      );
    }
    final p = m.predictions;
    final total = p.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('DISTRIBUCIÓN DE RESULTADOS'),
        const SizedBox(height: 10),
        DistributionBar(
          label: 'Saludable',
          value: p.healthy,
          total: total,
          color: AppTheme.successColor,
        ),
        const SizedBox(height: 6),
        DistributionBar(
          label: 'Contaminado/Crítico',
          value: p.critical,
          total: total,
          color: AppTheme.errorColor,
        ),
        const SizedBox(height: 6),
        DistributionBar(
          label: 'Desconocido',
          value: p.unknown,
          total: total,
          color: colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

class DistributionBar extends StatelessWidget {
  const DistributionBar({super.key, required this.label, required this.value, required this.total, required this.color});

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pct = total == 0 ? 0.0 : (value * 100 / total);
    return Row(
      children: [
        SizedBox(
          width: 128,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              FractionallySizedBox(
                widthFactor: total == 0 ? 0 : (pct / 100).clamp(0.0, 1.0),
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 64,
          child: Text(
            value == 0 ? '—' : '$value · ${pct.toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
//  LIVE EVENTS (estilo Dozzle)
// ===========================================================================

class _LiveEventsPanel extends StatelessWidget {
  final List<IaEvent> events;
  const _LiveEventsPanel({required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return _InlineMessage(
        icon: Icons.timeline_rounded,
        text: 'Esperando actividad de la IA…',
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
    }
    return Column(
      children: [
        for (var i = 0; i < events.length; i++) ...[
          if (i == 0)
            _TweenFade(child: _EventRow(event: events[i]))
          else
            _EventRow(event: events[i]),
          if (i != events.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _TweenFade extends StatelessWidget {
  final Widget child;
  const _TweenFade({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      builder: (context, value, childWidget) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * -8),
          child: childWidget,
        ),
      ),
      child: child,
    );
  }
}

class _EventRow extends StatelessWidget {
  final IaEvent event;
  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final palette = _eventSeverity(event.type);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppTheme.radiusMDBorder,
        border: Border.all(
          color: palette.color.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: palette.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.type.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          color: palette.color,
                        ),
                      ),
                    ),
                    Text(
                      _fmtEventTime(event.timestamp),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  event.displayTitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (event.category != null)
                      _eventChip(context, event.category!, AppTheme.primaryGreen),
                    if (event.confidence != null)
                      _eventChip(context, '${(event.confidence! * 100).toStringAsFixed(1)}% conf', AppTheme.successColor),
                    if (event.processingTimeMs != null)
                      _eventChip(context, '${event.processingTimeMs!.toStringAsFixed(0)} ms', palette.color),
                    if (event.analysisId != null)
                      _eventChip(context, '#${event.analysisId}', Theme.of(context).colorScheme.onSurfaceVariant),
                    if (event.errorType != null)
                      _eventChip(context, 'Error: ${event.errorType}', AppTheme.errorColor),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventSeverity {
  final String id;
  final Color color;
  const _EventSeverity(this.id, this.color);
}

_EventSeverity _eventSeverity(String type) {
  switch (type) {
    case 'analysis_started':
      return const _EventSeverity('INFO', AppTheme.warningColor);
    case 'analysis_completed':
      return const _EventSeverity('SUCCESS', AppTheme.successColor);
    case 'analysis_failed':
      return const _EventSeverity('CRITICAL', AppTheme.errorColor);
    case 'model_loaded':
      return const _EventSeverity('INFO', AppTheme.primaryGreen);
    case 'model_reloaded':
      return const _EventSeverity('WARNING', AppTheme.warningColor);
    default:
      return const _EventSeverity('INFO', AppTheme.primaryGreen);
  }
}

Widget _eventChip(BuildContext context, String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w500, color: color),
    ),
  );
}

// ===========================================================================
//  DIAGNÓSTICO
// ===========================================================================

class _DiagnosticPanel extends StatelessWidget {
  final IaMonitoringState state;
  const _DiagnosticPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final d = state.diagnostics;

    // La última carga del diagnóstico falló: no presentar checks antiguos
    // (posiblemente cacheados) como si fueran el estado actual.
    if (!state.diagnosticsDisplayValid || d == null && state.diagnosticsError != null) {
      return _InlineMessage(
        icon: Icons.health_and_safety_rounded,
        text: 'Diagnóstico no disponible · sin conexión con la base de datos',
        color: colorScheme.error,
      );
    }
    if (d == null) {
      return _InlineMessage(
        icon: Icons.health_and_safety_rounded,
        text: 'Calculando diagnóstico…',
        color: colorScheme.onSurfaceVariant,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('SYSTEM DIAGNOSTIC'),
        const SizedBox(height: 8),
        for (final check in d.checks) ...[
          _CheckRow(check: check),
          const SizedBox(height: 4),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'Overall: ${d.status.toUpperCase()}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            Text(
              'Score ${d.score.toStringAsFixed(0)}/100',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryGreen,
              ),
            ),
          ],
        ),
        if (d.recommendedActions.isNotEmpty &&
            d.recommendedActions.any((a) => !a.startsWith('No se requieren'))) ...[
          const SizedBox(height: 10),
          for (final action in d.recommendedActions)
            if (!action.startsWith('No se requieren'))
              Text(
                '» $action',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppTheme.warningColor,
                ),
              ),
        ],
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  final IaDiagnosticCheck check;
  const _CheckRow({required this.check});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _checkVisual(check.status);
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            check.message,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

(IconData, Color) _checkVisual(String status) {
  switch (status) {
    case 'ok':
      return (Icons.check_circle_rounded, AppTheme.successColor);
    case 'warn':
      return (Icons.warning_rounded, AppTheme.warningColor);
    case 'critical':
      return (Icons.cancel_rounded, AppTheme.errorColor);
    default:
      return (Icons.info_rounded, const Color(0xFF9E9E9E));
  }
}

// ===========================================================================
//  SERVICE HEALTH
// ===========================================================================

class _ServiceHealthPanel extends StatelessWidget {
  final IaMonitoringState state;
  const _ServiceHealthPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final health = state.health;
    final dbValid = state.healthDisplayValid;
    final serviceRows = <(String, IconData, Color, String)>[
      (
        'API',
        Icons.cloud_done_rounded,
        state.lastRefreshOk ? AppTheme.successColor : AppTheme.errorColor,
        state.lastRefreshOk ? 'respondiendo' : 'sin conexión',
      ),
      (
        'Modelo IA',
        Icons.psychology_rounded,
        _healthColor(health?.status, colorScheme),
        health?.statusDetail ?? 'sin datos',
      ),
      (
        'Base de datos',
        Icons.storage_rounded,
        !dbValid
            ? AppTheme.errorColor
            : health?.databaseHealthy == true
                ? AppTheme.successColor
                : health?.databaseHealthy == false
                    ? AppTheme.errorColor
                    : colorScheme.onSurfaceVariant,
        !dbValid
            ? 'sin conexión'
            : health?.databaseHealthy == true
                ? 'saludable'
                : health?.databaseHealthy == false
                    ? 'problema'
                    : 'sin datos',
      ),
      (
        'SSE (tiempo real)',
        Icons.sensors_rounded,
        state.sseConnected ? AppTheme.successColor : (state.sseReconnecting ? AppTheme.warningColor : colorScheme.onSurfaceVariant),
        state.sseConnected ? 'conectado' : (state.sseReconnecting ? 'reconectando…' : 'desconectado'),
      ),
    ];
    return Column(
      children: [
        for (final row in serviceRows) ...[
          _ServiceRow(name: row.$1, icon: row.$2, color: row.$3, statusText: row.$4),
          if (row != serviceRows.last) const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _ServiceRow extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final String statusText;
  const _ServiceRow({required this.name, required this.icon, required this.color, required this.statusText});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: AppTheme.radiusMDBorder,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              statusText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 11, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

Color _healthColor(String? status, ColorScheme colorScheme) {
  switch (status) {
    case 'healthy':
      return AppTheme.successColor;
    case 'degraded':
      return AppTheme.warningColor;
    case 'unhealthy':
      return AppTheme.errorColor;
    default:
      return colorScheme.onSurfaceVariant;
  }
}

// ===========================================================================
//  GRÁFICAS
// ===========================================================================

class MonitoringLineChart extends StatelessWidget {
  const MonitoringLineChart({
    super.key,
    required this.seriesA,
    this.seriesB,
    required this.labels,
    required this.colorA,
    this.colorB,
    this.unit = '',
    this.asPercent = false,
  });

  final List<double?> seriesA;
  final List<double?>? seriesB;
  final List<String> labels;
  final Color colorA;
  final Color? colorB;
  final String unit;
  final bool asPercent;

  @override
  Widget build(BuildContext context) {
    return _ChartHost(
      labels: labels,
      buildTooltip: (i) {
        final a = seriesA[i];
        final b = (seriesB == null || seriesB!.length <= i) ? null : seriesB![i];
        final parts = <String>[];
        if (a != null) {
          parts.add('avg ${_fmtValue(a)}');
        }
        if (b != null) parts.add('p95 ${_fmtValue(b)}');
        return parts.join(' · ');
      },
      child: CustomPaint(
        size: const Size(double.infinity, 150),
        painter: _LineChartPainter(
          seriesA: seriesA,
          seriesB: seriesB,
          labels: labels,
          colorA: colorA,
          colorB: colorB,
          asPercent: asPercent,
        ),
      ),
    );
  }

  String _fmtValue(double v) => asPercent ? '${(v * 100).toStringAsFixed(0)}%' : '${v.toStringAsFixed(0)}$unit';
}

class MonitoringBarChart extends StatelessWidget {
  const MonitoringBarChart({
    super.key,
    required this.values,
    required this.labels,
    required this.color,
  });

  final List<double> values;
  final List<String> labels;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _ChartHost(
      labels: labels,
      buildTooltip: (i) => '${labels[i]}: ${values[i].toStringAsFixed(0)}',
      child: CustomPaint(
        size: const Size(double.infinity, 120),
        painter: _BarChartPainter(values: values, color: color),
      ),
    );
  }
}

class _ChartHost extends StatefulWidget {
  final List<String> labels;
  final String Function(int index) buildTooltip;
  final Widget child;
  const _ChartHost({required this.labels, required this.buildTooltip, required this.child});

  @override
  State<_ChartHost> createState() => _ChartHostState();
}

class _ChartHostState extends State<_ChartHost> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, c) {
                return GestureDetector(
                  onTapDown: (details) {
                    if (widget.labels.isEmpty) return;
                    final n = widget.labels.length;
                    final ratio = (details.localPosition.dx / c.maxWidth).clamp(0.0, 0.999);
                    setState(() => _selected = (ratio * n).floor());
                  },
                  child: SizedBox(width: c.maxWidth, child: widget.child),
                );
              },
            ),
            if (_selected != null && _selected! < widget.labels.length) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${widget.labels[_selected!]} · ${widget.buildTooltip(_selected!)}',
                  style: GoogleFonts.poppins(fontSize: 10, color: colorScheme.onSurface),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double?> seriesA;
  final List<double?>? seriesB;
  final List<String> labels;
  final Color colorA;
  final Color? colorB;
  final bool asPercent;

  _LineChartPainter({
    required this.seriesA,
    required this.seriesB,
    required this.labels,
    required this.colorA,
    required this.colorB,
    required this.asPercent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = seriesA.length;
    if (n == 0) {
      _drawEmpty(canvas, size);
      return;
    }
    final flat = <double?>[...seriesA, ...?seriesB];
    final valid = flat.whereType<double>().toList();
    if (valid.isEmpty) {
      _drawEmpty(canvas, size);
      return;
    }
    var minV = valid.reduce(math.min);
    var maxV = valid.reduce(math.max);
    if (minV == maxV) {
      minV -= 1;
      maxV += 1;
    }
    final pad = 6.0;
    final height = size.height - pad * 2;

    // Grid (color neutro, independiente del tema del painter).
    final gridPaint = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 1;

    for (var i = 0; i <= 3; i++) {
      final y = pad + height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    double xAt(int i) => n == 1 ? 0.0 : (size.width * i / (n - 1));
    double yAt(double v) => pad + height * (1 - (v - minV) / (maxV - minV));

    Offset? prev;
    for (var i = 0; i < n; i++) {
      final v = seriesA[i];
      if (v == null) continue;
      final p = Offset(xAt(i), yAt(v));
      if (prev != null) {
        canvas.drawLine(prev, p, Paint()..color = colorA..strokeWidth = 2);
      }
      prev = p;
    }

    // Fill under first series.
    final fill = Path();
    Offset? first;
    for (var i = 0; i < n; i++) {
      final v = seriesA[i];
      if (v == null) continue;
      final p = Offset(xAt(i), yAt(v));
      if (first == null) {
        fill.moveTo(p.dx, p.dy);
        first = p;
      } else {
        fill.lineTo(p.dx, p.dy);
      }
    }
    if (first != null) {
      fill.lineTo(size.width, size.height);
      fill.lineTo(0, size.height);
      fill.close();
      canvas.drawPath(
        fill,
        Paint()..color = colorA.withValues(alpha: 0.12),
      );
    }

    if (seriesB != null) {
      Offset? prevB;
      for (var i = 0; i < n && i < seriesB!.length; i++) {
        final v = seriesB![i];
        if (v == null) continue;
        final p = Offset(xAt(i), yAt(v));
        if (prevB != null) {
          canvas.drawLine(prevB, p, Paint()..color = colorB!..strokeWidth = 1.6);
        }
        prevB = p;
      }
    }

    // Puntos.
    for (var i = 0; i < n; i++) {
      final v = seriesA[i];
      if (v == null) continue;
      canvas.drawCircle(
        Offset(xAt(i), yAt(v)),
        3,
        Paint()..color = colorA,
      );
    }
  }

  void _drawEmpty(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x22000000);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), p);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.seriesA != seriesA || old.seriesB != seriesB;
}

class _BarChartPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  _BarChartPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n == 0) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0x22000000));
      return;
    }
    final maxV = values.reduce(math.max).clamp(1.0, double.infinity);
    final slot = size.width / n;
    final barW = slot * 0.6;
    for (var i = 0; i < n; i++) {
      final h = size.height * (values[i] / maxV);
      final r = Rect.fromLTWH(i * slot + (slot - barW) / 2, size.height - h, barW, h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(3)),
        Paint()..color = color.withValues(alpha: 0.75),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) => old.values != values;
}

// ===========================================================================
//  Helpers de formato
// ===========================================================================

String _timeLabel(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String _fmtEventTime(DateTime? dt) {
  final t = dt ?? DateTime.now();
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  final s = t.second.toString().padLeft(2, '0');
  return '$h:$m:$s';
}

String _fmtMs(double? ms) => ms == null ? '—' : '${ms.toStringAsFixed(0)} ms';
String _fmtPct(double? v) => v == null ? '—' : '${(v * 100).toStringAsFixed(1)}%';
String _fmtRate(double v) => v <= 0 ? '0.0/s' : '${v.toStringAsFixed(1)}/s';

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InlineMessage({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminGuard extends StatelessWidget {
  const _AdminGuard();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Acceso restringido',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
      ),
    );
  }
}