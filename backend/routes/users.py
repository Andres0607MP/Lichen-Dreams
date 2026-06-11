from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel, EmailStr
from typing import Optional, List
from sqlalchemy.orm import Session
from sqlalchemy import and_

from config.db import get_db
from models.core import Usuario, Role
from auth.auth_service import get_current_user

router = APIRouter()


class UserResponse(BaseModel):
    id_usuario: int
    nombre: str
    apellido: Optional[str]
    correo: str
    telefono: Optional[str]
    estado_cuenta: str
    id_rol: Optional[int]

    class Config:
        orm_mode = True


class UserUpdate(BaseModel):
    nombre: Optional[str] = None
    apellido: Optional[str] = None
    correo: Optional[EmailStr] = None
    telefono: Optional[str] = None
    id_rol: Optional[int] = None


class UserCreate(BaseModel):
    nombre: str
    apellido: Optional[str] = None
    correo: EmailStr
    telefono: Optional[str] = None
    id_rol: Optional[int] = None


def verify_admin(current_user: Usuario = Depends(get_current_user)):
    """Verifica que el usuario actual sea administrador"""
    if current_user.rol is None or current_user.rol.nombre_rol != 'admin':
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo administradores pueden acceder a este recurso"
        )
    return current_user


@router.get("", response_model=List[UserResponse], summary="Listar usuarios (admin only)")
def list_users(
    skip: int = 0,
    limit: int = 100,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db)
):
    """
    Obtiene la lista de todos los usuarios (solo acceso de administrador)
    
    - **skip**: número de registros a saltar (paginación)
    - **limit**: número máximo de registros a retornar
    """
    users = db.query(Usuario).filter(
        Usuario.estado_cuenta != 'eliminado'
    ).offset(skip).limit(limit).all()
    return users


@router.get("/{user_id}", response_model=UserResponse, summary="Obtener usuario por ID (admin only)")
def get_user(
    user_id: int,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db)
):
    """
    Obtiene un usuario específico por su ID (solo acceso de administrador)
    
    - **user_id**: ID del usuario a obtener
    """
    user = db.query(Usuario).filter(
        and_(
            Usuario.id_usuario == user_id,
            Usuario.estado_cuenta != 'eliminado'
        )
    ).first()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado"
        )
    
    return user


@router.put("/{user_id}", response_model=UserResponse, summary="Actualizar usuario (admin only)")
def update_user(
    user_id: int,
    request: UserUpdate,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db)
):
    """
    Actualiza un usuario existente (solo acceso de administrador)
    
    - **user_id**: ID del usuario a actualizar
    - **request**: Datos a actualizar
    """
    user = db.query(Usuario).filter(
        and_(
            Usuario.id_usuario == user_id,
            Usuario.estado_cuenta != 'eliminado'
        )
    ).first()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado"
        )
    
    # Validar email duplicado si se proporciona
    if request.correo and request.correo != user.correo:
        existing = db.query(Usuario).filter(Usuario.correo == request.correo).first()
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Email ya existe"
            )
    
    # Actualizar campos
    if request.nombre is not None:
        user.nombre = request.nombre
    if request.apellido is not None:
        user.apellido = request.apellido
    if request.correo is not None:
        user.correo = request.correo
    if request.telefono is not None:
        user.telefono = request.telefono
    if request.id_rol is not None:
        user.id_rol = request.id_rol
    
    db.commit()
    db.refresh(user)
    return user


@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar usuario (admin only, soft delete)")
def delete_user(
    user_id: int,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db)
):
    """
    Elimina un usuario de forma lógica (soft delete - no borra de BD)
    
    - **user_id**: ID del usuario a eliminar
    """
    user = db.query(Usuario).filter(
        and_(
            Usuario.id_usuario == user_id,
            Usuario.estado_cuenta != 'eliminado'
        )
    ).first()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado"
        )
    
    # Soft delete: marcar como eliminado sin borrar del BD
    user.estado_cuenta = 'eliminado'
    db.commit()
    
    return None
