from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

router = APIRouter()

class LocationResponse(BaseModel):
    id: int
    analysis_id: int
    latitude: float
    longitude: float
    address: str
    timestamp: datetime

class LocationRequest(BaseModel):
    latitude: float
    longitude: float
    address: str

class LocationListResponse(BaseModel):
    id: int
    user_id: int
    latitude: float
    longitude: float
    address: str
    analysis_count: int
    last_updated: datetime

@router.post("/save/{analysis_id}", response_model=LocationResponse, summary="Guardar ubicación")
def save_location(analysis_id: int, request: LocationRequest):
    """
    Endpoint para guardar la ubicación de un análisis
    - RF07: Sistema registrar ubicación
    """
    return {
        "id": 1,
        "analysis_id": analysis_id,
        "latitude": request.latitude,
        "longitude": request.longitude,
        "address": request.address,
        "timestamp": datetime.now()
    }

@router.get("/{location_id}", response_model=LocationResponse, summary="Obtener ubicación por ID")
def get_location(location_id: int):
    """
    Endpoint para obtener información de una ubicación específica
    - RF08: Sistema mostrar mapa
    """
    return {
        "id": location_id,
        "analysis_id": 1,
        "latitude": 4.7110,
        "longitude": -74.0720,
        "address": "Bogotá, Colombia",
        "timestamp": datetime.now()
    }

@router.get("", response_model=List[LocationListResponse], summary="Obtener todas las ubicaciones")
def get_all_locations():
    """
    Endpoint para obtener todas las ubicaciones registradas
    - RF08: Sistema mostrar mapa
    """
    return [
        {
            "id": 1,
            "user_id": 1,
            "latitude": 4.7110,
            "longitude": -74.0720,
            "address": "Bogotá, Colombia",
            "analysis_count": 5,
            "last_updated": datetime.now()
        }
    ]
