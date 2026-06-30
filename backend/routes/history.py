<<<<<<< HEAD
from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel
from typing import List, Optional
=======
from fastapi import APIRouter, status
from pydantic import BaseModel, Field
from typing import List
>>>>>>> 0e0c74949dcb5c2453167deb1457685af8cfd684
from datetime import datetime
from sqlalchemy.orm import Session

from config.db import get_db
from models.core import HistorialActividad, Usuario
from auth.auth_service import get_current_user

router = APIRouter()


class HistoryResponse(BaseModel):
<<<<<<< HEAD
    id_historial: int
    accion: str
    descripcion: Optional[str]
    fecha: datetime
    id_usuario: int

    class Config:
        from_attributes = True
=======
    id: int
    id_usuario: int
    id_analisis: int
    url_imagen: str = ""
    resultado: str = ""
    estado: str = ""
    humedad: float = 0.0
    calidad_del_aire: str = ""
    recomendacion: str = ""
    ubicacion: str = ""
    fecha_creacion: datetime = Field(default_factory=datetime.now)
>>>>>>> 0e0c74949dcb5c2453167deb1457685af8cfd684


class HistorySaveRequest(BaseModel):
    analysis_id: int
    location: str
    accion: Optional[str] = "analisis_guardado"


def verify_admin(current_user: Usuario = Depends(get_current_user)):
    """Verifica que el usuario sea administrador"""
    if current_user.rol is None or current_user.rol.nombre_rol != 'admin':
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo administradores pueden acceder a este recurso"
        )
    return current_user


@router.post("/save", response_model=HistoryResponse, status_code=status.HTTP_201_CREATED, summary="Guardar análisis en historial")
def save_history(
    request: HistorySaveRequest,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
<<<<<<< HEAD
    Guarda un registro de actividad en el historial del usuario autenticado.

    - **analysis_id**: ID del análisis relacionado
    - **location**: ubicación asociada al análisis
    - **accion**: descripción corta de la acción (opcional)
    """
    registro = HistorialActividad(
        accion=request.accion,
        descripcion=f"analysis_id={request.analysis_id}; location={request.location}",
        id_usuario=current_user.id_usuario
    )
    db.add(registro)
    db.commit()
    db.refresh(registro)
    return registro


@router.get("", response_model=List[HistoryResponse], summary="Obtener historial del usuario autenticado")
def get_history(
    skip: int = 0,
    limit: int = 100,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
=======
    Endpoint para guardar un análisis en el historial del usuario
    - RF013: Sistema guardar historial
    """
    return {
        "id": 1,
        "id_usuario": 1,
        "id_analisis": request.analysis_id,
        "url_imagen": "https://example.com/image.jpg",
        "resultado": "liquen saludable",
        "estado": "completado",
        "humedad": 65.5,
        "calidad_del_aire": "moderada",
        "recomendacion": "Buena calidad de aire en la zona",
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
            "url_imagen": "https://example.com/image.jpg",
            "resultado": "liquen saludable",
            "estado": "completado",
            "humedad": 65.5,
            "calidad_del_aire": "moderada",
            "recomendacion": "Buena calidad de aire en la zona",
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
            "url_imagen": "https://example.com/image.jpg",
            "resultado": "liquen saludable",
            "estado": "completado",
            "humedad": 65.5,
            "calidad_del_aire": "moderada",
            "recomendacion": "Buena calidad de aire en la zona",
            "ubicacion": "Bogotá, Colombia",
            "fecha_creacion": datetime.now(),
        }
    ]


@router.delete("/{history_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar historial")
def delete_history(history_id: int):
>>>>>>> 0e0c74949dcb5c2453167deb1457685af8cfd684
    """
    Obtiene el historial de actividad del usuario autenticado.
    """
    items = db.query(HistorialActividad).filter(
        HistorialActividad.id_usuario == current_user.id_usuario
    ).order_by(HistorialActividad.fecha.desc()).offset(skip).limit(limit).all()
    return items


@router.get("/user/{user_id}", response_model=List[HistoryResponse], summary="Obtener historial de un usuario específico (admin)")
def get_user_history(
    user_id: int,
    skip: int = 0,
    limit: int = 100,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db)
):
    """
    Obtiene el historial de actividad de un usuario específico (solo administradores).
    """
    items = db.query(HistorialActividad).filter(
        HistorialActividad.id_usuario == user_id
    ).order_by(HistorialActividad.fecha.desc()).offset(skip).limit(limit).all()
    return items


@router.delete("/{history_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar registro de historial")
def delete_history(
    history_id: int,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Elimina un registro del historial (propietario o administrador).
    """
    registro = db.query(HistorialActividad).filter(
        HistorialActividad.id_historial == history_id
    ).first()

    if not registro:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Registro de historial no encontrado")

    is_owner = registro.id_usuario == current_user.id_usuario
    is_admin = current_user.rol and current_user.rol.nombre_rol == 'admin'

    if not (is_owner or is_admin):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="No tienes permiso para eliminar este registro")

    db.delete(registro)
    db.commit()
    return None
