from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime
from sqlalchemy.orm import Session

from config.db import get_db
from models.core import Usuario, Role, Reporte
from auth.auth_service import get_current_user
from auth.password_handler import hash_password

router = APIRouter()


def verify_admin(current_user: Usuario = Depends(get_current_user)):
    """Verifica que el usuario actual sea administrador. Bloquea el acceso si no lo es."""
    if current_user.rol is None or current_user.rol.nombre_rol != 'admin':
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo administradores pueden acceder a este recurso"
        )
    return current_user


# ---------- Usuarios ----------

class AdminUserResponse(BaseModel):
    id_usuario: int
    correo: str
    nombre: str
    id_rol: Optional[int]
    estado_cuenta: Optional[str]
    fecha_registro: datetime

    class Config:
        from_attributes = True


class AdminUserCreate(BaseModel):
    email: EmailStr
    name: str
    password: str
    id_rol: Optional[int] = None


class AdminUserUpdate(BaseModel):
    email: Optional[EmailStr] = None
    name: Optional[str] = None
    id_rol: Optional[int] = None
    estado_cuenta: Optional[str] = None


@router.get("/users", response_model=List[AdminUserResponse], summary="Obtener todos los usuarios (Admin)")
def get_all_users(
    skip: int = 0,
    limit: int = 100,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db)
):
    """Lista todos los usuarios registrados (solo administradores)."""
    users = db.query(Usuario).offset(skip).limit(limit).all()
    return users


@router.post("/users", response_model=AdminUserResponse, status_code=status.HTTP_201_CREATED, summary="Crear nuevo usuario (Admin)")
def create_user(
    request: AdminUserCreate,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db)
):
    """Crea un nuevo usuario (solo administradores)."""
    existing = db.query(Usuario).filter(Usuario.correo == request.email).first()
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Ya existe un usuario con ese correo")

    nuevo = Usuario(
        nombre=request.name,
        correo=request.email,
        contraseña=hash_password(request.password),
        estado_cuenta="activo",
        id_rol=request.id_rol
    )
    db.add(nuevo)
    db.commit()
    db.refresh(nuevo)
    return nuevo


@router.put("/users/{user_id}", response_model=AdminUserResponse, summary="Actualizar usuario (Admin)")
def update_user(
    user_id: int,
    request: AdminUserUpdate,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db)
):
    """Actualiza un usuario existente (solo administradores)."""
    user = db.query(Usuario).filter(Usuario.id_usuario == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado")

    if request.email is not None:
        user.correo = request.email
    if request.name is not None:
        user.nombre = request.name
    if request.id_rol is not None:
        user.id_rol = request.id_rol
    if request.estado_cuenta is not None:
        user.estado_cuenta = request.estado_cuenta

    db.commit()
    db.refresh(user)
    return user


@router.delete("/users/{user_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar usuario (Admin, soft delete)")
def delete_user(
    user_id: int,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db)
):
    """Elimina (soft delete) un usuario (solo administradores)."""
    user = db.query(Usuario).filter(Usuario.id_usuario == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado")

    user.estado_cuenta = "eliminado"
    db.commit()
    return None


# ---------- Reportes ----------

class ReportResponse(BaseModel):
    id_reporte: int
    titulo: str
    descripcion: Optional[str]
    tipo_reporte: Optional[str]
    fecha_generacion: datetime
    id_usuario: Optional[int]

    class Config:
        from_attributes = True


class ReportCreate(BaseModel):
    titulo: str
    descripcion: Optional[str] = None
    tipo_reporte: Optional[str] = None


@router.get("/reports", response_model=List[ReportResponse], summary="Obtener informes (Admin)")
def get_reports(
    skip: int = 0,
    limit: int = 100,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db)
):
    """Lista los informes generados (solo administradores)."""
    reports = db.query(Reporte).offset(skip).limit(limit).all()
    return reports


@router.post("/reports", response_model=ReportResponse, status_code=status.HTTP_201_CREATED, summary="Generar nuevo informe (Admin)")
def create_report(
    request: ReportCreate,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db)
):
    """Crea un nuevo informe asociado al administrador que lo genera."""
    reporte = Reporte(
        titulo=request.titulo,
        descripcion=request.descripcion,
        tipo_reporte=request.tipo_reporte,
        id_usuario=current_user.id_usuario
    )
    db.add(reporte)
    db.commit()
    db.refresh(reporte)
    return reporte


@router.get("/reports/{report_id}", response_model=ReportResponse, summary="Obtener informe por ID (Admin)")
def get_report(
    report_id: int,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db)
):
    """Obtiene un informe específico por su ID (solo administradores)."""
    reporte = db.query(Reporte).filter(Reporte.id_reporte == report_id).first()
    if not reporte:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Informe no encontrado")
    return reporte


@router.delete("/reports/{report_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar informe (Admin)")
def delete_report(
    report_id: int,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db)
):
    """Elimina un informe (solo administradores)."""
    reporte = db.query(Reporte).filter(Reporte.id_reporte == report_id).first()
    if not reporte:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Informe no encontrado")
    db.delete(reporte)
    db.commit()
    return None
