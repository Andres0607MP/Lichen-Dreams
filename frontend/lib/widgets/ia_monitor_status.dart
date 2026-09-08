import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Niveles de estado del Monitor IA (single source of truth de severidad).
enum IaMonitorLevel {
  healthy,
  warning,
  degraded,
  critical,
  offline,
}

/// Estado resuelto del monitor con label, color, icono, descripción y
/// severidad. Centraliza la lógica de estados para que los widgets no la
/// dispersen.
class IaMonitorStatus {
  final IaMonitorLevel level;
  final String label;
  final Color color;
  final IconData icon;
  final String description;
  final int severity;

  const IaMonitorStatus({
    required this.level,
    required this.label,
    required this.color,
    required this.icon,
    required this.description,
    required this.severity,
  });

  static const _offline = IaMonitorStatus(
    level: IaMonitorLevel.offline,
    label: 'OFFLINE',
    color: Color(0xFF9E9E9E),
    icon: Icons.cloud_off_rounded,
    description: 'Datos de monitoreo no disponibles',
    severity: 5,
  );

  /// Resuelve el estado global del monitor a partir de datos REALES.
  ///
  /// - `live`: hay una actualización de datos dentro de los últimos 20 s.
  /// - `hasData`: al menos una carga de health/metrics tuvo éxito alguna vez.
  /// - `stale`: la última actualización es antigua (> 45 s).
  /// - `healthStatus`/`diagnosticStatus`: estados reportados por el backend.
  static IaMonitorStatus resolve({
    required bool live,
    required bool hasData,
    required bool stale,
    String? healthStatus,
    String? diagnosticStatus,
  }) {
    if (!hasData) return _offline;
    if (stale) {
      return const IaMonitorStatus(
        level: IaMonitorLevel.degraded,
        label: 'DATOS DESACTUALIZADOS',
        color: AppTheme.warningColor,
        icon: Icons.history_rounded,
        description: 'Última actualización hace más de 45 s',
        severity: 2,
      );
    }
    if (healthStatus == 'unhealthy' ||
        diagnosticStatus == 'unhealthy' ||
        diagnosticStatus == 'critical') {
      return const IaMonitorStatus(
        level: IaMonitorLevel.critical,
        label: 'CRÍTICO',
        color: AppTheme.errorColor,
        icon: Icons.error_rounded,
        description: 'La IA presenta un estado crítico',
        severity: 4,
      );
    }
    if (healthStatus == 'degraded' || diagnosticStatus == 'degraded') {
      return const IaMonitorStatus(
        level: IaMonitorLevel.degraded,
        label: 'DEGRADADO',
        color: AppTheme.warningColor,
        icon: Icons.warning_rounded,
        description: 'Servicio activo con observaciones',
        severity: 2,
      );
    }
    if (!live) {
      return const IaMonitorStatus(
        level: IaMonitorLevel.warning,
        label: 'CONEXIÓN DEGRADADA',
        color: AppTheme.warningColor,
        icon: Icons.wifi_off_rounded,
        description: 'Actualizando datos del monitoreo',
        severity: 2,
      );
    }
    return const IaMonitorStatus(
      level: IaMonitorLevel.healthy,
      label: 'OPERATIVA',
      color: AppTheme.successColor,
      icon: Icons.verified_rounded,
      description: 'Inteligencia artificial operativa',
      severity: 0,
    );
  }
}