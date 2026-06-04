from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime
from sqlalchemy.orm import Session

from config.db import get_db
from models.core import Usuario, Role
from auth.auth_service import require_admin
from auth.password_handler import hash_password

router = APIRouter()

class AdminUserResponse(BaseModel):
    id: int
    email: str
    name: str
    role: str
    active: bool
    created_at: datetime

class AdminUserCreate(BaseModel):
    email: EmailStr
    name: str
    password: str
    role: str

class AdminUserUpdate(BaseModel):
    email: Optional[str] = None
    name: Optional[str] = None
    role: Optional[str] = None
    active: Optional[bool] = None

class ReportResponse(BaseModel):
    id: int
    title: str
    description: str
    generated_by: str
    created_at: datetime
    status: str

class ReportCreate(BaseModel):
    title: str
    description: str
    filters: dict

# Users Management
@router.get("/users", response_model=List[AdminUserResponse], summary="Obtener todos los usuarios (Admin)")
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

# Reports Management
@router.get("/reports", response_model=List[ReportResponse], summary="Obtener informes (Admin)")
def get_reports():
    """
    Endpoint para obtener lista de informes generados
    - RF016: Administrador gestionar informes
    """
    return [
        {
            "id": 1,
            "title": "Informe de Análisis - Mayo 2026",
            "description": "Resumen de análisis realizados en el mes",
            "generated_by": "admin@example.com",
            "created_at": datetime.now(),
            "status": "completed"
        }
    ]

@router.post("/reports", response_model=ReportResponse, status_code=status.HTTP_201_CREATED, summary="Generar nuevo informe (Admin)")
def create_report(request: ReportCreate):
    """
    Endpoint para generar un nuevo informe
    - RF016: Administrador gestionar informes
    """
    return {
        "id": 1,
        "title": request.title,
        "description": request.description,
        "generated_by": "admin@example.com",
        "created_at": datetime.now(),
        "status": "processing"
    }

@router.get("/reports/{report_id}", response_model=ReportResponse, summary="Obtener informe por ID (Admin)")
def get_report(report_id: int):
    """
    Endpoint para obtener un informe específico
    - RF016: Administrador gestionar informes
    """
    return {
        "id": report_id,
        "title": "Informe de Análisis",
        "description": "Resumen detallado",
        "generated_by": "admin@example.com",
        "created_at": datetime.now(),
        "status": "completed"
    }

@router.delete("/reports/{report_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar informe (Admin)")
def delete_report(report_id: int):
    """
    Endpoint para eliminar un informe
    - RF016: Administrador gestionar informes
    """
    return None

@router.get("/reports/{report_id}/download", summary="Descargar informe (Admin)")
def download_report(report_id: int):
    """
    Endpoint para descargar un informe en formato PDF o similar
    - RF016: Administrador gestionar informes
    """
    return {
        "report_id": report_id,
        "download_url": f"https://example.com/reports/{report_id}/download",
        "filename": f"report_{report_id}.pdf",
        "timestamp": datetime.now()
    }
