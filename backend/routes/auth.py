from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel, EmailStr
from typing import Optional
from sqlalchemy.orm import Session

from config.db import get_db
from models.core import Usuario
from auth.password_handler import hash_password, verify_password
from auth.jwt_handler import create_access_token
from auth.auth_service import authenticate_user, get_current_user

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
    id_usuario: int
    correo: str
    nombre: Optional[str]
    telefono: Optional[str]
    id_rol: Optional[int]

    class Config:
        orm_mode = True


class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    user: UserResponse


@router.post("/login", response_model=TokenResponse, summary="Iniciar sesión")
def login(request: LoginRequest, db: Session = Depends(get_db)):
    user = authenticate_user(db, request.email, request.password)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Credenciales inválidas")
    token = create_access_token(subject=user.correo)
    return {"access_token": token, "token_type": "bearer", "user": user}


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED, summary="Registrar nuevo usuario")
def register(request: RegisterRequest, db: Session = Depends(get_db)):
    existing = db.query(Usuario).filter(Usuario.correo == request.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="Usuario ya existe")
    user = Usuario(
        nombre=request.name,
        correo=request.email,
        contraseña=hash_password(request.password),
        telefono=request.phone
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.get("/me", response_model=UserResponse, summary="Obtener información del usuario actual")
def me(current_user: Usuario = Depends(get_current_user)):
    return current_user


@router.post("/logout", summary="Cerrar sesión")
def logout():
    return {"message": "Sesión cerrada exitosamente"}
