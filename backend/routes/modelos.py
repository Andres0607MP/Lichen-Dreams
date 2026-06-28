from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
from sqlalchemy.orm import Session

from config.db import get_db
from models.core import ModeloIA

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

    class Config:
        from_attributes = True


@router.get("", response_model=List[ModelResponse], summary="Listar modelos IA")
def list_models(db: Session = Depends(get_db)):
    models = db.query(ModeloIA).all()
    return models


@router.post("", response_model=ModelResponse, status_code=status.HTTP_201_CREATED, summary="Crear modelo IA")
def create_model(payload: ModelCreate, db: Session = Depends(get_db)):
    model = ModeloIA(
        nombre_modelo=payload.nombre_modelo,
        version=payload.version,
        descripcion=payload.descripcion
    )
    db.add(model)
    db.commit()
    db.refresh(model)
    return model


@router.get("/{model_id}", response_model=ModelResponse, summary="Obtener modelo por ID")
def get_model(model_id: int, db: Session = Depends(get_db)):
    model = db.query(ModeloIA).filter(ModeloIA.id_modelo == model_id).first()
    if not model:
        raise HTTPException(status_code=404, detail="Modelo no encontrado")
    return model


@router.put("/{model_id}", response_model=ModelResponse, summary="Actualizar modelo")
def update_model(model_id: int, payload: ModelCreate, db: Session = Depends(get_db)):
    model = db.query(ModeloIA).filter(ModeloIA.id_modelo == model_id).first()
    if not model:
        raise HTTPException(status_code=404, detail="Modelo no encontrado")
    model.nombre_modelo = payload.nombre_modelo
    model.version = payload.version
    model.descripcion = payload.descripcion
    db.commit()
    db.refresh(model)
    return model


@router.delete("/{model_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar modelo")
def delete_model(model_id: int, db: Session = Depends(get_db)):
    model = db.query(ModeloIA).filter(ModeloIA.id_modelo == model_id).first()
    if not model:
        raise HTTPException(status_code=404, detail="Modelo no encontrado")
    db.delete(model)
    db.commit()
    return None
