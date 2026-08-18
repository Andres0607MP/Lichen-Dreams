import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'map_analysis_point.dart';
import '../widgets/app_theme.dart';

enum EnvironmentalZoneType { healthy, contaminated, transition }

extension EnvironmentalZoneTypeEx on EnvironmentalZoneType {
  String get label {
    switch (this) {
      case EnvironmentalZoneType.healthy:
        return 'Saludable';
      case EnvironmentalZoneType.contaminated:
        return 'Contaminado';
      case EnvironmentalZoneType.transition:
        return 'Transición';
    }
  }

  Color get color {
    switch (this) {
      case EnvironmentalZoneType.healthy:
        return AppTheme.successColor;
      case EnvironmentalZoneType.contaminated:
        return AppTheme.errorColor;
      case EnvironmentalZoneType.transition:
        return AppTheme.warningColor;
    }
  }

  double get hue {
    switch (this) {
      case EnvironmentalZoneType.healthy:
        return BitmapDescriptor.hueGreen;
      case EnvironmentalZoneType.contaminated:
        return BitmapDescriptor.hueRed;
      case EnvironmentalZoneType.transition:
        return BitmapDescriptor.hueYellow;
    }
  }
}

extension MapAnalysisPointEx on MapAnalysisPoint {
  AirQualityLevel get visualQualityLevel {
    final air = airQuality.toLowerCase().trim();
    final contamination = contaminationLevel?.toLowerCase().trim() ?? '';

    if (air == 'buena' || air == 'good' || air == 'saludable') {
      if (contamination == 'alta') {
        return AirQualityLevel.moderate;
      }
      return AirQualityLevel.good;
    }

    if (air == 'mala' || air == 'poor' || air == 'deficiente') {
      if (contamination == 'baja') {
        return AirQualityLevel.moderate;
      }
      return AirQualityLevel.poor;
    }

    if (analyses.isNotEmpty) {
      final hasGood = analyses.any((a) {
        final q =
            (a['air_quality'] ?? a['calidad_del_aire'] ?? '').toString().toLowerCase();
        return q == 'buena' || q == 'good' || q == 'saludable';
      });
      final hasPoor = analyses.any((a) {
        final q =
            (a['air_quality'] ?? a['calidad_del_aire'] ?? '').toString().toLowerCase();
        return q == 'mala' || q == 'poor' || q == 'deficiente';
      });
      if (hasGood && hasPoor) {
        return AirQualityLevel.moderate;
      }
      if (hasGood) return AirQualityLevel.good;
      if (hasPoor) return AirQualityLevel.poor;
    }

    return AirQualityLevel.moderate;
  }

  double get hue => visualQualityLevel.hue;

  Color get statusColor => visualQualityLevel.statusColor;

  String get statusLabel => visualQualityLevel.statusLabel;
}

extension AirQualityLevelEx on AirQualityLevel {
  double get hue {
    switch (this) {
      case AirQualityLevel.good:
        return BitmapDescriptor.hueGreen;
      case AirQualityLevel.moderate:
        return BitmapDescriptor.hueYellow;
      case AirQualityLevel.poor:
        return BitmapDescriptor.hueRed;
    }
  }

  Color get statusColor {
    switch (this) {
      case AirQualityLevel.good:
        return AppTheme.successColor;
      case AirQualityLevel.moderate:
        return AppTheme.warningColor;
      case AirQualityLevel.poor:
        return AppTheme.errorColor;
    }
  }

  String get statusLabel {
    switch (this) {
      case AirQualityLevel.good:
        return 'Saludable';
      case AirQualityLevel.moderate:
        return 'Moderado';
      case AirQualityLevel.poor:
        return 'Contaminado';
    }
  }
}

class EnvironmentalZone {
  final String id;
  final EnvironmentalZoneType type;
  final List<MapAnalysisPoint> points;
  final double radius;
  final LatLng center;

