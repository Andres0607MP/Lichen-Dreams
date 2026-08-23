import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'environmental_quality.dart';

enum AirQualityLevel { good, moderate, poor }

enum ContaminationLevel { low, medium, high, unknown }

enum ConfidenceLevel { high, medium, low }

enum DateRange { today, week, month, all }

const double defaultCircleRadius = 5.0;

class MapAnalysisPoint {
  static const double environmentalCircleRadius = 100.0;
  static const double defaultMapZoom = 14.0;
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
  final String visibilidad;
  final int? idUsuario;
  final Map<String, dynamic>? usuario;
  final int analysisCount;
  final List<Map<String, dynamic>> analyses;

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
    required this.visibilidad,
    this.idUsuario,
    this.usuario,
    this.analysisCount = 1,
    this.analyses = const [],
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

    final visibilidad = json['visibilidad']?.toString() ??
        json['estado_validacion']?.toString() ??
        'private';

    final idUsuario = json['id_usuario'] is int
        ? json['id_usuario'] as int
        : int.tryParse(json['id_usuario']?.toString() ?? '');

    final usuarioRaw = json['usuario'];
    final Map<String, dynamic>? usuario = usuarioRaw is Map<String, dynamic>
        ? Map<String, dynamic>.from(usuarioRaw)
        : null;

    final analysisCount = json['analysis_count'] is int
        ? json['analysis_count'] as int
        : int.tryParse(json['analysis_count']?.toString() ?? '') ?? 1;

    final analyses = json['analyses'] is List
        ? List<Map<String, dynamic>>.from(
            (json['analyses'] as List).map((item) => Map<String, dynamic>.from(item as Map)),
          )
        : const <Map<String, dynamic>>[];

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
      visibilidad: visibilidad,
      idUsuario: idUsuario,
      usuario: usuario,
      analysisCount: analysisCount,
      analyses: analyses,
    );
  }

  LatLng get latLng => LatLng(lat, lng);

  LatLng get markerLatLng {
    final angle = (id * 137.508) * (math.pi / 180.0);
    final distance = 0.00001;
    final dLat = distance * math.cos(angle);
    final dLng = distance * math.sin(angle);
    return LatLng(lat + dLat, lng + dLng);
  }

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

  EnvironmentalQuality get environmentalQuality {
    final quality = EnvironmentalQuality.fromStrings(
      airQuality: airQuality,
      contamination: contaminationLevel,
    );
    return quality;
  }

  Color get _circleFillColor {
    switch (qualityLevel) {
      case AirQualityLevel.good:
        return const Color(0xFF4CAF50).withValues(alpha: 0.25);
      case AirQualityLevel.moderate:
        return const Color(0xFFFFC107).withValues(alpha: 0.25);
      case AirQualityLevel.poor:
        return const Color(0xFFF44336).withValues(alpha: 0.25);
    }
  }

  Color get _circleStrokeColor {
    switch (qualityLevel) {
      case AirQualityLevel.good:
        return const Color(0xFF4CAF50).withValues(alpha: 0.6);
      case AirQualityLevel.moderate:
        return const Color(0xFFFFC107).withValues(alpha: 0.6);
      case AirQualityLevel.poor:
        return const Color(0xFFF44336).withValues(alpha: 0.6);
    }
  }

  Color get _lightFillColor {
    switch (qualityLevel) {
      case AirQualityLevel.good:
        return const Color(0xFF81C784).withValues(alpha: 0.12);
      case AirQualityLevel.moderate:
        return const Color(0xFFFFD54F).withValues(alpha: 0.12);
      case AirQualityLevel.poor:
        return const Color(0xFFE57373).withValues(alpha: 0.12);
    }
  }

  Color get _lightStrokeColor {
    switch (qualityLevel) {
      case AirQualityLevel.good:
        return const Color(0xFF81C784).withValues(alpha: 0.5);
      case AirQualityLevel.moderate:
        return const Color(0xFFFFD54F).withValues(alpha: 0.5);
      case AirQualityLevel.poor:
        return const Color(0xFFE57373).withValues(alpha: 0.5);
    }
  }

  bool get isShared {
    final value = visibilidad.toLowerCase().trim();
    return value == 'shared' || value == 'publicado' || value == 'public' || value == 'visible';
  }

  ContaminationLevel get contaminationLevelCategory {
    final value = (contaminationLevel ?? '').toLowerCase().trim();
    if (value.contains('bajo') || value.contains('low') || value.contains('leve')) {
      return ContaminationLevel.low;
    }
    if (value.contains('alto') || value.contains('high') || value.contains('severa') || value.contains('severo')) {
      return ContaminationLevel.high;
    }
    if (value.contains('medio') || value.contains('medium') || value.contains('moderado')) {
      return ContaminationLevel.medium;
    }
    return ContaminationLevel.unknown;
  }

  ConfidenceLevel get confidenceLevel {
    if (confidence >= 0.8) return ConfidenceLevel.high;
    if (confidence >= 0.5) return ConfidenceLevel.medium;
    return ConfidenceLevel.low;
  }

  bool isInDateRange(DateRange range) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final pointDate = DateTime(date.year, date.month, date.day);
    switch (range) {
      case DateRange.today:
        return pointDate == today;
      case DateRange.week:
        return today.difference(pointDate).inDays < 7;
      case DateRange.month:
        return today.difference(pointDate).inDays < 30;
      case DateRange.all:
        return true;
    }
  }

  Circle toCircle() {
    return Circle(
      circleId: CircleId('analysis_${id}_circle'),
      center: latLng,
      radius: defaultCircleRadius,
      fillColor: _circleFillColor,
      strokeColor: _circleStrokeColor,
      strokeWidth: 1,
    );
  }

  Circle toEnvironmentalCircle() {
    return Circle(
      circleId: CircleId('analysis_${id}_env_circle'),
      center: latLng,
      radius: environmentalCircleRadius,
      fillColor: _lightFillColor,
      strokeColor: _lightStrokeColor,
      strokeWidth: 2,
    );
  }
}
