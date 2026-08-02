from datetime import date, datetime
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel, EmailStr
from typing import Optional
from models.core import Usuario
from config.db import get_db
from config.settings import normalize_image_path
from auth.auth_service import get_current_user

router = APIRouter(tags=["Profile"])


class ProfileUpdate(BaseModel):
    """Modelo para actualizar perfil del usuario"""
    nombre: Optional[str] = None
    apellido: Optional[str] = None
    correo: Optional[EmailStr] = None
    telefono: Optional[str] = None
    tipo_documento: Optional[str] = None
    numero_documento: Optional[str] = None
    fecha_nacimiento: Optional[date] = None
    foto_perfil: Optional[str] = None


class ProfileResponse(BaseModel):
    """Modelo de respuesta del perfil"""
    id: int
    nombre: Optional[str]
    apellido: Optional[str]
    correo: str
    telefono: Optional[str]
    tipo_documento: Optional[str] = None
    numero_documento: Optional[str] = None
    fecha_nacimiento: Optional[str] = None
    foto_perfil: Optional[str] = None
    fecha_registro: Optional[str] = None

    class Config:
        from_attributes = True

    @staticmethod
    def from_usuario(usuario: Usuario):
        fecha_nacimiento = None
        fecha_registro = None

        if usuario.fecha_nacimiento is not None:
            try:
                fecha_nacimiento = usuario.fecha_nacimiento.date().isoformat()
            except Exception:
                fecha_nacimiento = usuario.fecha_nacimiento.isoformat()

        if usuario.fecha_registro is not None:
            try:
                fecha_registro = usuario.fecha_registro.isoformat()
            except Exception:
                fecha_registro = datetime.fromtimestamp(usuario.fecha_registro.timestamp()).isoformat()

        return ProfileResponse(
            id=usuario.id_usuario,
            nombre=usuario.nombre,
            apellido=usuario.apellido,
            correo=usuario.correo,
            telefono=usuario.telefono,
            tipo_documento=usuario.tipo_documento,
            numero_documento=usuario.numero_documento,
            fecha_nacimiento=fecha_nacimiento,
            foto_perfil=usuario.foto_perfil,
            fecha_registro=fecha_registro,
        )


@router.get("/profile", response_model=ProfileResponse, summary="Obtener perfil del usuario")
def get_profile(current_user: Usuario = Depends(get_current_user), db: Session = Depends(get_db)):
    """
    Obtiene el perfil del usuario autenticado
    """
    return ProfileResponse.from_usuario(current_user)


@router.put("/profile", response_model=ProfileResponse, summary="Actualizar perfil del usuario")
def update_profile(
    profile_update: ProfileUpdate,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Actualiza el perfil del usuario autenticado
    - RF016: Usuario editar su perfil
    """
    try:
        # Validar que el email sea único si se intenta cambiar
        if profile_update.correo and profile_update.correo != current_user.correo:
            existing_user = db.query(Usuario).filter(Usuario.correo == profile_update.correo).first()
            if existing_user:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Este email ya está registrado"
                )

        # Actualizar solo los campos que se envíen
        if profile_update.nombre is not None:
            current_user.nombre = profile_update.nombre
        if profile_update.apellido is not None:
            current_user.apellido = profile_update.apellido
        if profile_update.correo is not None:
            current_user.correo = profile_update.correo
        if profile_update.telefono is not None:
            current_user.telefono = profile_update.telefono
        if profile_update.tipo_documento is not None:
            current_user.tipo_documento = profile_update.tipo_documento
        if profile_update.numero_documento is not None:
            current_user.numero_documento = profile_update.numero_documento
        if profile_update.fecha_nacimiento is not None:
            current_user.fecha_nacimiento = profile_update.fecha_nacimiento
        if profile_update.foto_perfil is not None:
            old_foto = current_user.foto_perfil
            new_foto = normalize_image_path(profile_update.foto_perfil)
            if old_foto and old_foto != new_foto and old_foto.startswith("/uploads/"):
                try:
                    from services.upload_service import resolve_file_path
                    old_file_path = resolve_file_path(old_foto)
                    if old_file_path is not None:
                        old_file_path.unlink(missing_ok=True)
                except Exception:
                    pass
            current_user.foto_perfil = new_foto

        db.commit()
        db.refresh(current_user)
        return ProfileResponse.from_usuario(current_user)

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al actualizar perfil: {str(e)}"
        )
