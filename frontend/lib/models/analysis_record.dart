class AnalysisRecord {
  final int? id;
  final String title;
  final String status;
  final String summary;
  final String? imageUrl;
  final String? imageBase64;
  final DateTime? createdAt;
  final Map<String, dynamic> raw;

  AnalysisRecord({
    this.id,
    required this.title,
    required this.status,
    required this.summary,
    this.imageUrl,
    this.imageBase64,
    this.createdAt,
    required this.raw,
  });

  factory AnalysisRecord.fromJson(Map<String, dynamic> json) {
    final status = json['estado']?.toString() ??
        json['status']?.toString() ??
        json['state']?.toString() ??
        json['resultado']?.toString() ??
        'Desconocido';
    final title = json['titulo']?.toString() ??
        json['nombre']?.toString() ??
        json['resultado']?.toString() ??
        status;
    final summary = json['resumen']?.toString() ??
        json['summary']?.toString() ??
        json['detalle']?.toString() ??
        json['description']?.toString() ??
        json['recommendation']?.toString() ??
        '';
    final imageUrl = json['imagen_url']?.toString() ??
        json['url_imagen']?.toString() ??
        json['image_url']?.toString() ??
        json['foto']?.toString();
    final imageBase64 = json['imagen_base64']?.toString() ?? json['image_base64']?.toString();
    DateTime? createdAt;
    final createdValue = json['fecha_creacion'] ?? json['created_at'] ?? json['fecha'] ?? json['date'];
    if (createdValue is String) {
      createdAt = DateTime.tryParse(createdValue);
    }
    final filteredRaw = Map<String, dynamic>.from(json);
    filteredRaw.remove('imagen_base64');
    filteredRaw.remove('image_base64');
    return AnalysisRecord(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? ''),
      title: title,
      status: status,
      summary: summary,
      imageUrl: imageBase64 != null ? null : imageUrl,
      imageBase64: imageBase64,
      createdAt: createdAt,
      raw: filteredRaw,
    );
  }

  String get displayDate {
    if (createdAt != null) {
      return '${createdAt!.day.toString().padLeft(2, '0')}/${createdAt!.month.toString().padLeft(2, '0')}/${createdAt!.year}';
    }
    return 'Sin fecha';
  }
}
