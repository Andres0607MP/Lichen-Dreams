from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime
from sqlalchemy.orm import Session

from config.db import get_db
<<<<<<< HEAD
from models.core import Usuario, Role, Reporte
from auth.auth_service import get_current_user
=======
from models.core import Usuario, Role
from auth.auth_service import require_admin
>>>>>>> 0e0c74949dcb5c2453167deb1457685af8cfd684
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
<<<<<<< HEAD
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
=======
def get_all_users(current_user: Usuario = Depends(require_admin), db: Session = Depends(get_db)):
    """
    Endpoint para que el administrador obtenga lista de todos los usuarios
    - RF015: Administrador gestionar usuarios
    """
    users = db.query(Usuario).all()
    return [
        {
            "id": user.id_usuario,
            "email": user.correo,
            "name": user.nombre or "Sin nombre",
            "role": user.rol.nombre_rol if user.rol else "user",
            "active": user.estado_cuenta == 'active',
            "created_at": user.fecha_registro or datetime.now()
        }
        for user in users
    ]

@router.post("/users", response_model=AdminUserResponse, status_code=status.HTTP_201_CREATED, summary="Crear nuevo usuario (Admin)")
def create_user(request: AdminUserCreate, current_user: Usuario = Depends(require_admin), db: Session = Depends(get_db)):
    """
    Endpoint para que el administrador cree un nuevo usuario
    - RF015: Administrador gestionar usuarios
    """
    # Verificar que el email no exista
    existing_user = db.query(Usuario).filter(Usuario.correo == request.email).first()
    if existing_user:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="El email ya está registrado")
    
    # Obtener el rol
    role = db.query(Role).filter(Role.nombre_rol == request.role).first()
    if not role:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Rol inválido")
    
    # Crear nuevo usuario
    new_user = Usuario(
        nombre=request.name,
        correo=request.email,
        contrasena=hash_password(request.password),
        estado_cuenta='active',
        id_rol=role.id_rol
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    return {
        "id": new_user.id_usuario,
        "email": new_user.correo,
        "name": new_user.nombre,
        "role": request.role,
        "active": True,
        "created_at": new_user.fecha_registro or datetime.now()
    }

@router.put("/users/{user_id}", response_model=AdminUserResponse, summary="Actualizar usuario (Admin)")
def update_user(user_id: int, request: AdminUserUpdate, current_user: Usuario = Depends(require_admin), db: Session = Depends(get_db)):
    """
    Endpoint para que el administrador actualice un usuario
    - RF015: Administrador gestionar usuarios
    """
    user = db.query(Usuario).filter(Usuario.id_usuario == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado")
    
    if request.email:
        existing_user = db.query(Usuario).filter(Usuario.correo == request.email, Usuario.id_usuario != user_id).first()
        if existing_user:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="El email ya está registrado")
        user.correo = request.email
    
    if request.name:
        user.nombre = request.name
    
    if request.role:
        role = db.query(Role).filter(Role.nombre_rol == request.role).first()
        if not role:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Rol inválido")
        user.id_rol = role.id_rol
    
    if request.active is not None:
        user.estado_cuenta = 'active' if request.active else 'inactive'
    
    db.commit()
    db.refresh(user)
    
    return {
        "id": user.id_usuario,
        "email": user.correo,
        "name": user.nombre,
        "role": user.rol.nombre_rol if user.rol else "user",
        "active": user.estado_cuenta == 'active',
        "created_at": user.fecha_registro or datetime.now()
    }

@router.delete("/users/{user_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar usuario (Admin)")
def delete_user(user_id: int, current_user: Usuario = Depends(require_admin), db: Session = Depends(get_db)):
    """
    Endpoint para que el administrador elimine un usuario
    - RF015: Administrador gestionar usuarios
    """
    try:
        if current_user.id_usuario == user_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, 
                detail="No puedes eliminar tu propia cuenta como administrador"
            )
        
        user = db.query(Usuario).filter(Usuario.id_usuario == user_id).first()
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, 
                detail=f"Usuario con ID {user_id} no encontrado"
            )
        
        # Eliminar sesiones del usuario
        from models.core import Sesion, Analisis
        db.query(Sesion).filter(Sesion.id_usuario == user_id).delete()
        
        # Eliminar análisis del usuario
        db.query(Analisis).filter(Analisis.id_usuario == user_id).delete()
        
        # Finalmente, eliminar el usuario
        db.delete(user)
        db.commit()
        return None
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al eliminar usuario: {str(e)}"
        )
>>>>>>> 0e0c74949dcb5c2453167deb1457685af8cfd684


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
