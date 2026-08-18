import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

enum DevMapQuality { healthy, contaminated }

enum DevAirQuality { good, moderate, bad }

enum DevContamination { low, medium, high }

enum DevMapZoneType { healthy, contaminated, transition }

class DeveloperMapPoint {
  final double latitude;
  final double longitude;
  final DevMapQuality quality;
  final DevAirQuality airQuality;
  final DevContamination contamination;
  final double confidence;
  final DateTime createdAt;

  const DeveloperMapPoint({
    required this.latitude,
    required this.longitude,
    required this.quality,
    required this.airQuality,
    required this.contamination,
    required this.confidence,
    required this.createdAt,
  });

  LatLng get latLng => LatLng(latitude, longitude);
}

class DeveloperMapZone {
  final String id;
  final DevMapZoneType zoneType;
  final List<DeveloperMapPoint> points;
  final double radius;
  final DeveloperMapPoint? sourceA;
  final DeveloperMapPoint? sourceB;

  const DeveloperMapZone({
    required this.id,
    required this.zoneType,
    required this.points,
    required this.radius,
    this.sourceA,
    this.sourceB,
  });

  LatLng get center {
    if (points.isEmpty) return const LatLng(0, 0);
    double lat = 0;
    double lng = 0;
    for (final p in points) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / points.length, lng / points.length);
  }

  String get interpretation {
    switch (zoneType) {
      case DevMapZoneType.healthy:
        return 'Indicador favorable de las condiciones ambientales locales';
      case DevMapZoneType.contaminated:
        return 'Indicador de posible presión ambiental elevada';
      case DevMapZoneType.transition:
        return 'Zona donde coinciden observaciones saludables y afectadas. Puede indicar variabilidad ambiental o cambio gradual de condiciones.';
    }
  }

  String get label {
    switch (zoneType) {
      case DevMapZoneType.healthy:
        return 'Liquen saludable';
      case DevMapZoneType.contaminated:
        return 'Liquen afectado';
      case DevMapZoneType.transition:
        return 'Zona de transición';
    }
  }
}

List<DeveloperMapZone> calculateZones(List<DeveloperMapPoint> points) {
  final List<DeveloperMapZone> zones = [];
  const double pointRadius = 100.0;

  for (final point in points) {
    zones.add(DeveloperMapZone(
      id: 'point_${point.createdAt.millisecondsSinceEpoch}_${point.latitude}_${point.longitude}',
      zoneType: point.quality == DevMapQuality.healthy
          ? DevMapZoneType.healthy
          : DevMapZoneType.contaminated,
      points: [point],
      radius: pointRadius,
      sourceA: point,
    ));
  }

  final healthyPoints = points.where((p) => p.quality == DevMapQuality.healthy).toList();
  final contaminatedPoints = points.where((p) => p.quality == DevMapQuality.contaminated).toList();

  int transitionIndex = 0;
  for (final healthy in healthyPoints) {
    for (final contaminated in contaminatedPoints) {
      final distance = Geolocator.distanceBetween(
        healthy.latitude,
        healthy.longitude,
        contaminated.latitude,
        contaminated.longitude,
      );

      if (distance < pointRadius * 2) {
        final midLat = (healthy.latitude + contaminated.latitude) / 2;
        final midLng = (healthy.longitude + contaminated.longitude) / 2;
        final transitionRadius = (distance / 2).clamp(10.0, pointRadius);

        zones.add(DeveloperMapZone(
          id: 'transition_${transitionIndex++}_${midLat}_${midLng}',
          zoneType: DevMapZoneType.transition,
          points: [healthy, contaminated],
          radius: transitionRadius,
          sourceA: healthy,
          sourceB: contaminated,
        ));
      }
    }
  }

  return zones;
}

