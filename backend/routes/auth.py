from datetime import date
from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel, EmailStr
from typing import Optional
from sqlalchemy.orm import Session
from fastapi import Form
from config.db import get_db
from models.core import Usuario, Sesion, Role
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
    apellido: Optional[str] = None
    phone: Optional[str] = None
    tipo_documento: Optional[str] = None
    numero_documento: Optional[str] = None
    fecha_nacimiento: Optional[date] = None
    foto_perfil: Optional[str] = None


class UserResponse(BaseModel):
    id_usuario: int
    correo: str
    nombre: Optional[str]
    apellido: Optional[str] = None
    telefono: Optional[str] = None
    tipo_documento: Optional[str] = None
    numero_documento: Optional[str] = None
    fecha_nacimiento: Optional[date] = None
    foto_perfil: Optional[str] = None
    estado_cuenta: Optional[str] = None
    id_rol: Optional[int]
    rol: Optional[str]

    class Config:
        from_attributes = True


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str
    user: UserResponse


@router.post("/login", response_model=TokenResponse, summary="Iniciar sesión")
def login(request: Optional[LoginRequest] = None, email: Optional[str] = Form(None), password: Optional[str] = Form(None), db: Session = Depends(get_db)):
    if request is not None:
        email = request.email
        password = request.password
    if not email or not password:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="email y password son requeridos")

    user = authenticate_user(db, email, password)
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
    return {
        "access_token": access,
        "refresh_token": refresh,
        "token_type": "bearer",
        "user": {
            "id_usuario": user.id_usuario,
            "correo": user.correo,
            "nombre": user.nombre,
            "telefono": user.telefono,
            "id_rol": user.id_rol,
            "rol": user.rol.nombre_rol if user.rol else None,
        },
    }


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED, summary="Registrar nuevo usuario")
def register(request: RegisterRequest, db: Session = Depends(get_db)):
    existing = db.query(Usuario).filter(Usuario.correo == request.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="Usuario ya existe")
    user_role = db.query(Role).filter(Role.nombre_rol == 'user').first()
    if not user_role:
        user_role = Role(nombre_rol='user', descripcion='Usuario normal', nivel_acceso=1)
        db.add(user_role)
        db.commit()
        db.refresh(user_role)

    user = Usuario(
        nombre=request.name,
        apellido=request.apellido,
        correo=request.email,
        contrasena=hash_password(request.password),
        telefono=request.phone,
        tipo_documento=request.tipo_documento,
        numero_documento=request.numero_documento,
        fecha_nacimiento=request.fecha_nacimiento,
        foto_perfil=request.foto_perfil,
        estado_cuenta='active',
        id_rol=user_role.id_rol,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return {
        "id_usuario": user.id_usuario,
        "correo": user.correo,
        "nombre": user.nombre,
        "apellido": user.apellido,
        "telefono": user.telefono,
        "tipo_documento": user.tipo_documento,
        "numero_documento": user.numero_documento,
        "fecha_nacimiento": user.fecha_nacimiento.date() if user.fecha_nacimiento else None,
        "foto_perfil": user.foto_perfil,
        "estado_cuenta": user.estado_cuenta,
        "id_rol": user.id_rol,
        "rol": user_role.nombre_rol,
    }


@router.get("/me", response_model=UserResponse, summary="Obtener información del usuario actual")
def me(current_user: Usuario = Depends(get_current_user)):
    return {
        "id_usuario": current_user.id_usuario,
        "correo": current_user.correo,
        "nombre": current_user.nombre,
        "apellido": current_user.apellido,
        "telefono": current_user.telefono,
        "tipo_documento": current_user.tipo_documento,
        "numero_documento": current_user.numero_documento,
        "fecha_nacimiento": current_user.fecha_nacimiento.date() if current_user.fecha_nacimiento else None,
        "foto_perfil": current_user.foto_perfil,
        "estado_cuenta": current_user.estado_cuenta,
        "id_rol": current_user.id_rol,
        "rol": current_user.rol.nombre_rol if current_user.rol else None,
    }


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
