from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

router = APIRouter()


class DatasetCreate(BaseModel):
    nombre_dataset: str
    ruta_archivo: Optional[str] = None
    tipo_datos: Optional[str] = None


class DatasetResponse(BaseModel):
    id_dataset: int
    nombre_dataset: str
    ruta_archivo: Optional[str]
    tipo_datos: Optional[str]
    fecha_creacion: datetime


@router.get("", response_model=List[DatasetResponse], summary="Listar datasets")
def list_datasets():
    return [
        {
            "id_dataset": 1,
            "nombre_dataset": "dataset_inicial",
            "ruta_archivo": "/data/ds1.zip",
            "tipo_datos": "imagenes",
            "fecha_creacion": datetime.now()
        }
    ]


@router.post("", response_model=DatasetResponse, status_code=status.HTTP_201_CREATED, summary="Crear dataset")
def create_dataset(payload: DatasetCreate):
    return {
        "id_dataset": 1,
        "nombre_dataset": payload.nombre_dataset,
        "ruta_archivo": payload.ruta_archivo,
        "tipo_datos": payload.tipo_datos,
        "fecha_creacion": datetime.now()
    }


@router.get("/{dataset_id}", response_model=DatasetResponse, summary="Obtener dataset por ID")
def get_dataset(dataset_id: int):
    return {
        "id_dataset": dataset_id,
        "nombre_dataset": "dataset_inicial",
        "ruta_archivo": "/data/ds1.zip",
        "tipo_datos": "imagenes",
        "fecha_creacion": datetime.now()
    }


@router.put("/{dataset_id}", response_model=DatasetResponse, summary="Actualizar dataset")
def update_dataset(dataset_id: int, payload: DatasetCreate):
    return {
        "id_dataset": dataset_id,
        "nombre_dataset": payload.nombre_dataset,
        "ruta_archivo": payload.ruta_archivo,
        "tipo_datos": payload.tipo_datos,
        "fecha_creacion": datetime.now()
    }


@router.delete("/{dataset_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar dataset")
def delete_dataset(dataset_id: int):
    return None


@router.post("/{dataset_id}/associate", summary="Asociar dataset con un modelo")
def associate_dataset_model(dataset_id: int, model_id: int):
    """Asocia `dataset_id` con `model_id` (modelo_dataset)."""
    return {
        "dataset_id": dataset_id,
        "model_id": model_id,
        "associated": True,
        "fecha_asociacion": datetime.now()
    }
