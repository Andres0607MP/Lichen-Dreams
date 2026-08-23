import 'package:flutter/material.dart';

enum EnvironmentalQualityLevel {
  excellent,
  good,
  moderate,
  poor,
  critical,
  unknown,
}

class EnvironmentalQuality {
  final EnvironmentalQualityLevel level;
  final String label;
  final String description;
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;
  final IconData icon;

  const EnvironmentalQuality({
    required this.level,
    required this.label,
    required this.description,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
    required this.icon,
  });

  static const Map<EnvironmentalQualityLevel, EnvironmentalQuality> _values = {
    EnvironmentalQualityLevel.excellent: EnvironmentalQuality(
      level: EnvironmentalQualityLevel.excellent,
      label: 'Excelente',
      description: 'Calidad del aire óptima',
      primaryColor: Color(0xFF1B5E20),
      secondaryColor: Color(0xFF4CAF50),
      backgroundColor: Color(0xFFE8F5E9),
      icon: Icons.eco_rounded,
    ),
    EnvironmentalQualityLevel.good: EnvironmentalQuality(
      level: EnvironmentalQualityLevel.good,
      label: 'Saludable',
      description: 'Líquen saludable identificado',
      primaryColor: Color(0xFF4CAF50),
      secondaryColor: Color(0xFF81C784),
      backgroundColor: Color(0xFFE8F5E9),
      icon: Icons.check_circle_rounded,
    ),
    EnvironmentalQualityLevel.moderate: EnvironmentalQuality(
      level: EnvironmentalQualityLevel.moderate,
      label: 'Moderada',
      description: 'Calidad del aire regular',
      primaryColor: Color(0xFF8BC34A),
      secondaryColor: Color(0xFFAED581),
      backgroundColor: Color(0xFFF1F8E9),
      icon: Icons.warning_rounded,
    ),
    EnvironmentalQualityLevel.poor: EnvironmentalQuality(
      level: EnvironmentalQualityLevel.poor,
      label: 'Líquen afectado',
      description: 'Líquen afectado por contaminantes',
      primaryColor: Color(0xFFFF9800),
      secondaryColor: Color(0xFFFFB74D),
      backgroundColor: Color(0xFFFFF3E0),
      icon: Icons.error_rounded,
    ),
    EnvironmentalQualityLevel.critical: EnvironmentalQuality(
      level: EnvironmentalQualityLevel.critical,
      label: 'Crítica',
      description: 'Calidad del aire peligrosa',
      primaryColor: Color(0xFFF44336),
      secondaryColor: Color(0xFFE57373),
      backgroundColor: Color(0xFFFFEBEE),
      icon: Icons.dangerous_rounded,
    ),
    EnvironmentalQualityLevel.unknown: EnvironmentalQuality(
      level: EnvironmentalQualityLevel.unknown,
      label: 'No identificado',
      description: 'No fue posible identificar el organismo',
      primaryColor: Color(0xFF9E9E9E),
      secondaryColor: Color(0xFFBDBDBD),
      backgroundColor: Color(0xFFF5F5F5),
      icon: Icons.help_rounded,
    ),
  };

  static EnvironmentalQuality fromIAResult(String? iaResult) {
    final normalized = (iaResult ?? '').toLowerCase().trim();

    if (normalized.contains('saludable') ||
        normalized.contains('healthy') ||
        normalized.contains('sano') ||
        normalized.contains('buena') ||
        normalized.contains('good')) {
      return _values[EnvironmentalQualityLevel.good]!;
    }
    if (normalized.contains('afectado') ||
        normalized.contains('affected') ||
        normalized.contains('contaminado') ||
        normalized.contains('polluted') ||
        normalized.contains('dañado') ||
        normalized.contains('damaged')) {
      return _values[EnvironmentalQualityLevel.poor]!;
    }
    if (normalized.contains('desconocido') ||
        normalized.contains('unknown') ||
        normalized.contains('no identificado') ||
        normalized.contains('unidentified') ||
        normalized.contains('no es liquen') ||
        normalized.contains('rechazado') ||
        normalized.contains('rejected')) {
      return _values[EnvironmentalQualityLevel.unknown]!;
    }
    return _values[EnvironmentalQualityLevel.unknown]!;
  }

