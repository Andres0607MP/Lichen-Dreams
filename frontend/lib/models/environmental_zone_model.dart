import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../widgets/app_theme.dart';

class EnvironmentalZoneModel {
  final int id;
  final String nombre;
  final double? latitud;
  final double? longitud;
  final double? radioMetros;
  final String? nivelRiesgo;
  final String? calidadPromedioAire;
  final int totalAnalisis;
  final int saludables;
  final int afectados;
  final int desconocidos;
  final double? porcentajeSaludable;
  final String? descripcion;

  EnvironmentalZoneModel({
    required this.id,
    required this.nombre,
    this.latitud,
    this.longitud,
    this.radioMetros,
    this.nivelRiesgo,
    this.calidadPromedioAire,
    this.totalAnalisis = 0,
    this.saludables = 0,
    this.afectados = 0,
    this.desconocidos = 0,
    this.porcentajeSaludable,
    this.descripcion,
  });

  LatLng? get center {
    if (latitud == null || longitud == null) return null;
    return LatLng(latitud!, longitud!);
  }

  bool get hasValidGeometry {
    return latitud != null &&
        longitud != null &&
        radioMetros != null &&
        radioMetros! > 0;
  }

  Color get statusColor {
    final normalized = (calidadPromedioAire ?? '').toLowerCase().trim();
    if (normalized == 'buena' || normalized == 'good' || normalized == 'saludable') {
      return AppTheme.successColor;
    }
    if (normalized == 'mala' || normalized == 'poor' || normalized == 'deficiente') {
      return AppTheme.errorColor;
    }
    if (normalized == 'moderada' || normalized == 'moderate' || normalized == 'media') {
      return AppTheme.warningColor;
    }
    return AppTheme.mapaPrimary;
  }

  String get riskLabel {
    final normalized = (nivelRiesgo ?? '').toLowerCase().trim();
    if (normalized == 'bajo' || normalized == 'low') return 'Bajo';
    if (normalized == 'medio' || normalized == 'medium' || normalized == 'moderado') return 'Medio';
    if (normalized == 'alto' || normalized == 'high') return 'Alto';
    if (normalized == 'sin_datos' || normalized == 'sin datos') return 'Sin datos';
    return nivelRiesgo ?? 'Sin datos';
  }

  String get qualityLabel {
    final normalized = (calidadPromedioAire ?? '').toLowerCase().trim();
    if (normalized == 'buena' || normalized == 'good' || normalized == 'saludable') return 'Buena';
    if (normalized == 'mala' || normalized == 'poor' || normalized == 'deficiente') return 'Mala';
    if (normalized == 'moderada' || normalized == 'moderate' || normalized == 'media') return 'Moderada';
    return 'Sin datos';
  }

  factory EnvironmentalZoneModel.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      return double.tryParse(value.toString());
    }

    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return EnvironmentalZoneModel(
      id: parseInt(json['id_zona'] ?? json['id']),
      nombre: json['nombre_zona']?.toString() ??
          json['nombre']?.toString() ??
          json['name']?.toString() ??
          'Sin nombre',
      latitud: parseDouble(json['latitud'] ?? json['lat']),
      longitud: parseDouble(json['longitud'] ?? json['lng']),
      radioMetros: parseDouble(json['radio_metros']),
      nivelRiesgo: json['nivel_riesgo']?.toString(),
      calidadPromedioAire: json['calidad_promedio_aire']?.toString() ??
          json['calidad_aire']?.toString(),
      totalAnalisis: parseInt(json['total_analisis']),
      saludables: parseInt(json['saludables'] ?? json['liquidos_saludables'] ?? 0),
      afectados: parseInt(json['afectados'] ?? json['liquidos_afectados'] ?? 0),
      desconocidos: parseInt(json['desconocidos'] ?? json['liquidos_desconocidos'] ?? 0),
      porcentajeSaludable: parseDouble(json['porcentaje_saludable']),
      descripcion: json['descripcion']?.toString(),
    );
  }
}
