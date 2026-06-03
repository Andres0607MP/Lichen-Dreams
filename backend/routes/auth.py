from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel, EmailStr
from typing import Optional
from sqlalchemy.orm import Session

from config.db import get_db
from models.core import Usuario, Sesion
from auth.password_handler import hash_password, verify_password
from auth.jwt_handler import create_access_token, create_refresh_token, decode_token
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
    refresh_token: str
    token_type: str
    user: UserResponse


@router.post("/login", response_model=TokenResponse, summary="Iniciar sesión")
def login(request: LoginRequest, db: Session = Depends(get_db)):
    user = authenticate_user(db, request.email, request.password)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Credenciales inválidas")
    import uuid
    sid = uuid.uuid4().hex
    # create session record
    from models.core import Sesion
    ses = Sesion(token_sesion=sid, dispositivo=None, ip_usuario=None, estado_sesion='active', id_usuario=user.id_usuario)
    db.add(ses)
    db.commit()
    db.refresh(ses)

    access = create_access_token(subject=user.correo, sid=sid)
    refresh = create_refresh_token(subject=user.correo, sid=sid)
    return {"access_token": access, "refresh_token": refresh, "token_type": "bearer", "user": user}


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


@router.post('/refresh', summary='Refresh access token')
def refresh_token(refresh_token: str, db: Session = Depends(get_db)):
    payload = None
    try:
        payload = decode_token(refresh_token)
    except Exception:
        raise HTTPException(status_code=401, detail='Token inválido')
    if not payload:
        raise HTTPException(status_code=401, detail='Token inválido')
    sub = payload.get('sub')
    sid = payload.get('sid')
    if not sub or not sid:
        raise HTTPException(status_code=401, detail='Token inválido')
    ses = db.query(Sesion).filter(Sesion.token_sesion == sid).first()
    if not ses or ses.estado_sesion != 'active':
        raise HTTPException(status_code=401, detail='Sesión revocada')
    # issue new access token including sid
    access = create_access_token(subject=sub)
    return {"access_token": access, "token_type": "bearer"}


@router.post('/logout_refresh', summary='Logout and revoke refresh token')
def logout_refresh(refresh_token: str, db: Session = Depends(get_db)):
    payload = decode_token(refresh_token)
    if not payload:
        raise HTTPException(status_code=401, detail='Token inválido')
    sid = payload.get('sid')
    if not sid:
        raise HTTPException(status_code=400, detail='Refresh token inválido')
    ses = db.query(Sesion).filter(Sesion.token_sesion == sid).first()
    if ses:
        ses.estado_sesion = 'revoked'
        db.commit()
    return {"message": "Sesión revocada"}
