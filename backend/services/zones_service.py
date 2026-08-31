"""Cálculo centralizado de indicadores ambientales de zonas.

Fuente de verdad para calidad y riesgo de una zona: se deriva de los análisis
reales (resultados de la IA) cuyas ubicaciones caen dentro del radio geográfico
de la zona. Flutter únicamente presenta estos valores.
"""
import math

from sqlalchemy.orm import Session

from models.core import Analisis, Ubicacion, ZonaAmbiental

# Valores reales de resultado_ia usados por la IA del proyecto.
HEALTHY = 'liquen saludable'
AFFECTED = 'liquen contaminado'
UNKNOWN = 'liquen desconocido'


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Distancia en kilómetros entre dos coordenadas (Haversine)."""
    r = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2) ** 2
    )
    return 2 * r * math.asin(math.sqrt(a))


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

    La membresía es geográfica (derivada): ningún análisis pertenece a la zona
    de forma almacenada; se agrupan bajo demanda por distancia al centro.
    Devuelve también los totales serializados para usar como datos de reporte.
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

    radius_km = float(zona.radio_metros) / 1000.0
    center_lat = float(zona.latitud)
    center_lng = float(zona.longitud)

    analyses = (
        db.query(Analisis, Ubicacion)
        .join(Ubicacion, Analisis.id_ubicacion == Ubicacion.id_ubicacion)
        .filter(
            Ubicacion.latitud.isnot(None),
            Ubicacion.longitud.isnot(None),
            Analisis.estado_validacion != 'error',
        )
        .all()
    )

    healthy = affected = unknown = 0
    for analysis, ubicacion in analyses:
        dist_km = _haversine_km(
            center_lat,
            center_lng,
            float(ubicacion.latitud),
            float(ubicacion.longitud),
        )
        if dist_km > radius_km:
            continue
        if analysis.resultado_ia == HEALTHY:
            healthy += 1
        elif analysis.resultado_ia == AFFECTED:
            affected += 1
        elif analysis.resultado_ia == UNKNOWN:
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