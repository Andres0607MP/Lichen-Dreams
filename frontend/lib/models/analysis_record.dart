class AnalysisRecord {
  final int? id;
  final String title;
  final String status;
  final String summary;
  final String? imageUrl;
  final DateTime? createdAt;
  final Map<String, dynamic> raw;

  AnalysisRecord({
    this.id,
    required this.title,
    required this.status,
    required this.summary,
    this.imageUrl,
    this.createdAt,
    required this.raw,
  });

  factory AnalysisRecord.fromJson(Map<String, dynamic> json) {
    final status = json['estado']?.toString() ??
        json['status']?.toString() ??
        json['resultado']?.toString() ??
        json['state']?.toString() ??
        'Desconocido';
    final title = json['titulo']?.toString() ??
        json['nombre']?.toString() ??
        status;
    final summary = json['resumen']?.toString() ??
        json['summary']?.toString() ??
        json['detalle']?.toString() ??
        json['description']?.toString() ??
        '';
    final imageUrl = json['imagen_url']?.toString() ??
        json['image_url']?.toString() ??
        json['foto']?.toString();
    DateTime? createdAt;
    final createdValue = json['fecha_creacion'] ?? json['created_at'] ?? json['fecha'] ?? json['date'];
    if (createdValue is String) {
      createdAt = DateTime.tryParse(createdValue);
    }
    return AnalysisRecord(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? ''),
      title: title,
      status: status,
      summary: summary,
      imageUrl: imageUrl,
      createdAt: createdAt,
      raw: json,
    );
  }

  String get displayDate {
    if (createdAt != null) {
      return '${createdAt!.day.toString().padLeft(2, '0')}/${createdAt!.month.toString().padLeft(2, '0')}/${createdAt!.year}';
    }
    return 'Sin fecha';
  }
}
