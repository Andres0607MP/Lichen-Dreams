import 'environmental_zone.dart';
import 'map_analysis_point.dart';

/// Resultado del filtro de calidad aplicado a la representación del mapa.
class QualityFilterResult {
  final List<MapAnalysisPoint> points;
  final List<EnvironmentalZone> zones;

  const QualityFilterResult({required this.points, required this.zones});
}

/// Aplica el filtro de calidad (Saludable / Moderado / Contaminado) sobre lo
/// que se muestra en el mapa.
///
/// - `null` (ningún filtro): muestra todos los puntos y todas las zonas.
/// - `good` (Saludable): solo puntos saludables y zonas `healthy`; las
///   transiciones NO se muestran (un filtro exclusivamente saludable no
///   produce transiciones).
/// - `poor` (Contaminado): solo puntos contaminados/críticos y zonas
///   `contaminated`; las transiciones no se muestran.
/// - `moderate` (Moderado/Transición): muestra únicamente las zonas de
///   transición derivadas (sin marcadores individuales). La transición es
///   derivada (frontend-only), nunca un análisis persistido.
///
/// IMPORTANTE: `zones` debe calcularse sobre el conjunto COMPLETO de puntos
/// visibles ANTES de filtrar, para que las intersecciones saludable↔crítica se
/// identifiquen correctamente y no desaparezcan por el orden del filtrado.
QualityFilterResult applyQualityFilter(
  List<MapAnalysisPoint> points,
  List<EnvironmentalZone> zones,
  AirQualityLevel? filter,
) {
  if (filter == null) {
    return QualityFilterResult(points: points, zones: zones);
  }

  if (filter == AirQualityLevel.moderate) {
    return QualityFilterResult(
      points: const [],
      zones: zones
          .where((z) => z.type == EnvironmentalZoneType.transition)
          .toList(),
    );
  }

  final zoneType = filter == AirQualityLevel.good
      ? EnvironmentalZoneType.healthy
      : EnvironmentalZoneType.contaminated;

  return QualityFilterResult(
    points: points.where((p) => p.visualQualityLevel == filter).toList(),
    zones: zones.where((z) => z.type == zoneType).toList(),
  );
}