from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
from sqlalchemy.orm import Session

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


@router.post("/save", response_model=LocationResponse, summary="Guardar ubicación")
def save_location(request: LocationCreate, db: Session = Depends(get_db)):
    ub = Ubicacion(
        latitud=request.latitude,
        longitud=request.longitude,
        direccion=request.direccion,
        municipio=request.municipio,
        departamento=request.departamento,
        pais=request.pais
    )
    db.add(ub)
    db.commit()
    db.refresh(ub)
    return ub


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
