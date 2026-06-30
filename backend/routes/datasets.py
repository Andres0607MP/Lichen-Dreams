from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
from sqlalchemy.orm import Session

from config.db import get_db
from models.core import Dataset as DatasetModel, Usuario
from auth.auth_service import get_current_user

router = APIRouter()


class DatasetCreate(BaseModel):
    nombre_dataset: str
    ruta_archivo: Optional[str] = None
    tipo_datos: Optional[str] = None


class DatasetUpdate(BaseModel):
    nombre_dataset: Optional[str] = None
    ruta_archivo: Optional[str] = None
    tipo_datos: Optional[str] = None


class DatasetResponse(BaseModel):
    id_dataset: int
    nombre_dataset: str
    ruta_archivo: Optional[str]
    tipo_datos: Optional[str]
    fecha_creacion: datetime

    class Config:
        from_attributes = True


def verify_admin(current_user: Usuario = Depends(get_current_user)):
    """Verifica que el usuario sea administrador"""
    if current_user.rol is None or current_user.rol.nombre_rol != 'admin':
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo administradores pueden acceder a este recurso"
        )
    return current_user


@router.get("", response_model=List[DatasetResponse], summary="Listar datasets (público)")
def list_datasets(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db)
):
    """
    Lista todos los datasets disponibles (público)
    
    - **skip**: número de registros a saltar (paginación)
    - **limit**: número máximo de registros a retornar
    """
    datasets = db.query(DatasetModel).offset(skip).limit(limit).all()
    return datasets


@router.post("", response_model=DatasetResponse, status_code=status.HTTP_201_CREATED, summary="Crear dataset (admin only)")
def create_dataset(
    payload: DatasetCreate,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db)
):
    """
    Crea un nuevo dataset (solo administradores)
    
    - **nombre_dataset**: nombre del dataset (requerido)
    - **ruta_archivo**: ruta del archivo (opcional)
    - **tipo_datos**: tipo de datos (opcional)
    """
    ds = DatasetModel(
        nombre_dataset=payload.nombre_dataset,
        ruta_archivo=payload.ruta_archivo,
        tipo_datos=payload.tipo_datos
    )
    db.add(ds)
    db.commit()
    db.refresh(ds)
    return ds


@router.get("/{dataset_id}", response_model=DatasetResponse, summary="Obtener dataset por ID (público)")
def get_dataset(
    dataset_id: int,
    db: Session = Depends(get_db)
):
    """
    Obtiene un dataset específico por su ID (público)
    
    - **dataset_id**: ID del dataset
    """
    ds = db.query(DatasetModel).filter(DatasetModel.id_dataset == dataset_id).first()
    if not ds:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Dataset no encontrado"
        )
    return ds


@router.put("/{dataset_id}", response_model=DatasetResponse, summary="Actualizar dataset (admin only)")
def update_dataset(
    dataset_id: int,
    payload: DatasetUpdate,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db)
):
    """
    Actualiza un dataset existente (solo administradores)
    
    - **dataset_id**: ID del dataset a actualizar
    """
    ds = db.query(DatasetModel).filter(DatasetModel.id_dataset == dataset_id).first()
    if not ds:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Dataset no encontrado"
        )
    
    if payload.nombre_dataset is not None:
        ds.nombre_dataset = payload.nombre_dataset
    if payload.ruta_archivo is not None:
        ds.ruta_archivo = payload.ruta_archivo
    if payload.tipo_datos is not None:
        ds.tipo_datos = payload.tipo_datos
    
    db.commit()
    db.refresh(ds)
    return ds


@router.delete("/{dataset_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar dataset (admin only)")
def delete_dataset(
    dataset_id: int,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db)
):
    """
    Elimina un dataset (solo administradores)
    
    - **dataset_id**: ID del dataset a eliminar
    """
    ds = db.query(DatasetModel).filter(DatasetModel.id_dataset == dataset_id).first()
    if not ds:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Dataset no encontrado"
        )
    db.delete(ds)
    db.commit()
    return None

