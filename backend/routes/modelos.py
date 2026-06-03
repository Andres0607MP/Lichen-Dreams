from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

router = APIRouter()


class ModelCreate(BaseModel):
    nombre_modelo: str
    version: Optional[str] = None
    descripcion: Optional[str] = None


class ModelResponse(BaseModel):
    id_modelo: int
    nombre_modelo: str
    version: Optional[str]
    descripcion: Optional[str]
    fecha_creacion: datetime


@router.get("", response_model=List[ModelResponse], summary="Listar modelos IA")
def list_models():
    return [
        {
            "id_modelo": 1,
            "nombre_modelo": "modelo_v1",
            "version": "1.0",
            "descripcion": "Modelo de detección inicial",
            "fecha_creacion": datetime.now()
        }
    ]


@router.post("", response_model=ModelResponse, status_code=status.HTTP_201_CREATED, summary="Crear modelo IA")
def create_model(payload: ModelCreate):
    return {
        "id_modelo": 1,
        "nombre_modelo": payload.nombre_modelo,
        "version": payload.version,
        "descripcion": payload.descripcion,
        "fecha_creacion": datetime.now()
    }


@router.get("/{model_id}", response_model=ModelResponse, summary="Obtener modelo por ID")
def get_model(model_id: int):
    return {
        "id_modelo": model_id,
        "nombre_modelo": "modelo_v1",
        "version": "1.0",
        "descripcion": "Descripción mock",
        "fecha_creacion": datetime.now()
    }


@router.put("/{model_id}", response_model=ModelResponse, summary="Actualizar modelo")
def update_model(model_id: int, payload: ModelCreate):
    return {
        "id_modelo": model_id,
        "nombre_modelo": payload.nombre_modelo,
        "version": payload.version,
        "descripcion": payload.descripcion,
        "fecha_creacion": datetime.now()
    }


@router.delete("/{model_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar modelo")
def delete_model(model_id: int):
    return None
