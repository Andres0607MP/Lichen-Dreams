from fastapi import APIRouter, HTTPException, status, UploadFile, File, Depends
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from sqlalchemy.orm import Session
from sqlalchemy import and_
import os
from pathlib import Path

from config.db import get_db
from models.core import Analisis, Imagen, Usuario, ModeloIA, Dataset
from auth.auth_service import get_current_user

router = APIRouter()

# Configuración de upload
UPLOAD_DIR = Path("backend/uploads")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
ALLOWED_FORMATS = {"jpg", "jpeg", "png"}
MAX_FILE_SIZE = 50 * 1024 * 1024  # 50MB


class AnalisisResponse(BaseModel):
    id_analisis: int
    id_usuario: int
    id_modelo: Optional[int]
    id_dataset: Optional[int]
    resultado: Optional[str]
    fecha: datetime

    class Config:
        from_attributes = True


class ImagenResponse(BaseModel):
    id_imagen: int
    id_analisis: int
    url: str
    descripcion: Optional[str]

    class Config:
        from_attributes = True


class AnalisisConImagenesResponse(AnalisisResponse):
    imagenes: List[ImagenResponse]


def verify_ownership_or_admin(analysis_id: int, current_user: Usuario = Depends(get_current_user), db: Session = Depends(get_db)):
    """Verifica que el usuario sea propietario del análisis o administrador"""
    analisis = db.query(Analisis).filter(Analisis.id_analisis == analysis_id).first()
    
    if not analisis:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Análisis no encontrado"
        )
    
    is_owner = analisis.id_usuario == current_user.id_usuario
    is_admin = current_user.rol and current_user.rol.nombre_rol == 'admin'
    
    if not (is_owner or is_admin):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para acceder a este análisis"
        )
    
    return analisis


@router.post("/upload", response_model=dict, summary="Subir imagen para análisis")
async def upload_image(
    file: UploadFile = File(...),
    current_user: Usuario = Depends(get_current_user)
):
    """
    Sube una imagen para análisis (validar formato/tamaño)
    
    - **file**: archivo de imagen (jpg, jpeg, png, máximo 50MB)
    - Formatos válidos: jpg, jpeg, png
    - Tamaño máximo: 50MB
    """
    # Validar extensión
    if not file.filename:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Nombre de archivo inválido"
        )
    
    file_ext = file.filename.split('.')[-1].lower()
    if file_ext not in ALLOWED_FORMATS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Formato no permitido. Formatos válidos: {', '.join(ALLOWED_FORMATS)}"
        )
    
    # Leer contenido para validar tamaño
    contents = await file.read()
    if len(contents) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Archivo demasiado grande. Máximo: {MAX_FILE_SIZE / (1024*1024):.0f}MB"
        )
    
    # Guardar archivo
    file_path = UPLOAD_DIR / f"{current_user.id_usuario}_{file.filename}"
    with open(file_path, "wb") as f:
        f.write(contents)
    
    return {
        "filename": file.filename,
        "size": len(contents),
        "upload_time": datetime.now(),
        "file_path": str(file_path)
    }


@router.post("/process", response_model=AnalisisResponse, summary="Procesar análisis con IA")
def process_analysis(
    id_modelo: Optional[int] = None,
    id_dataset: Optional[int] = None,
    resultado: Optional[str] = None,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Procesa un análisis con IA
    
    - **id_modelo**: ID del modelo IA a usar (opcional)
    - **id_dataset**: ID del dataset a usar (opcional)
    - **resultado**: Resultado del análisis (opcional)
    """
    # Validar que modelo existe si se proporciona
    if id_modelo:
        modelo = db.query(ModeloIA).filter(ModeloIA.id_modelo == id_modelo).first()
        if not modelo:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Modelo IA no encontrado"
            )
    
    # Validar que dataset existe si se proporciona
    if id_dataset:
        dataset = db.query(Dataset).filter(Dataset.id_dataset == id_dataset).first()
        if not dataset:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Dataset no encontrado"
            )
    
    # Crear análisis
    analisis = Analisis(
        id_usuario=current_user.id_usuario,
        id_modelo=id_modelo,
        id_dataset=id_dataset,
        resultado=resultado
    )
    
    db.add(analisis)
    db.commit()
    db.refresh(analisis)
    
    return analisis


@router.get("/{analysis_id}", response_model=AnalisisConImagenesResponse, summary="Obtener análisis por ID (propietario/admin)")
def get_analysis(
    analisis: Analisis = Depends(verify_ownership_or_admin),
    db: Session = Depends(get_db)
):
    """
    Obtiene los detalles de un análisis (propietario o administrador)
    
    - **analysis_id**: ID del análisis
    """
    # Cargar imágenes relacionadas
    imagenes = db.query(Imagen).filter(Imagen.id_analisis == analisis.id_analisis).all()
    
    response = AnalisisConImagenesResponse(
        id_analisis=analisis.id_analisis,
        id_usuario=analisis.id_usuario,
        id_modelo=analisis.id_modelo,
        id_dataset=analisis.id_dataset,
        resultado=analisis.resultado,
        fecha=analisis.fecha,
        imagenes=imagenes
    )
    
    return response


@router.delete("/{analysis_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar análisis (propietario/admin)")
def delete_analysis(
    analisis: Analisis = Depends(verify_ownership_or_admin),
    db: Session = Depends(get_db)
):
    """
    Elimina un análisis y sus imágenes asociadas (propietario o administrador)
    
    - **analysis_id**: ID del análisis a eliminar
    """
    # Eliminar imágenes asociadas
    imagenes = db.query(Imagen).filter(Imagen.id_analisis == analisis.id_analisis).all()
    for imagen in imagenes:
        db.delete(imagen)
    
    # Eliminar análisis
    db.delete(analisis)
    db.commit()
    
    return None


@router.post("/{analysis_id}/images", response_model=ImagenResponse, summary="Agregar imagen a análisis")
def add_image_to_analysis(
    analysis_id: int,
    url: str,
    descripcion: Optional[str] = None,
    analisis: Analisis = Depends(verify_ownership_or_admin),
    db: Session = Depends(get_db)
):
    """
    Agrega una imagen a un análisis existente
    
    - **analysis_id**: ID del análisis
    - **url**: URL de la imagen
    - **descripcion**: Descripción de la imagen (opcional)
    """
    imagen = Imagen(
        id_analisis=analysis_id,
        url=url,
        descripcion=descripcion
    )
    
    db.add(imagen)
    db.commit()
    db.refresh(imagen)
    
    return imagen
