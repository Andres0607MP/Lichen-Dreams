from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
from sqlalchemy.orm import Session

from config.db import get_db
from models.core import ModeloIA, Usuario
from auth.auth_service import get_current_user

router = APIRouter()


class ModelCreate(BaseModel):
    nombre_modelo: str
    version: Optional[str] = None
    descripcion: Optional[str] = None


class ModelUpdate(BaseModel):
    nombre_modelo: Optional[str] = None
    version: Optional[str] = None
    descripcion: Optional[str] = None


class ModelResponse(BaseModel):
    id_modelo: int
    nombre_modelo: str
    version: Optional[str]
    descripcion: Optional[str]
    fecha_creacion: datetime

    class Config:
        orm_mode = True


def verify_admin(current_user: Usuario = Depends(get_current_user)):
    """Verifica que el usuario sea administrador"""
    if current_user.rol is None or current_user.rol.nombre_rol != 'admin':
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo administradores pueden acceder a este recurso"
        )
    return current_user


@router.get("", response_model=List[ModelResponse], summary="Listar modelos IA (público)")
def list_models(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db)
):
    """
    Lista todos los modelos IA disponibles (público)
    
    - **skip**: número de registros a saltar (paginación)
    - **limit**: número máximo de registros a retornar
    """
    models = db.query(ModeloIA).offset(skip).limit(limit).all()
    return models


@router.post("", response_model=ModelResponse, status_code=status.HTTP_201_CREATED, summary="Crear modelo IA (admin only)")
def create_model(
    payload: ModelCreate,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db)
):
    """
    Crea un nuevo modelo IA (solo administradores)
    
    - **nombre_modelo**: nombre del modelo (requerido)
    - **version**: versión del modelo (opcional)
    - **descripcion**: descripción del modelo (opcional)
    """
    model = ModeloIA(
        nombre_modelo=payload.nombre_modelo,
        version=payload.version,
        descripcion=payload.descripcion
    )
    db.add(model)
    db.commit()
    db.refresh(model)
    return model


@router.get("/{model_id}", response_model=ModelResponse, summary="Obtener modelo por ID (público)")
def get_model(
    model_id: int,
    db: Session = Depends(get_db)
):
    """
    Obtiene un modelo IA específico por su ID (público)
    
    - **model_id**: ID del modelo
    """
    model = db.query(ModeloIA).filter(ModeloIA.id_modelo == model_id).first()
    if not model:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Modelo no encontrado"
        )
    return model


@router.put("/{model_id}", response_model=ModelResponse, summary="Actualizar modelo (admin only)")
def update_model(
    model_id: int,
    payload: ModelUpdate,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db)
):
    """
    Actualiza un modelo IA existente (solo administradores)
    
    - **model_id**: ID del modelo a actualizar
    """
    model = db.query(ModeloIA).filter(ModeloIA.id_modelo == model_id).first()
    if not model:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Modelo no encontrado"
        )
    
    if payload.nombre_modelo is not None:
        model.nombre_modelo = payload.nombre_modelo
    if payload.version is not None:
        model.version = payload.version
    if payload.descripcion is not None:
        model.descripcion = payload.descripcion
    
    db.commit()
    db.refresh(model)
    return model


@router.delete("/{model_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar modelo (admin only)")
def delete_model(
    model_id: int,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db)
):
    """
    Elimina un modelo IA (solo administradores)
    
    - **model_id**: ID del modelo a eliminar
    """
    model = db.query(ModeloIA).filter(ModeloIA.id_modelo == model_id).first()
    if not model:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Modelo no encontrado"
        )
    db.delete(model)
    db.commit()
    return None
