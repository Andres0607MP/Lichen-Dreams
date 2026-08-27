from fastapi import APIRouter, HTTPException, status, Depends, Response
from pydantic import BaseModel, EmailStr, field_validator
from sqlalchemy import func
from typing import Optional, List
from datetime import datetime
from sqlalchemy.orm import Session, joinedload

from config.db import get_db
from models.core import Usuario, Role, Reporte, Sesion, Analisis, Notificacion, EspecieLiquen, ZonaAmbiental
from auth.auth_service import get_current_user
from auth.password_handler import hash_password
from models.validations import (
    EspecieLiquenCreate, EspecieLiquenUpdate, EspecieLiquenResponse,
    ZonaAmbientalCreate, ZonaAmbientalUpdate, ZonaAmbientalResponse,
)

router = APIRouter()


def verify_admin(current_user: Usuario = Depends(get_current_user)):
    """Verifica que el usuario actual sea administrador. Bloquea el acceso si no lo es."""
    if current_user.rol is None or current_user.rol.nombre_rol != 'admin':
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo administradores pueden acceder a este recurso"
        )
    return current_user


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

    @field_validator("password")
    @classmethod
    def validate_password_strength(cls, value: str) -> str:
        if len(value) < 6:
            raise ValueError("La contraseña debe tener al menos 6 caracteres")
        if not any(not ch.isalnum() for ch in value):
            raise ValueError("La contraseña debe incluir al menos un carácter especial")
        return value


class AdminUserUpdate(BaseModel):
    email: Optional[EmailStr] = None
    name: Optional[str] = None
    id_rol: Optional[int] = None
    estado_cuenta: Optional[str] = None
    active: Optional[bool] = None


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


class NotificationCreate(BaseModel):
    titulo: str
    mensaje: str
    tipo_notificacion: str = "system"
    destino: str
    id_usuario: Optional[int] = None


class NotificationCreateResponse(BaseModel):
    message: str
    count: int
    destino: str


@router.get("/users", response_model=List[AdminUserResponse], summary="Obtener todos los usuarios (Admin)")
def get_all_users(
    skip: int = 0,
    limit: int = 100,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db),
):
    """Lista todos los usuarios registrados (solo administradores)."""
    users = db.query(Usuario).filter(Usuario.estado_cuenta != 'eliminado').offset(skip).limit(limit).all()
    return users


@router.post("/users", response_model=AdminUserResponse, status_code=status.HTTP_201_CREATED, summary="Crear nuevo usuario (Admin)")
def create_user(
    request: AdminUserCreate,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db),
):
    """Crea un nuevo usuario (solo administradores)."""
    existing = db.query(Usuario).filter(Usuario.correo == request.email).first()
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Ya existe un usuario con ese correo")

    nuevo = Usuario(
        nombre=request.name,
        correo=request.email,
        contrasena=hash_password(request.password),
        estado_cuenta="active",
        id_rol=request.id_rol,
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
    db: Session = Depends(get_db),
):
    """Actualiza un usuario existente (solo administradores)."""
    user = db.query(Usuario).filter(Usuario.id_usuario == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado")

    estado_anterior = user.estado_cuenta

    if request.email is not None:
        user.correo = request.email
    if request.name is not None:
        user.nombre = request.name
    if request.id_rol is not None:
        user.id_rol = request.id_rol
    if request.estado_cuenta is not None:
        user.estado_cuenta = request.estado_cuenta
    if request.active is not None:
        user.estado_cuenta = 'active' if request.active else 'inactive'

    if estado_anterior == "active" and user.estado_cuenta != "active":
        db.query(Sesion).filter(
            Sesion.id_usuario == user.id_usuario,
            Sesion.estado_sesion == "active"
        ).update({Sesion.estado_sesion: "revoked"}, synchronize_session=False)

    db.commit()
    db.refresh(user)
    return user


@router.delete("/users/{user_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar usuario (Admin, soft delete)")
def delete_user(
    user_id: int,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db),
):
    """Elimina (soft delete) un usuario (solo administradores)."""
    user = db.query(Usuario).filter(Usuario.id_usuario == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado")

    if current_user.id_usuario == user_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="El administrador no puede eliminarse a sí mismo")

    user.estado_cuenta = "eliminado"
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/reports", response_model=List[ReportResponse], summary="Obtener informes (Admin)")
def get_reports(
    skip: int = 0,
    limit: int = 100,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db),
):
    """Lista los informes generados (solo administradores)."""
    reports = db.query(Reporte).offset(skip).limit(limit).all()
    return reports