  static EnvironmentalQuality fromAirQuality(String? airQuality) {
    final normalized = (airQuality ?? '').toLowerCase().trim();

    if (normalized.contains('excelente') ||
        normalized.contains('excellent') ||
        normalized.contains('óptima') ||
        normalized.contains('optimal')) {
      return _values[EnvironmentalQualityLevel.excellent]!;
    }
    if (normalized.contains('saludable') ||
        normalized.contains('healthy') ||
        normalized.contains('sano')) {
      return _values[EnvironmentalQualityLevel.good]!;
    }
    if (normalized.contains('buena') ||
        normalized.contains('good') ||
        normalized.contains('bueno')) {
      return _values[EnvironmentalQualityLevel.good]!;
    }
    if (normalized.contains('moderada') ||
        normalized.contains('moderate') ||
        normalized.contains('media') ||
        normalized.contains('regular')) {
      return _values[EnvironmentalQualityLevel.moderate]!;
    }
    if (normalized.contains('afectado') ||
        normalized.contains('affected') ||
        normalized.contains('contaminado') ||
        normalized.contains('polluted') ||
        normalized.contains('dañado') ||
        normalized.contains('damaged')) {
      return _values[EnvironmentalQualityLevel.poor]!;
    }
    if (normalized.contains('deficiente') ||
        normalized.contains('poor') ||
        normalized.contains('mala') ||
        normalized.contains('bad') ||
        normalized.contains('baja')) {
      return _values[EnvironmentalQualityLevel.poor]!;
    }
    if (normalized.contains('crítica') ||
        normalized.contains('critical') ||
        normalized.contains('peligrosa') ||
        normalized.contains('dangerous') ||
        normalized.contains('severa')) {
      return _values[EnvironmentalQualityLevel.critical]!;
    }
    if (normalized.contains('desconocido') ||
        normalized.contains('unknown') ||
        normalized.contains('no identificado') ||
        normalized.contains('unidentified') ||
        normalized.contains('rechazado') ||
        normalized.contains('rejected')) {
      return _values[EnvironmentalQualityLevel.unknown]!;
    }
    return _values[EnvironmentalQualityLevel.unknown]!;
  }

  static EnvironmentalQuality fromContamination(String? contamination) {
    final normalized = (contamination ?? '').toLowerCase().trim();

    if (normalized.contains('nula') ||
        normalized.contains('null') ||
        normalized.contains('ninguna') ||
        normalized.contains('none') ||
        normalized.contains('sin')) {
      return _values[EnvironmentalQualityLevel.excellent]!;
    }
    if (normalized.contains('baja') ||
        normalized.contains('low') ||
        normalized.contains('leve') ||
        normalized.contains('slight') ||
        normalized.contains('mínima')) {
      return _values[EnvironmentalQualityLevel.good]!;
    }
    if (normalized.contains('media') ||
        normalized.contains('medium') ||
        normalized.contains('moderada') ||
        normalized.contains('moderate')) {
      return _values[EnvironmentalQualityLevel.moderate]!;
    }
    if (normalized.contains('alta') ||
        normalized.contains('high') ||
        normalized.contains('elevada') ||
        normalized.contains('elevated')) {
      return _values[EnvironmentalQualityLevel.poor]!;
    }
    if (normalized.contains('severa') ||
        normalized.contains('severe') ||
        normalized.contains('crítica') ||
        normalized.contains('critical') ||
        normalized.contains('extrema')) {
      return _values[EnvironmentalQualityLevel.critical]!;
    }
    return _values[EnvironmentalQualityLevel.unknown]!;
  }

  static EnvironmentalQuality fromStrings({
    String? airQuality,
    String? contamination,
    String? result,
  }) {
    final iaResult = fromIAResult(result);
    if (iaResult.level != EnvironmentalQualityLevel.unknown) {
      return iaResult;
    }

    final airResult = fromAirQuality(airQuality);
    if (airResult.level != EnvironmentalQualityLevel.unknown) {
      return airResult;
    }

    final contaminationResult = fromContamination(contamination);
    if (contaminationResult.level != EnvironmentalQualityLevel.unknown) {
      return contaminationResult;
    }

    return _values[EnvironmentalQualityLevel.unknown]!;
  }

  Color get fillColor => primaryColor.withValues(alpha: 0.25);
  Color get strokeColor => primaryColor.withValues(alpha: 0.6);
  Color get lightFillColor => secondaryColor.withValues(alpha: 0.12);
  Color get lightStrokeColor => secondaryColor.withValues(alpha: 0.5);

  @override
  String toString() => 'EnvironmentalQuality(level: $level, label: $label)';
}
