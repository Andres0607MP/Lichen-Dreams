from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

router = APIRouter()

class HistoryResponse(BaseModel):
    id: int
    user_id: int
    analysis_id: int
    lichen_detected: bool
    state: str
    humidity: float
    air_quality: str
    location: str
    created_at: datetime

class HistorySaveRequest(BaseModel):
    analysis_id: int
    location: str

class HistoryDeleteRequest(BaseModel):
    analysis_id: int

@router.post("/save", response_model=HistoryResponse, status_code=status.HTTP_201_CREATED, summary="Guardar análisis en historial")
def save_history(request: HistorySaveRequest):
    """
    Endpoint para guardar un análisis en el historial del usuario
    - RF013: Sistema guardar historial
    """
    return {
        "id": 1,
        "user_id": 1,
        "analysis_id": request.analysis_id,
        "lichen_detected": True,
        "state": "healthy",
        "humidity": 65.5,
        "air_quality": "moderate",
        "location": request.location,
        "created_at": datetime.now()
    }

@router.get("", response_model=List[HistoryResponse], summary="Obtener historial del usuario")
def get_history():
    """
    Endpoint para obtener el historial completo del usuario autenticado
    - RF014: Sistema consultar historial
    """
    return [
        {
            "id": 1,
            "user_id": 1,
            "analysis_id": 1,
            "lichen_detected": True,
            "state": "healthy",
            "humidity": 65.5,
            "air_quality": "moderate",
            "location": "Bogotá, Colombia",
            "created_at": datetime.now()
        }
    ]

@router.get("/user/{user_id}", response_model=List[HistoryResponse], summary="Obtener historial de usuario específico")
def get_user_history(user_id: int):
    """
    Endpoint para obtener el historial de un usuario específico (admin)
    - RF014: Sistema consultar historial
    """
    return [
        {
            "id": 1,
            "user_id": user_id,
            "analysis_id": 1,
            "lichen_detected": True,
            "state": "healthy",
            "humidity": 65.5,
            "air_quality": "moderate",
            "location": "Bogotá, Colombia",
            "created_at": datetime.now()
        }
    ]

@router.delete("/{history_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar historial")
def delete_history(history_id: int):
    """
    Endpoint para eliminar un registro del historial
    """
    return None
