class LiquenpediaArticle {
  final int? id;
  final String titulo;
  final String contenido;
  final String autor;
  final String categoria;
  final String? imagenArticulo;
  final String estadoPublicacion;
  final DateTime? fechaPublicacion;
  final DateTime? fechaActualizacion;

  LiquenpediaArticle({
    this.id,
    required this.titulo,
    required this.contenido,
    required this.autor,
    required this.categoria,
    this.imagenArticulo,
    required this.estadoPublicacion,
    this.fechaPublicacion,
    this.fechaActualizacion,
  });

  factory LiquenpediaArticle.fromJson(Map<String, dynamic> json) {
    return LiquenpediaArticle(
      id: json['id_articulo'] as int?,
      titulo: json['titulo'] as String? ?? '',
      contenido: json['contenido'] as String? ?? '',
      autor: json['autor'] as String? ?? '',
      categoria: json['categoria'] as String? ?? '',
      imagenArticulo: json['imagen_articulo'] as String?,
      estadoPublicacion: json['estado_publicacion'] as String? ?? 'borrador',
      fechaPublicacion: json['fecha_publicacion'] != null
          ? DateTime.tryParse(json['fecha_publicacion'] as String)
          : null,
      fechaActualizacion: json['fecha_actualizacion'] != null
          ? DateTime.tryParse(json['fecha_actualizacion'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_articulo': id,
      'titulo': titulo,
      'contenido': contenido,
      'autor': autor,
      'categoria': categoria,
      'imagen_articulo': imagenArticulo,
      'estado_publicacion': estadoPublicacion,
      'fecha_publicacion': fechaPublicacion?.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
    };
  }

  LiquenpediaArticle copyWith({
    int? id,
    String? titulo,
    String? contenido,
    String? autor,
    String? categoria,
    String? imagenArticulo,
    String? estadoPublicacion,
    DateTime? fechaPublicacion,
    DateTime? fechaActualizacion,
  }) {
    return LiquenpediaArticle(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      contenido: contenido ?? this.contenido,
      autor: autor ?? this.autor,
      categoria: categoria ?? this.categoria,
      imagenArticulo: imagenArticulo ?? this.imagenArticulo,
      estadoPublicacion: estadoPublicacion ?? this.estadoPublicacion,
      fechaPublicacion: fechaPublicacion ?? this.fechaPublicacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
    );
  }
}
