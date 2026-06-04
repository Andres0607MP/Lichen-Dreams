from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel, EmailStr
from typing import Optional, List
from sqlalchemy.orm import Session

from config.db import get_db
from models.core import Usuario
from auth.auth_service import require_admin

router = APIRouter()

class UserResponse(BaseModel):
    id_usuario: int
    correo: str
    nombre: Optional[str]
    telefono: Optional[str]
    rol: Optional[str]
    activo: bool

class UserUpdate(BaseModel):
    email: Optional[EmailStr] = None
    name: Optional[str] = None
    phone: Optional[str] = None
    activo: Optional[bool] = None


def user_to_response(user: Usuario):
    return {
        "id_usuario": user.id_usuario,
        "correo": user.correo,
        "nombre": user.nombre,
        "telefono": user.telefono,
        "rol": user.rol.nombre_rol if user.rol else None,
        "activo": user.estado_cuenta == 'active'
    }

@router.get("", response_model=List[UserResponse], summary="Obtener lista de usuarios")
def get_users(current_user: Usuario = Depends(require_admin), db: Session = Depends(get_db)):
    users = db.query(Usuario).all()
    return [user_to_response(user) for user in users]

@router.get("/{user_id}", response_model=UserResponse, summary="Obtener usuario por ID")
def get_user(user_id: int, current_user: Usuario = Depends(require_admin), db: Session = Depends(get_db)):
    user = db.query(Usuario).filter(Usuario.id_usuario == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado")
    return user_to_response(user)

@router.put("/{user_id}", response_model=UserResponse, summary="Actualizar usuario")
def update_user(user_id: int, request: UserUpdate, current_user: Usuario = Depends(require_admin), db: Session = Depends(get_db)):
    user = db.query(Usuario).filter(Usuario.id_usuario == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado")
    if request.email is not None:
        user.correo = request.email
    if request.name is not None:
        user.nombre = request.name
    if request.phone is not None:
        user.telefono = request.phone
    if request.activo is not None:
        user.estado_cuenta = 'active' if request.activo else 'inactive'
    db.commit()
    db.refresh(user)
    return user_to_response(user)

@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar usuario")
def delete_user(user_id: int, current_user: Usuario = Depends(require_admin), db: Session = Depends(get_db)):
    if current_user.id_usuario == user_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="El administrador no puede eliminarse a sí mismo")
    user = db.query(Usuario).filter(Usuario.id_usuario == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado")
    db.delete(user)
    db.commit()
    return None
