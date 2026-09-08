import 'package:flutter/foundation.dart';

/// Un chequeo individual del diagnóstico determinístico de la IA.
@immutable
class IaDiagnosticCheck {
  /// Identificador (api, model, database, latency, errors, confidence).
  final String id;
  /// ok | warn | critical | info
  final String status;
  final String message;

  const IaDiagnosticCheck({
    required this.id,
    required this.status,
    required this.message,
  });

  factory IaDiagnosticCheck.fromJson(Map<String, dynamic> json) {
    return IaDiagnosticCheck(
      id: json['id']?.toString() ?? 'unknown',
      status: json['status']?.toString() ?? 'info',
      message: json['message']?.toString() ?? '',
    );
  }

  bool get isOk => status == 'ok';
  bool get isWarning => status == 'warn';
  bool get isCritical => status == 'critical';
}

/// Diagnóstico automático de la IA (reglas determinísticas del backend).
@immutable
class IaDiagnostic {
  /// healthy | degraded | critical | unhealthy
  final String status;
  final double score;
  final List<IaDiagnosticCheck> checks;
  final List<String> recommendedActions;
  final int rulesVersion;
  final DateTime? timestamp;

  const IaDiagnostic({
    required this.status,
    required this.score,
    this.checks = const [],
    this.recommendedActions = const [],
    this.rulesVersion = 1,
    this.timestamp,
  });

  factory IaDiagnostic.fromJson(Map<String, dynamic> json) {
    final checksJson = json['checks'];
    final actions = json['recommended_actions'];

    return IaDiagnostic(
      status: json['status']?.toString() ?? 'unhealthy',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      checks: checksJson is List
          ? checksJson
              .whereType<Map>()
              .map((e) =>
                  IaDiagnosticCheck.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      recommendedActions: actions is List
          ? actions.map((e) => e.toString()).toList()
          : const [],
      rulesVersion: (json['rules_version'] as num?)?.toInt() ?? 1,
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? ''),
    );
  }
}