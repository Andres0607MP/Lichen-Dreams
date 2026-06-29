from fastapi import APIRouter, status
from pydantic import BaseModel
from typing import List
from datetime import datetime

router = APIRouter()


class HistoryResponse(BaseModel):
    id: int
    id_usuario: int
    id_analisis: int
    resultado: str
    estado: str
    humedad: float
    calidad_del_aire: str
    ubicacion: str
    fecha_creacion: datetime


class HistorySaveRequest(BaseModel):
    analysis_id: int
    location: str


@router.post("/save", response_model=HistoryResponse, status_code=status.HTTP_201_CREATED, summary="Guardar análisis en historial")
def save_history(request: HistorySaveRequest):
    """
    Endpoint para guardar un análisis en el historial del usuario
    - RF013: Sistema guardar historial
    """
    return {
        "id": 1,
        "id_usuario": 1,
        "id_analisis": request.analysis_id,
        "resultado": "liquen saludable",
        "estado": "completado",
        "humedad": 65.5,
        "calidad_del_aire": "moderada",
        "ubicacion": request.location,
        "fecha_creacion": datetime.now(),
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
            "id_usuario": 1,
            "id_analisis": 1,
            "resultado": "liquen saludable",
            "estado": "completado",
            "humedad": 65.5,
            "calidad_del_aire": "moderada",
            "ubicacion": "Bogotá, Colombia",
            "fecha_creacion": datetime.now(),
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
            "id_usuario": user_id,
            "id_analisis": 1,
            "resultado": "liquen saludable",
            "estado": "completado",
            "humedad": 65.5,
            "calidad_del_aire": "moderada",
            "ubicacion": "Bogotá, Colombia",
            "fecha_creacion": datetime.now(),
        }
    ]


@router.delete("/{history_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar historial")
def delete_history(history_id: int):
    """
    Endpoint para eliminar un registro del historial
    """
    return None
