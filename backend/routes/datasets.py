from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
from sqlalchemy.orm import Session

from config.db import get_db
from models.core import Dataset as DatasetModel

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

    class Config:
        orm_mode = True


@router.get("", response_model=List[DatasetResponse], summary="Listar datasets")
def list_datasets(db: Session = Depends(get_db)):
    items = db.query(DatasetModel).all()
    return items


@router.post("", response_model=DatasetResponse, status_code=status.HTTP_201_CREATED, summary="Crear dataset")
def create_dataset(payload: DatasetCreate, db: Session = Depends(get_db)):
    ds = DatasetModel(
        nombre_dataset=payload.nombre_dataset,
        ruta_archivo=payload.ruta_archivo,
        tipo_datos=payload.tipo_datos
    )
    db.add(ds)
    db.commit()
    db.refresh(ds)
    return ds


@router.get("/{dataset_id}", response_model=DatasetResponse, summary="Obtener dataset por ID")
def get_dataset(dataset_id: int, db: Session = Depends(get_db)):
    ds = db.query(DatasetModel).filter(DatasetModel.id_dataset == dataset_id).first()
    if not ds:
        raise HTTPException(status_code=404, detail="Dataset no encontrado")
    return ds


@router.put("/{dataset_id}", response_model=DatasetResponse, summary="Actualizar dataset")
def update_dataset(dataset_id: int, payload: DatasetCreate, db: Session = Depends(get_db)):
    ds = db.query(DatasetModel).filter(DatasetModel.id_dataset == dataset_id).first()
    if not ds:
        raise HTTPException(status_code=404, detail="Dataset no encontrado")
    ds.nombre_dataset = payload.nombre_dataset
    ds.ruta_archivo = payload.ruta_archivo
    ds.tipo_datos = payload.tipo_datos
    db.commit()
    db.refresh(ds)
    return ds


@router.delete("/{dataset_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar dataset")
def delete_dataset(dataset_id: int, db: Session = Depends(get_db)):
    ds = db.query(DatasetModel).filter(DatasetModel.id_dataset == dataset_id).first()
    if not ds:
        raise HTTPException(status_code=404, detail="Dataset no encontrado")
    db.delete(ds)
    db.commit()
    return None


@router.post("/{dataset_id}/associate", summary="Asociar dataset con un modelo")
def associate_dataset_model(dataset_id: int, model_id: int, db: Session = Depends(get_db)):
    # Aquí solo devolvemos una respuesta mock; implementar tabla intermedia si es necesario
    return {
        "dataset_id": dataset_id,
        "model_id": model_id,
        "associated": True,
        "fecha_asociacion": datetime.now()
    }