@router.post("/reports", response_model=ReportResponse, status_code=status.HTTP_201_CREATED, summary="Generar nuevo informe (Admin)")
def create_report(
    request: ReportCreate,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db),
):
    """Crea un nuevo informe asociado al administrador que lo genera."""
    reporte = Reporte(
        titulo=request.titulo,
        descripcion=request.descripcion,
        tipo_reporte=request.tipo_reporte,
        id_usuario=current_user.id_usuario,
    )
    db.add(reporte)
    db.commit()
    db.refresh(reporte)
    return reporte


@router.get("/reports/{report_id}", response_model=ReportResponse, summary="Obtener informe por ID (Admin)")
def get_report(
    report_id: int,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db),
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
    db: Session = Depends(get_db),
):
    """Elimina un informe (solo administradores)."""
    reporte = db.query(Reporte).filter(Reporte.id_reporte == report_id).first()
    if not reporte:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Informe no encontrado")
    db.delete(reporte)
    db.commit()
    return None


@router.post("/notifications", response_model=NotificationCreateResponse, status_code=status.HTTP_201_CREATED, summary="Crear notificación de sistema (Admin)")
def create_notification(
    request: NotificationCreate,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db),
):
    """Crea notificaciones de sistema para uno o todos los usuarios."""
    if request.destino == "user":
        if request.id_usuario is None:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="id_usuario es requerido cuando destino es 'user'")
        user = db.query(Usuario).filter(Usuario.id_usuario == request.id_usuario).first()
        if not user:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado")
        notif = Notificacion(
            id_usuario=request.id_usuario,
            titulo=request.titulo,
            mensaje=request.mensaje,
            tipo_notificacion=request.tipo_notificacion,
            estado_notificacion="pendiente",
        )
        db.add(notif)
        db.commit()
        db.refresh(notif)
        return NotificationCreateResponse(
            message="Notificación creada correctamente",
            count=1,
            destino="user",
        )
    elif request.destino == "all":
        users = db.query(Usuario).filter(Usuario.estado_cuenta != 'eliminado').all()
        for user in users:
            notif = Notificacion(
                id_usuario=user.id_usuario,
                titulo=request.titulo,
                mensaje=request.mensaje,
                tipo_notificacion=request.tipo_notificacion,
                estado_notificacion="pendiente",
            )
            db.add(notif)
        db.commit()
        return NotificationCreateResponse(
            message="Notificaciones creadas correctamente",
            count=len(users),
            destino="all",
        )
    raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="destino debe ser 'user' o 'all'")


# ---------- Reportes ----------

# ---------- Especies de Líquenes ----------

@router.get("/species", response_model=List[EspecieLiquenResponse], summary="Obtener todas las especies (Admin)")
def get_species(
    skip: int = 0,
    limit: int = 100,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db),
):
    """Lista todas las especies de líquenes (solo administradores)."""
    species = db.query(EspecieLiquen).order_by(EspecieLiquen.nombre_cientifico).offset(skip).limit(limit).all()
    return species


@router.post("/species", response_model=EspecieLiquenResponse, status_code=status.HTTP_201_CREATED, summary="Crear nueva especie (Admin)")
def create_species(
    request: EspecieLiquenCreate,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db),
):
    """Crea una nueva especie de líquen (solo administradores)."""
    nombre = request.nombre_cientifico
    duplicada = (
        db.query(EspecieLiquen)
        .filter(func.lower(EspecieLiquen.nombre_cientifico) == nombre.lower())
        .first()
    )
    if duplicada:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Ya existe una especie con el nombre científico '{nombre}'"
        )

    especie = EspecieLiquen(
        nombre_cientifico=nombre,
        nombre_comun=request.nombre_comun,
        descripcion=request.descripcion,
        color_predominante=request.color_predominante,
        tipo_crecimiento=request.tipo_crecimiento,
        nivel_tolerancia_contaminacion=request.nivel_tolerancia_contaminacion,
        indicador_calidad_aire=request.indicador_calidad_aire,
        habitat=request.habitat,
        imagen_referencia=request.imagen_referencia,
    )
    db.add(especie)
    db.commit()
    db.refresh(especie)
    return especie


