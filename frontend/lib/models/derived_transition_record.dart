import 'analysis_record.dart';
import 'environmental_zone.dart';

/// Representaciones derivadas (solo frontend) de las zonas de transición.
///
/// Una transición NO es un análisis real almacenado en la base de datos: es un
/// overlay espacial derivado de la intersección (< 200 m) entre un análisis
/// saludable y uno crítico (radio 100 m). Este modelo convierte cada
/// `EnvironmentalZoneType.transition` en un `AnalysisRecord` de apoyo para que
/// el historial pueda mostrarlo como elemento amarillo dentro del filtro
/// Moderados/Transición, sin duplicar los `AnalysisRecord` originales ni
/// persistir nada.
///
/// El color amarillo proviene de la representación ya existente del proyecto:
/// `EnvironmentalZoneType.transition.color` (AppTheme.warningColor), la misma
/// que utiliza el mapa para la zona de transición.
AnalysisRecord buildTransitionRecord(
  EnvironmentalZone zone, {
  required int index,
}) {
  final participants = zone.points;
  DateTime? created;
  for (final p in participants) {
    if (created == null || p.date.isAfter(created)) {
      created = p.date;
    }
  }
  final zoneName =
      participants.isNotEmpty ? participants.first.zoneName : null;

  return AnalysisRecord(
    id: index,
    analysisId: null,
    title: 'Transición / Moderado',
    status: EnvironmentalZoneType.transition.label,
    summary:
        'Intersección espacial entre zonas saludable y afectada · '
        '${participants.length} análisis a menos de 200 m',
    ubicacion: zoneName,
    createdAt: created,
    source: 'transition',
    raw: {
      'ubicacion': ?zoneName,
      '_derived_transition': true,
      '_zone_id': zone.id,
      '_participant_ids': participants.map((p) => p.id).toList(),
      // El resultado de IA no debe contener claves que desplieguen el banner
      // de validación de un análisis real; la calidad derivada se resuelve por
      // aire 'moderada' -> EnvironmentalQualityLevel.moderate.
      'resultado_ia': 'transición',
      'calidad_del_aire': 'moderada',
    },
  );
}

/// Convierte todas las zonas de transición en registros derivados (uno por
/// transición). Devuelve una lista vacía si no existe ninguna transición.
List<AnalysisRecord> buildTransitionRecords(List<EnvironmentalZone> zones) {
  final result = <AnalysisRecord>[];
  var index = 0;
  for (final zone in zones) {
    if (zone.type == EnvironmentalZoneType.transition) {
      result.add(buildTransitionRecord(zone, index: index));
      index++;
    }
  }
  return result;
}