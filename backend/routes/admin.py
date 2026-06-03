from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime

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
def get_all_users():
    """
    Endpoint para que el administrador obtenga lista de todos los usuarios
    - RF015: Administrador gestionar usuarios
    """
    return [
        {
            "id": 1,
            "email": "user1@example.com",
            "name": "Usuario 1",
            "role": "user",
            "active": True,
            "created_at": datetime.now()
        }
    ]

@router.post("/users", response_model=AdminUserResponse, status_code=status.HTTP_201_CREATED, summary="Crear nuevo usuario (Admin)")
def create_user(request: AdminUserCreate):
    """
    Endpoint para que el administrador cree un nuevo usuario
    - RF015: Administrador gestionar usuarios
    """
    return {
        "id": 1,
        "email": request.email,
        "name": request.name,
        "role": request.role,
        "active": True,
        "created_at": datetime.now()
    }

@router.put("/users/{user_id}", response_model=AdminUserResponse, summary="Actualizar usuario (Admin)")
def update_user(user_id: int, request: AdminUserUpdate):
    """
    Endpoint para que el administrador actualice un usuario
    - RF015: Administrador gestionar usuarios
    """
    return {
        "id": user_id,
        "email": request.email or "user@example.com",
        "name": request.name or "Usuario",
        "role": request.role or "user",
        "active": request.active if request.active is not None else True,
        "created_at": datetime.now()
    }

@router.delete("/users/{user_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar usuario (Admin)")
def delete_user(user_id: int):
    """
    Endpoint para que el administrador elimine un usuario
    - RF015: Administrador gestionar usuarios
    """
    return None

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
