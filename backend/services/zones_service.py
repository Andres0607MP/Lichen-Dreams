"""Cálculo centralizado de indicadores ambientales de zonas.

Fuente de verdad para calidad y riesgo de una zona: se deriva de los análisis
reales (resultados de la IA) cuyas ubicaciones caen dentro del radio geográfico
de la zona. Flutter únicamente presenta estos valores.

La membresía se materializa en la tabla `analisis_zonas_ambientales` (M2M),
poblada por `sync_zone_to_analyses` / `sync_analysis_to_zones` en
`services.zone_membership`. Este módulo consume esa tabla M2M como fuente de
verdad, evitando recálculos de Haversine en cada lectura.
"""
from sqlalchemy.orm import Session

from models.core import Analisis, AnalisisZonaAmbiental, ZonaAmbiental

HEALTHY = 'liquen saludable'
AFFECTED = 'liquen contaminado'
UNKNOWN = 'liquen desconocido'


def _calcular_calidad_riesgo(healthy_count: int, affected_count: int):
    """Convierte la proporción saludable/afectado en calidad y riesgo.

    >= 70% saludables -> buena / bajo
    40% - 69%          -> moderada / medio
    < 40%              -> mala / alto
    Sin datos          -> sin_datos / sin_datos
    """
    total = healthy_count + affected_count
    if total == 0:
        return 'sin_datos', 'sin_datos'
    ratio = healthy_count / total
    if ratio >= 0.70:
        return 'buena', 'bajo'
    if ratio >= 0.40:
        return 'moderada', 'medio'
    return 'mala', 'alto'


def calculate_zone_indicators(db: Session, zona: ZonaAmbiental) -> dict:
    """Calcula los indicadores de una zona a partir de los análisis reales.

    La membresía está materializada en la tabla M2M `analisis_zonas_ambientales`,
    poblada geográficamente por `sync_zone_to_analyses`. Este método consume esa
    tabla en lugar de recalcular Haversine en cada lectura, manteniendo coherencia
    con la membresía y evitando scans completos.
    """
    if not zona.latitud or not zona.longitud or not zona.radio_metros:
        return {
            'id_zona': zona.id_zona,
            'calidad_aire': 'sin_datos',
            'nivel_riesgo': 'sin_datos',
            'total_analisis': 0,
            'liquidos_saludables': 0,
            'liquidos_afectados': 0,
            'liquidos_desconocidos': 0,
            'porcentaje_saludable': None,
        }

    rows = (
        db.query(Analisis.resultado_ia)
        .join(
            AnalisisZonaAmbiental,
            AnalisisZonaAmbiental.id_analisis == Analisis.id_analisis,
        )
        .filter(AnalisisZonaAmbiental.id_zona == zona.id_zona)
        .all()
    )

    healthy = affected = unknown = 0
    for (resultado,) in rows:
        if resultado == HEALTHY:
            healthy += 1
        elif resultado == AFFECTED:
            affected += 1
        elif resultado == UNKNOWN:
            unknown += 1

    calidad_aire, nivel_riesgo = _calcular_calidad_riesgo(healthy, affected)
    total_clasificados = healthy + affected
    porcentaje = round((healthy / total_clasificados) * 100, 1) if total_clasificados else None

    return {
        'id_zona': zona.id_zona,
        'calidad_aire': calidad_aire,
        'nivel_riesgo': nivel_riesgo,
        'total_analisis': healthy + affected + unknown,
        'liquidos_saludables': healthy,
        'liquidos_afectados': affected,
        'liquidos_desconocidos': unknown,
        'porcentaje_saludable': porcentaje,
    }


def refresh_zone_indicators(db: Session, zona: ZonaAmbiental) -> dict:
    """Recalcula los indicadores y los persiste en las columnas calculadas."""
    indicators = calculate_zone_indicators(db, zona)
    zona.calidad_promedio_aire = indicators['calidad_aire']
    zona.nivel_riesgo = indicators['nivel_riesgo']
    return indicators