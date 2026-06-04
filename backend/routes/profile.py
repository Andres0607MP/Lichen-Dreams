from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel, EmailStr
from typing import Optional
from models.core import Usuario
from config.database import get_db
from auth.auth_service import get_current_user

router = APIRouter(tags=["Profile"])


class ProfileUpdate(BaseModel):
    """Modelo para actualizar perfil del usuario"""
    nombre: Optional[str] = None
    apellido: Optional[str] = None
    correo: Optional[EmailStr] = None
    telefono: Optional[str] = None


class ProfileResponse(BaseModel):
    """Modelo de respuesta del perfil"""
    id: int
    nombre: Optional[str]
    apellido: Optional[str]
    correo: str
    telefono: Optional[str]
    fecha_registro: str

    class Config:
        from_attributes = True

    @staticmethod
    def from_usuario(usuario: Usuario):
        return ProfileResponse(
            id=usuario.id_usuario,
            nombre=usuario.nombre,
            apellido=usuario.apellido,
            correo=usuario.correo,
            telefono=usuario.telefono,
            fecha_registro=usuario.fecha_registro.isoformat() if usuario.fecha_registro else None
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
