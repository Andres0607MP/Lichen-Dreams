"""Servicio para gestionar la membresía entre análisis y zonas ambientales.
Esta tabla materializa la relación geográfica entre análisis y zonas para consultas eficientes.
"""
from typing import Optional
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_
import math

from models.core import Analisis, Ubicacion, ZonaAmbiental, AnalisisZonaAmbiental

# Constantes para el cálculo de distancias
EARTH_RADIUS_KM = 6371.0
KM_PER_DEGREE_LAT = 111.0  # aproximadamente


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calcula la distancia en kilómetros entre dos coordenadas usando la fórmula de Haversine."""
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2) ** 2
    )
    a = max(0.0, min(1.0, a))
    return 2 * EARTH_RADIUS_KM * math.asin(math.sqrt(a))


def sync_zone_to_analyses(db: Session, id_zona: int) -> int:
    """
    Sincroniza la membresía de una zona específica con los análisis.
    Elimina las asociaciones existentes y las recalcula basándose en la ubicación geográfica actual.
    
    Args:
        db: Sesión de base de datos
        id_zona: ID de la zona a sincronizar
        
    Returns:
        Número de análisis asociados a la zona después de la sincronización
    """
    # Obtener la zona
    zona = db.query(ZonaAmbiental).filter(ZonaAmbiental.id_zona == id_zona).first()
    if not zona:
        # Zona no existe, eliminar todas sus asociaciones (aunque debería ser cero)
        db.query(AnalisisZonaAmbiental).filter(
            AnalisisZonaAmbiental.id_zona == id_zona
        ).delete(synchronize_session=False)
        return 0
    
    # Verificar si la zona tiene geometría válida
    if zona.latitud is None or zona.longitud is None or zona.radio_metros is None or zona.radio_metros <= 0:
        # Geometría inválida, eliminar todas las asociaciones
        db.query(AnalisisZonaAmbiental).filter(
            AnalisisZonaAmbiental.id_zona == id_zona
        ).delete(synchronize_session=False)
        return 0
    
    # Calcular bounding box para filtrado inicial eficiente
    radius_km = float(zona.radio_metros) / 1000.0  # convertir a km
    center_lat = float(zona.latitud)
    center_lng = float(zona.longitud)
    
    # Latitud: 1 grado ≈ 111 km
    lat_degree_radius = radius_km / KM_PER_DEGREE_LAT
    
    # Longitud: depende de la latitud (los grados de longitud se hacen más pequeños cerca de los polos)
    # Evitar división por cero en el ecuador (cos(0) = 1) y polos (cos(±90°) = 0)
    lat_rad = math.radians(center_lat)
    cos_lat = abs(math.cos(lat_rad))
    # Si estamos muy cerca de los polos, usar un valor mínimo para evitar división por cero
    safe_cos_lat = max(cos_lat, 0.01)
    lng_degree_radius = radius_km / (KM_PER_DEGREE_LAT * safe_cos_lat)
    
    # Calcular límites del bounding box
    min_lat = center_lat - lat_degree_radius
    max_lat = center_lat + lat_degree_radius
    min_lng = center_lng - lng_degree_radius
    max_lng = center_lng + lng_degree_radius
    
    # Obtener candidatos usando bounding box (filtro SQL eficiente)
    candidates = (
        db.query(
            Analisis.id_analisis,
            Ubicacion.latitud,
            Ubicacion.longitud
        )
        .join(Ubicacion, Analisis.id_ubicacion == Ubicacion.id_ubicacion)
        .filter(
            Ubicacion.latitud.isnot(None),
            Ubicacion.longitud.isnot(None),
            Analisis.estado_validacion != 'error',
            Ubicacion.latitud >= min_lat,
            Ubicacion.latitud <= max_lat,
            Ubicacion.longitud >= min_lng,
            Ubicacion.longitud <= max_lng
        )
        .all()
    )
    
    # Eliminar asociaciones existentes para esta zona
    db.query(AnalisisZonaAmbiental).filter(
        AnalisisZonaAmbiental.id_zona == id_zona
    ).delete(synchronize_session=False)
    
    # Procesar candidatos con Haversine preciso
    new_associations = []
    for analisis_id, ub_lat, ub_lng in candidates:
        distance_km = _haversine_km(center_lat, center_lng, float(ub_lat), float(ub_lng))
        if distance_km <= radius_km:
            new_associations.append({
                'id_analisis': analisis_id,
                'id_zona': id_zona
            })
    
    # Insertar nuevas asociaciones
    if new_associations:
        db.bulk_insert_mappings(AnalisisZonaAmbiental, new_associations)
    
    return len(new_associations)


def sync_analysis_to_zones(db: Session, id_analisis: int, id_ubicacion: Optional[int]) -> int:
    """
    Sincroniza las membresías de un análisis específico con todas las zonas que lo contienen.
    Se utiliza cuando se crea un nuevo análisis o se actualiza su ubicación.
    
    Args:
        db: Sesión de base de datos
        id_analisis: ID del análisis
        id_ubicacion: ID de la ubicación del análisis (puede ser None)
        
    Returns:
        Número de zonas asociadas al análisis después de la sincronización
    """
    if not id_ubicacion:
        # Si no hay ubicación, eliminar todas las asociaciones del análisis
        db.query(AnalisisZonaAmbiental).filter(
            AnalisisZonaAmbiental.id_analisis == id_analisis
        ).delete(synchronize_session=False)
        return 0
    
    # Obtener la ubicación
    ubicacion = db.query(Ubicacion).filter(Ubicacion.id_ubicacion == id_ubicacion).first()
    if not ubicacion:
        # Ubicación no existe, eliminar todas las asociaciones
        db.query(AnalisisZonaAmbiental).filter(
            AnalisisZonaAmbiental.id_analisis == id_analisis
        ).delete(synchronize_session=False)
        return 0
    
    # Verificar si la ubicación tiene coordenadas válidas
    if ubicacion.latitud is None or ubicacion.longitud is None:
        # Coordenadas inválidas, eliminar todas las asociaciones
        db.query(AnalisisZonaAmbiental).filter(
            AnalisisZonaAmbiental.id_analisis == id_analisis
        ).delete(synchronize_session=False)
        return 0
    
    # Obtener todas las zonas con geometría válida
    zonas = db.query(ZonaAmbiental).filter(
        ZonaAmbiental.latitud.isnot(None),
        ZonaAmbiental.longitud.isnot(None),
        ZonaAmbiental.radio_metros.isnot(None),
        ZonaAmbiental.radio_metros > 0
    ).all()
    
    # Eliminar asociaciones existentes para este análisis
    db.query(AnalisisZonaAmbiental).filter(
        AnalisisZonaAmbiental.id_analisis == id_analisis
    ).delete(synchronize_session=False)
    
    # Verificar qué zonas contienen este análisis
    new_associations = []
    for zona in zonas:
        radius_km = float(zona.radio_metros) / 1000.0
        distance_km = _haversine_km(
            float(zona.latitud),
            float(zona.longitud),
            float(ubicacion.latitud),
            float(ubicacion.longitud)
        )
        if distance_km <= radius_km:
            new_associations.append({
                'id_analisis': id_analisis,
                'id_zona': zona.id_zona
            })
    
    # Insertar nuevas asociaciones
    if new_associations:
        db.bulk_insert_mappings(AnalisisZonaAmbiental, new_associations)
    
    return len(new_associations)


def sync_all_zones(db: Session) -> int:
    """
    Reconstruye completamente todas las membresías entre zonas y análisis.
    Útil para backfill inicial, reparación o mantenimiento administrativo.
    
    Args:
        db: Sesión de base de datos
        
    Returns:
        Número total de asociaciones creadas
    """
    # Eliminar todas las asociaciones existentes
    db.query(AnalisisZonaAmbiental).delete(synchronize_session=False)
    
    # Obtener todas las zonas con geometría válida
    zonas = db.query(ZonaAmbiental).filter(
        ZonaAmbiental.latitud.isnot(None),
        ZonaAmbiental.longitud.isnot(None),
        ZonaAmbiental.radio_metros.isnot(None),
        ZonaAmbiental.radio_metros > 0
    ).all()
    
    total_associations = 0
    for zona in zonas:
        associations_count = sync_zone_to_analyses(db, zona.id_zona)
        total_associations += associations_count
    
    return total_associations