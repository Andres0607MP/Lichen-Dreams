from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, EmailStr
from typing import Optional

router = APIRouter()

class LoginRequest(BaseModel):
    email: str
    password: str

class RegisterRequest(BaseModel):
    email: EmailStr
    password: str
    name: str
    phone: Optional[str] = None

class UserResponse(BaseModel):
    id: int
    email: str
    name: str
    phone: Optional[str]
    role: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    user: UserResponse

@router.post("/login", response_model=TokenResponse, summary="Iniciar sesión")
def login(request: LoginRequest):
    """
    Endpoint para autenticar usuario
    - **email**: Email del usuario
    - **password**: Contraseña del usuario
    """
    return {
        "access_token": "token_example",
        "token_type": "bearer",
        "user": {
            "id": 1,
            "email": request.email,
            "name": "Usuario",
            "phone": None,
            "role": "user"
        }
    }

@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED, summary="Registrar nuevo usuario")
def register(request: RegisterRequest):
    """
    Endpoint para registrar un nuevo usuario
    - **email**: Email del usuario
    - **password**: Contraseña del usuario
    - **name**: Nombre del usuario
    - **phone**: Teléfono (opcional)
    """
    return {
        "id": 1,
        "email": request.email,
        "name": request.name,
        "phone": request.phone,
        "role": "user"
    }

@router.get("/me", response_model=UserResponse, summary="Obtener información del usuario actual")
def get_current_user():
    """
    Endpoint para obtener información del usuario autenticado
    """
    return {
        "id": 1,
        "email": "user@example.com",
        "name": "Usuario Actual",
        "phone": None,
        "role": "user"
    }

@router.post("/logout", summary="Cerrar sesión")
def logout():
    """
    Endpoint para cerrar sesión del usuario
    """
    return {"message": "Sesión cerrada exitosamente"}