@router.put("/species/{species_id}", response_model=EspecieLiquenResponse, summary="Actualizar especie (Admin)")
def update_species(
    species_id: int,
    request: EspecieLiquenUpdate,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db),
):
    """Actualiza una especie de líquen existente (solo administradores)."""
    especie = db.query(EspecieLiquen).filter(EspecieLiquen.id_especie == species_id).first()
    if not especie:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Especie no encontrada")

    campos_opcionales = (
        'nombre_comun',
        'descripcion',
        'color_predominante',
        'tipo_crecimiento',
        'nivel_tolerancia_contaminacion',
        'indicador_calidad_aire',
        'habitat',
        'imagen_referencia',
    )
    for campo in campos_opcionales:
        if campo in request.model_fields_set:
            setattr(especie, campo, getattr(request, campo))

    if 'nombre_cientifico' in request.model_fields_set:
        nuevo_nombre = request.nombre_cientifico
        duplicada = (
            db.query(EspecieLiquen)
            .filter(
                func.lower(EspecieLiquen.nombre_cientifico) == nuevo_nombre.lower(),
                EspecieLiquen.id_especie != species_id,
            )
            .first()
        )
        if duplicada:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Ya existe una especie con el nombre científico '{nuevo_nombre}'"
            )
        especie.nombre_cientifico = nuevo_nombre

    db.commit()
    db.refresh(especie)
    return especie


@router.delete("/species/{species_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar especie (Admin)")
def delete_species(
    species_id: int,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db),
):
    """Elimina una especie de líquen si no está siendo usada en análisis (solo administradores)."""
    especie = db.query(EspecieLiquen).filter(EspecieLiquen.id_especie == species_id).first()
    if not especie:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Especie no encontrada")

    analisis_count = db.query(Analisis).filter(Analisis.id_especie == species_id).count()
    if analisis_count > 0:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"No se puede eliminar: la especie está siendo usada en {analisis_count} análisis"
        )

    db.delete(especie)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


# ---------- Zonas Ambientales ----------

@router.get("/zones", response_model=List[ZonaAmbientalResponse], summary="Obtener todas las zonas ambientales (Admin)")
def get_zones(
    skip: int = 0,
    limit: int = 100,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db),
):
    """Lista todas las zonas ambientales (solo administradores)."""
    zones = db.query(ZonaAmbiental).order_by(ZonaAmbiental.nombre_zona).offset(skip).limit(limit).all()
    return zones


@router.post("/zones", response_model=ZonaAmbientalResponse, status_code=status.HTTP_201_CREATED, summary="Crear nueva zona ambiental (Admin)")
def create_zone(
    request: ZonaAmbientalCreate,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db),
):
    """Crea una nueva zona ambiental (solo administradores)."""
    zona = ZonaAmbiental(
        nombre_zona=request.nombre_zona,
        nivel_riesgo=request.nivel_riesgo,
        calidad_promedio_aire=request.calidad_promedio_aire,
        descripcion=request.descripcion,
    )
    db.add(zona)
    db.commit()
    db.refresh(zona)
    return zona


@router.put("/zones/{zone_id}", response_model=ZonaAmbientalResponse, summary="Actualizar zona ambiental (Admin)")
def update_zone(
    zone_id: int,
    request: ZonaAmbientalUpdate,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db),
):
    """Actualiza una zona ambiental existente (solo administradores)."""
    zona = db.query(ZonaAmbiental).filter(ZonaAmbiental.id_zona == zone_id).first()
    if not zona:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Zona ambiental no encontrada")

    if request.nombre_zona is not None:
        zona.nombre_zona = request.nombre_zona
    if request.nivel_riesgo is not None:
        zona.nivel_riesgo = request.nivel_riesgo
    if request.calidad_promedio_aire is not None:
        zona.calidad_promedio_aire = request.calidad_promedio_aire
    if request.descripcion is not None:
        zona.descripcion = request.descripcion

    zona.fecha_actualizacion = datetime.utcnow()
    db.commit()
    db.refresh(zona)
    return zona


@router.delete("/zones/{zone_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar zona ambiental (Admin)")
def delete_zone(
    zone_id: int,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db),
):
    """Elimina una zona ambiental (solo administradores)."""
    zona = db.query(ZonaAmbiental).filter(ZonaAmbiental.id_zona == zone_id).first()
    if not zona:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Zona ambiental no encontrada")

    db.delete(zona)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
