from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel
from typing import List
from datetime import datetime
from sqlalchemy.orm import Session

from config.db import get_db
from models.core import Notificacion, Usuario
from auth.auth_service import get_current_user

router = APIRouter()


class NotificacionResponse(BaseModel):
    id: int
    id_usuario: int
    titulo: str
    mensaje: str
    tipo_notificacion: str
    estado_notificacion: str
    fecha: datetime

    class Config:
        from_attributes = True


class NotificacionClearResponse(BaseModel):
    message: str


def _notificacion_to_response(notif: Notificacion) -> NotificacionResponse:
    return NotificacionResponse(
        id=notif.id_notificacion,
        id_usuario=notif.id_usuario,
        titulo=notif.titulo or "",
        mensaje=notif.mensaje or "",
        tipo_notificacion=notif.tipo_notificacion or "general",
        estado_notificacion=notif.estado_notificacion or "pendiente",
        fecha=notif.fecha or datetime.now(),
    )


@router.get("", response_model=List[NotificacionResponse], summary="Obtener notificaciones del usuario")
def get_notificaciones(
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Obtiene las notificaciones del usuario autenticado."""
    items = db.query(Notificacion).filter(
        Notificacion.id_usuario == current_user.id_usuario
    ).order_by(Notificacion.fecha.desc()).all()
    return [_notificacion_to_response(item) for item in items]


@router.delete("/clear", response_model=NotificacionClearResponse, summary="Limpiar todas las notificaciones del usuario")
def clear_notificaciones(
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Elimina todas las notificaciones del usuario autenticado."""
    db.query(Notificacion).filter(
        Notificacion.id_usuario == current_user.id_usuario
    ).delete(synchronize_session=False)
    db.commit()
    return NotificacionClearResponse(message="Notificaciones eliminadas correctamente")


@router.patch("/{notificacion_id}/read", response_model=NotificacionResponse, summary="Marcar notificación como leída")
def mark_notificacion_read(
    notificacion_id: int,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Marca una notificación como leída."""
    notif = db.query(Notificacion).filter(
        Notificacion.id_notificacion == notificacion_id,
        Notificacion.id_usuario == current_user.id_usuario,
    ).first()
    if not notif:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Notificación no encontrada")

    notif.estado_notificacion = "leida"
    db.commit()
    db.refresh(notif)
    return _notificacion_to_response(notif)