  const EnvironmentalZone({
    required this.id,
    required this.type,
    required this.points,
    required this.radius,
    required this.center,
  });

  String get label {
    switch (type) {
      case EnvironmentalZoneType.healthy:
        return 'Liquen saludable';
      case EnvironmentalZoneType.contaminated:
        return 'Liquen afectado';
      case EnvironmentalZoneType.transition:
        return 'Zona de transición';
    }
  }

  String get interpretation {
    switch (type) {
      case EnvironmentalZoneType.healthy:
        return 'Indicador favorable de las condiciones ambientales locales';
      case EnvironmentalZoneType.contaminated:
        return 'Indicador de posible presión ambiental elevada';
      case EnvironmentalZoneType.transition:
        return 'Zona donde coinciden observaciones saludables y afectadas. '
            'Puede indicar variabilidad ambiental o cambio gradual de condiciones.';
    }
  }

  double get avgConfidence {
    if (points.isEmpty) return 0.0;
    return points.map((p) => p.confidence).reduce((a, b) => a + b) / points.length;
  }

  AirQualityLevel get qualityLevel {
    switch (type) {
      case EnvironmentalZoneType.healthy:
        return AirQualityLevel.good;
      case EnvironmentalZoneType.contaminated:
        return AirQualityLevel.poor;
      case EnvironmentalZoneType.transition:
        return AirQualityLevel.moderate;
    }
  }

  Circle toCircle() {
    final level = qualityLevel;
    return Circle(
      circleId: CircleId(id),
      center: center,
      radius: radius,
      fillColor: level.statusColor.withValues(alpha: 0.32),
      strokeColor: level.statusColor,
      strokeWidth: 3,
    );
  }

  Marker toMarker(VoidCallback? onTap) {
    final level = qualityLevel;
    return Marker(
      markerId: MarkerId('env_zone_marker_$id'),
      position: center,
      icon: BitmapDescriptor.defaultMarkerWithHue(level.hue),
      infoWindow: InfoWindow(
        title: label,
        snippet: '${points.length} análisis · ${type.label}',
      ),
      onTap: onTap,
    );
  }
}

List<EnvironmentalZone> calculateEnvironmentalZones(
    List<MapAnalysisPoint> points) {
  if (points.isEmpty) return [];

  const double individualRadius = 100.0;
  final List<EnvironmentalZone> zones = [];

  for (final point in points) {
    final level = point.visualQualityLevel;
    if (level == AirQualityLevel.moderate) continue;
    final type = level == AirQualityLevel.good
        ? EnvironmentalZoneType.healthy
        : EnvironmentalZoneType.contaminated;
    zones.add(EnvironmentalZone(
      id: 'point_${point.id}_zone',
      type: type,
      points: [point],
      radius: individualRadius,
      center: point.latLng,
    ));
  }

  final healthyPoints = points.where((p) => p.visualQualityLevel == AirQualityLevel.good).toList();
  final contaminatedPoints = points.where((p) => p.visualQualityLevel == AirQualityLevel.poor).toList();

  int transitionIndex = 0;
  for (final healthy in healthyPoints) {
    for (final contaminated in contaminatedPoints) {
      final distance = Geolocator.distanceBetween(
        healthy.lat,
        healthy.lng,
        contaminated.lat,
        contaminated.lng,
      );

      if (distance < individualRadius * 2) {
        final midLat = (healthy.lat + contaminated.lat) / 2;
        final midLng = (healthy.lng + contaminated.lng) / 2;
        final transitionRadius = (distance / 2).clamp(10.0, individualRadius);
        final midLatStr = midLat.toString();
        final midLngStr = midLng.toString();

        zones.add(EnvironmentalZone(
          id: 'transition_${transitionIndex++}_' + midLatStr + '_' + midLngStr,
          type: EnvironmentalZoneType.transition,
          points: [healthy, contaminated],
          radius: transitionRadius,
          center: LatLng(midLat, midLng),
        ));
      }
    }
  }

  return zones;
}
