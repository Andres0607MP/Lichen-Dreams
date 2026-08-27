from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
from sqlalchemy.orm import Session
from sqlalchemy import text

from config.db import get_db
from models.core import Ubicacion

router = APIRouter()


class LocationCreate(BaseModel):
    latitude: float
    longitude: float
    direccion: Optional[str] = None
    municipio: Optional[str] = None
    departamento: Optional[str] = None
    pais: Optional[str] = None


class LocationResponse(BaseModel):
    id_ubicacion: int
    latitud: float
    longitud: float
    direccion: Optional[str]
    municipio: Optional[str]
    departamento: Optional[str]
    pais: Optional[str]
    fecha_registro: datetime

    class Config:
        from_attributes = True


class LocationFindOrCreateRequest(BaseModel):
    latitude: float
    longitude: float
    radius_meters: float = 15.0
    direccion: Optional[str] = None
    municipio: Optional[str] = None
    departamento: Optional[str] = None
    pais: Optional[str] = "Colombia"


class LocationFindOrCreateResponse(BaseModel):
    id_ubicacion: int
    latitud: float
    longitud: float
    existed: bool
    distance_meters: float

    class Config:
        from_attributes = True


def _haversine_distance(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    import math
    R = 6371000.0
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c


def _clean_direccion(direccion: Optional[str]) -> Optional[str]:
    if direccion is None:
        return None
    cleaned = direccion.strip()
    if cleaned.lower() == 'unnamed road':
        return None
    return cleaned if cleaned else None


@router.post("/save", response_model=LocationResponse, summary="Guardar ubicación")
def save_location(request: LocationCreate, db: Session = Depends(get_db)):
    ub = Ubicacion(
        latitud=request.latitude,
        longitud=request.longitude,
        direccion=_clean_direccion(request.direccion),
        municipio=request.municipio,
        departamento=request.departamento,
        pais=request.pais
    )
    db.add(ub)
    db.commit()
    db.refresh(ub)
    return ub


@router.post("/find-or-create", response_model=LocationFindOrCreateResponse, summary="Buscar ubicación cercana o crear una nueva")
def find_or_create_location(request: LocationFindOrCreateRequest, db: Session = Depends(get_db)):
    ubicaciones = db.query(Ubicacion).all()

    best_match = None
    best_distance = float('inf')

    for ub in ubicaciones:
        dist = _haversine_distance(
            request.latitude,
            request.longitude,
            float(ub.latitud),
            float(ub.longitud),
        )
        if dist <= request.radius_meters and dist < best_distance:
            best_distance = dist
            best_match = ub

    if best_match is not None:
        if not best_match.municipio and request.municipio:
            best_match.municipio = request.municipio
        if not best_match.departamento and request.departamento:
            best_match.departamento = request.departamento
        existing_direccion = (best_match.direccion or '').strip()
        new_direccion = (request.direccion or '').strip()
        if (not existing_direccion or existing_direccion.lower() == 'unnamed road'):
            if new_direccion and new_direccion.lower() != 'unnamed road':
                best_match.direccion = new_direccion
        if not best_match.pais and request.pais:
            best_match.pais = request.pais
        db.commit()
        db.refresh(best_match)
        return LocationFindOrCreateResponse(
            id_ubicacion=best_match.id_ubicacion,
            latitud=float(best_match.latitud),
            longitud=float(best_match.longitud),
            existed=True,
            distance_meters=best_distance,
        )

    ub = Ubicacion(
        latitud=request.latitude,
        longitud=request.longitude,
        direccion=_clean_direccion(request.direccion),
        municipio=request.municipio,
        departamento=request.departamento,
        pais=request.pais,
    )
    db.add(ub)
    db.commit()
    db.refresh(ub)
    return LocationFindOrCreateResponse(
        id_ubicacion=ub.id_ubicacion,
        latitud=float(ub.latitud),
        longitud=float(ub.longitud),
        existed=False,
        distance_meters=0.0,
    )


@router.get("/{location_id}", response_model=LocationResponse, summary="Obtener ubicación por ID")
def get_location(location_id: int, db: Session = Depends(get_db)):
    ub = db.query(Ubicacion).filter(Ubicacion.id_ubicacion == location_id).first()
    if not ub:
        raise HTTPException(status_code=404, detail="Ubicación no encontrada")
    return ub


@router.get("", response_model=List[LocationResponse], summary="Obtener todas las ubicaciones")
def get_all_locations(db: Session = Depends(get_db)):
    items = db.query(Ubicacion).all()
    return items
