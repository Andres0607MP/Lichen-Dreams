from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, EmailStr
from typing import Optional, List

router = APIRouter()

class UserResponse(BaseModel):
    id: int
    email: str
    name: str
    phone: Optional[str]
    role: str
    active: bool

class UserUpdate(BaseModel):
    email: Optional[str] = None
    name: Optional[str] = None
    phone: Optional[str] = None

@router.get("", response_model=List[UserResponse], summary="Obtener lista de usuarios")
def get_users():
    """
    Endpoint para obtener la lista de todos los usuarios
    """
    return [
        {
            "id": 1,
            "email": "user1@example.com",
            "name": "Usuario 1",
            "phone": None,
            "role": "user",
            "active": True
        }
    ]

@router.get("/{user_id}", response_model=UserResponse, summary="Obtener usuario por ID")
def get_user(user_id: int):
    """
    Endpoint para obtener un usuario específico por su ID
    """
    return {
        "id": user_id,
        "email": "user@example.com",
        "name": "Usuario",
        "phone": None,
        "role": "user",
        "active": True
    }

@router.put("/{user_id}", response_model=UserResponse, summary="Actualizar usuario")
def update_user(user_id: int, request: UserUpdate):
    """
    Endpoint para actualizar un usuario
    """
    return {
        "id": user_id,
        "email": request.email or "user@example.com",
        "name": request.name or "Usuario",
        "phone": request.phone,
        "role": "user",
        "active": True
    }

@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar usuario")
def delete_user(user_id: int):
    """
    Endpoint para eliminar un usuario
    """
    return None
