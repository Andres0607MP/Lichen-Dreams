"""Catálogo público para usuarios autenticados (solo lectura).

Permite consultar especies disponibles (para seleccionarlas en un análisis) y
zonas ambientales con sus indicadores calculados. La administración (crear,
editar, eliminar) permanece exclusivamente en /admin.
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from auth.auth_service import get_current_user
from config.db import get_db
from models.core import EspecieLiquen, Usuario, ZonaAmbiental
from models.validations import EspecieLiquenResponse, ZonaAmbientalResponse

router = APIRouter()


@router.get("/species", response_model=list[EspecieLiquenResponse], summary="Listar especies de líquenes disponibles")
def get_species_catalog(
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Lista las especies del catálogo para que el usuario las seleccione."""
    return db.query(EspecieLiquen).order_by(EspecieLiquen.nombre_cientifico).all()


@router.get("/zones", response_model=list[ZonaAmbientalResponse], summary="Listar zonas ambientales con sus indicadores")
def get_zones_catalog(
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Lista las zonas ambientales con indicadores calculados (solo lectura)."""
    from services.zones_service import calculate_zone_indicators

    zones = db.query(ZonaAmbiental).order_by(ZonaAmbiental.nombre_zona).all()
    result = []
    for zona in zones:
        indicators = calculate_zone_indicators(db, zona)
        result.append({
            "id_zona": zona.id_zona,
            "nombre_zona": zona.nombre_zona,
            "latitud": float(zona.latitud) if zona.latitud is not None else None,
            "longitud": float(zona.longitud) if zona.longitud is not None else None,
            "radio_metros": zona.radio_metros,
            "nivel_riesgo": indicators["nivel_riesgo"],
            "calidad_promedio_aire": indicators["calidad_aire"],
            "total_analisis": indicators["total_analisis"],
            "saludables": indicators["liquidos_saludables"],
            "afectados": indicators["liquidos_afectados"],
            "desconocidos": indicators["liquidos_desconocidos"],
            "porcentaje_saludable": indicators["porcentaje_saludable"],
            "descripcion": zona.descripcion,
            "fecha_actualizacion": zona.fecha_actualizacion,
        })
    return result