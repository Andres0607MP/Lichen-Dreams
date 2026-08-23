import 'environmental_quality.dart';

class AnalysisRecord {
  final int? id;
  final int? analysisId;
  final String title;
  final String status;
  final String summary;
  final String? imageUrl;
  final String? imageBase64;
  final DateTime? createdAt;
  final String? ubicacion;
  final double? humedad;
  final String? calidadDelAire;
  final String source;
  final Map<String, dynamic> raw;

  AnalysisRecord({
    this.id,
    this.analysisId,
    required this.title,
    required this.status,
    required this.summary,
    this.imageUrl,
    this.imageBase64,
    this.createdAt,
    this.ubicacion,
    this.humedad,
    this.calidadDelAire,
    this.source = 'camera',
    required this.raw,
  });

  factory AnalysisRecord.fromJson(Map<String, dynamic> json) {
    final status = (json['estado']?.toString() ??
        json['status']?.toString() ??
        json['state']?.toString() ??
        json['resultado']?.toString() ??
        'Desconocido').trim();
    final title = (json['resultado_ia']?.toString() ??
        json['resultado']?.toString() ??
        json['titulo']?.toString() ??
        json['nombre']?.toString() ??
        status).trim();
    final summary = (json['recomendacion']?.toString() ??
        json['resumen']?.toString() ??
        json['summary']?.toString() ??
        json['detalle']?.toString() ??
        json['description']?.toString() ??
        '').trim();
    final imageUrl = json['url_imagen']?.toString() ??
        json['imagen_url']?.toString() ??
        json['image_url']?.toString() ??
        json['foto']?.toString();
    final imageBase64 = json['imagen_base64']?.toString() ?? json['image_base64']?.toString();
    DateTime? createdAt;
    final createdValue = json['fecha_creacion'] ?? json['created_at'] ?? json['fecha'] ?? json['date'];
    if (createdValue is String) {
      createdAt = DateTime.tryParse(createdValue);
    }
    final ubicacion = json['ubicacion']?.toString();
    final humedad = json['humedad'] is num
        ? (json['humedad'] as num).toDouble()
        : double.tryParse(json['humedad']?.toString() ?? '');
    final calidadDelAire = json['calidad_del_aire']?.toString() ??
        json['calidadDelAire']?.toString() ??
        json['calidad_aire']?.toString();
    final source = (json['source'] ?? json['origen'] ?? 'camera').toString();
    final analysisId = json['id_analisis'] is int
        ? json['id_analisis'] as int
        : int.tryParse(json['id_analisis']?.toString() ?? '');
    final filteredRaw = Map<String, dynamic>.from(json);
    filteredRaw.remove('imagen_base64');
    filteredRaw.remove('image_base64');

    return AnalysisRecord(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? ''),
      analysisId: analysisId,
      title: title,
      status: status,
      summary: summary,
      imageUrl: imageBase64 != null ? null : imageUrl,
      imageBase64: imageBase64,
      createdAt: createdAt,
      ubicacion: ubicacion,
      humedad: humedad,
      calidadDelAire: calidadDelAire,
      source: source,
      raw: filteredRaw,
    );
  }

  String get displayDate {
    final createdAt = this.createdAt;
    if (createdAt != null) {
      return '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
    }
    return 'Sin fecha';
  }

  bool get isShared {
    final value = raw['visibilidad'];
    if (value is String) return value.toLowerCase() == 'shared';
    if (value is int) return value == 1;
    return false;
  }

  EnvironmentalQuality get environmentalQuality {
    final iaResult = raw['resultado_ia']?.toString() ?? raw['resultado']?.toString();
    if (iaResult != null && iaResult.isNotEmpty) {
      final quality = EnvironmentalQuality.fromIAResult(iaResult);
      final confidence = raw['confianza'] ?? raw['confidence'] ?? raw['confianza_ia'];
      print('[IA VALIDATION FLOW] resultado: $iaResult, level: ${quality.level.name}, label: ${quality.label}');
      return quality;
    }
    final quality = EnvironmentalQuality.fromStrings(
      airQuality: calidadDelAire ?? raw['calidad_del_aire']?.toString() ?? raw['calidad_aire']?.toString() ?? raw['air_quality']?.toString(),
      result: raw['resultado_ia']?.toString() ?? raw['resultado']?.toString(),
      contamination: raw['nivel_contaminacion']?.toString() ?? raw['contamination_level']?.toString(),
    );
    final confidence = raw['confianza'] ?? raw['confidence'] ?? raw['confianza_ia'];
    print('[IA VALIDATION FLOW] resultado: $iaResult, level: ${quality.level.name}, label: ${quality.label}');
    return quality;
  }
}
