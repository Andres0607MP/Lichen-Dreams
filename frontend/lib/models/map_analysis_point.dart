import 'package:google_maps_flutter/google_maps_flutter.dart';

enum AirQualityLevel { good, moderate, poor }

class MapAnalysisPoint {
  final int id;
  final double lat;
  final double lng;
  final String zoneName;
  final String airQuality;
  final String? contaminationLevel;
  final String species;
  final double confidence;
  final DateTime date;
  final String status;

  const MapAnalysisPoint({
    required this.id,
    required this.lat,
    required this.lng,
    required this.zoneName,
    required this.airQuality,
    this.contaminationLevel,
    required this.species,
    required this.confidence,
    required this.date,
    required this.status,
  });

  factory MapAnalysisPoint.fromJson(Map<String, dynamic> json) {
    final id = json['id'] is int
        ? json['id'] as int
        : int.tryParse(json['id']?.toString() ?? '') ?? 0;

    final lat = json['lat'] is double
        ? json['lat'] as double
        : (json['lat'] is int
            ? (json['lat'] as int).toDouble()
            : double.tryParse(json['lat']?.toString() ?? '') ?? 0.0);

    final lng = json['lng'] is double
        ? json['lng'] as double
        : (json['lng'] is int
            ? (json['lng'] as int).toDouble()
            : double.tryParse(json['lng']?.toString() ?? '') ?? 0.0);

    final zoneName = json['zone_name']?.toString() ?? '';

    final airQuality = json['air_quality']?.toString() ?? '';

    final contaminationLevel = json['contamination_level']?.toString();

    final species = json['species']?.toString() ?? '';

    final confidence = json['confidence'] is double
        ? json['confidence'] as double
        : (json['confidence'] is int
            ? (json['confidence'] as int).toDouble()
            : double.tryParse(json['confidence']?.toString() ?? '') ?? 0.0);

    DateTime date;
    final dateValue = json['date'] ?? json['fecha'] ?? json['fecha_creacion'];
    if (dateValue is String) {
      date = DateTime.tryParse(dateValue) ?? DateTime.now();
    } else if (dateValue is DateTime) {
      date = dateValue;
    } else {
      date = DateTime.now();
    }

    final status = json['status']?.toString() ??
        json['estado']?.toString() ??
        json['estado_validacion']?.toString() ??
        '';

    return MapAnalysisPoint(
      id: id,
      lat: lat,
      lng: lng,
      zoneName: zoneName,
      airQuality: airQuality,
      contaminationLevel: contaminationLevel,
      species: species,
      confidence: confidence,
      date: date,
      status: status,
    );
  }

  LatLng get latLng => LatLng(lat, lng);

  AirQualityLevel get qualityLevel {
    final normalized = airQuality.toLowerCase().trim();
    if (normalized == 'buena' ||
        normalized == 'good' ||
        normalized == 'saludable') {
      return AirQualityLevel.good;
    }
    if (normalized == 'moderada' ||
        normalized == 'moderate' ||
        normalized == 'media') {
      return AirQualityLevel.moderate;
    }
    if (normalized == 'deficiente' ||
        normalized == 'poor' ||
        normalized == 'mala') {
      return AirQualityLevel.poor;
    }
    return AirQualityLevel.moderate;
  }
}
