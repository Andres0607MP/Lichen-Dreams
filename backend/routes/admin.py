from fastapi import APIRouter, HTTPException, status, Depends, Response
from pydantic import BaseModel, EmailStr, field_validator
from sqlalchemy import func
from typing import Optional, List
from datetime import datetime, timezone
from sqlalchemy.orm import Session, joinedload
import os
import logging
import boto3
from botocore.exceptions import ClientError

from config.db import get_db
from models.core import Usuario, Role, Reporte, Sesion, Analisis, Notificacion, EspecieLiquen, ZonaAmbiental, HistorialActividad, RecoveryCode, EmailVerificationToken, PasswordResetToken
from auth.auth_service import get_current_user
from auth.password_handler import hash_password
from services.zone_membership import sync_zone_to_analyses
from services.upload_service import delete_user_r2_objects
from services.push_service import send_to_token, clear_invalid_token, FcmResult, FcmSendResult
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
    rol: Optional[str] = None

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


class RoleResponse(BaseModel):
    id_rol: int
    nombre_rol: str
    descripcion: Optional[str] = None
    nivel_acceso: Optional[int] = None

    class Config:
        from_attributes = True


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


@router.get("/roles/admin", response_model=RoleResponse, summary="Obtener el rol admin")
def get_admin_role(
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db),
):
    """Devuelve el rol 'admin' para asignarlo a otros usuarios."""
    role = db.query(Role).filter(Role.nombre_rol == 'admin').first()
    if not role:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Rol admin no encontrado",
        )
    return role


@router.get("/roles/user", response_model=RoleResponse, summary="Obtener el rol usuario normal")
def get_user_role(
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db),
):
    """Devuelve el rol 'user' para asignarlo a otros usuarios."""
    role = db.query(Role).filter(Role.nombre_rol == 'user').first()
    if not role:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Rol usuario no encontrado",
        )
    return role


@router.get("/users", response_model=List[AdminUserResponse], summary="Obtener todos los usuarios (Admin)")
def get_all_users(
    skip: int = 0,
    limit: int = 100,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db),
):
    """Lista todos los usuarios registrados (solo administradores)."""
    users = (
        db.query(Usuario)
        .options(joinedload(Usuario.rol))
        .filter(
            Usuario.estado_cuenta != 'eliminado',
            Usuario.id_usuario != current_user.id_usuario,
        )
        .offset(skip)
        .limit(limit)
        .all()
    )
    return [
        AdminUserResponse(
            id_usuario=u.id_usuario,
            correo=u.correo,
            nombre=u.nombre,
            id_rol=u.id_rol,
            estado_cuenta=u.estado_cuenta,
            fecha_registro=u.fecha_registro,
            rol=u.rol.nombre_rol if u.rol else None,
        )
        for u in users
    ]


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
    return AdminUserResponse(
        id_usuario=nuevo.id_usuario,
        correo=nuevo.correo,
        nombre=nuevo.nombre,
        id_rol=nuevo.id_rol,
        estado_cuenta=nuevo.estado_cuenta,
        fecha_registro=nuevo.fecha_registro,
        rol=nuevo.rol.nombre_rol if nuevo.rol else None,
    )


@router.put("/users/{user_id}", response_model=AdminUserResponse, summary="Actualizar usuario (Admin)")
def update_user(
    user_id: int,
    request: AdminUserUpdate,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db),
):
    """Actualiza un usuario existente (solo administradores)."""
    user = (
        db.query(Usuario)
        .options(joinedload(Usuario.rol))
        .filter(Usuario.id_usuario == user_id)
        .first()
    )
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado")

    if current_user.id_usuario == user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El administrador no puede modificarse a sí mismo",
        )

    estado_anterior = user.estado_cuenta
    old_id_rol = user.id_rol

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

    if request.id_rol is not None and request.id_rol != old_id_rol:
        admin_role = db.query(Role).filter(Role.nombre_rol == "admin").first()
        admin_role_id = admin_role.id_rol if admin_role else None

        if admin_role_id is not None:
            es_admin = request.id_rol == admin_role_id
            mensaje = (
                "Tu cuenta ahora tiene permisos de administrador."
                if es_admin
                else "Tu cuenta ha sido cambiada a usuario normal."
            )
            notificacion = Notificacion(
                id_usuario=user.id_usuario,
                titulo="Cambio de rol",
                mensaje=mensaje,
                tipo_notificacion="system",
                estado_notificacion="pendiente",
                fecha=datetime.now(timezone.utc),
            )
            db.add(notificacion)

    db.commit()
    db.refresh(user)
    return AdminUserResponse(
        id_usuario=user.id_usuario,
        correo=user.correo,
        nombre=user.nombre,
        id_rol=user.id_rol,
        estado_cuenta=user.estado_cuenta,
        fecha_registro=user.fecha_registro,
        rol=user.rol.nombre_rol if user.rol else None,
    )


@router.delete("/users/{user_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar usuario (Admin, hard delete)")
def delete_user(
    user_id: int,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db),
):
    """Elimina definitivamente un usuario y todos sus datos asociados (solo administradores)."""
    user = db.query(Usuario).filter(Usuario.id_usuario == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado")

    if current_user.id_usuario == user_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="El administrador no puede eliminarse a sí mismo")

    # Eliminar objetos R2 asociados al usuario
    try:
        delete_user_r2_objects(user_id)
    except HTTPException:
        raise
    except Exception as e:
        import logging
        logging.warning(f"Error limpiando objetos R2 para usuario {user_id}: {e}")

    # Hard delete: borrar explícitamente todas las dependencias antes del usuario
    # (funciona en MySQL con ON DELETE CASCADE y en SQLite sin cascade nativo)
    db.query(RecoveryCode).filter(RecoveryCode.id_usuario == user_id).delete(synchronize_session=False)
    db.query(EmailVerificationToken).filter(EmailVerificationToken.id_usuario == user_id).delete(synchronize_session=False)
    db.query(PasswordResetToken).filter(PasswordResetToken.id_usuario == user_id).delete(synchronize_session=False)
    db.query(Notificacion).filter(Notificacion.id_usuario == user_id).delete(synchronize_session=False)
    db.query(Reporte).filter(Reporte.id_usuario == user_id).delete(synchronize_session=False)
    db.query(HistorialActividad).filter(HistorialActividad.id_usuario == user_id).delete(synchronize_session=False)
    # Analisis cascada borra imagenes, procesamiento_ia, analisis_zonas_ambientales
    db.query(Analisis).filter(Analisis.id_usuario == user_id).delete(synchronize_session=False)
    db.query(Sesion).filter(Sesion.id_usuario == user_id).delete(synchronize_session=False)

    # Finalmente borrar el usuario
    db.delete(user)
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


def _notify_user_via_fcm(db: Session, user_id: int, titulo: str, mensaje: str,
                         tipo_notificacion: str, destino: str,
                         extra_data: Optional[dict] = None) -> int:
    """Envía un push FCM a todas las sesiones activas con fcm_token de un usuario.

    Retorna la cantidad de notificaciones push enviadas exitosamente.
    Los tokens inválidos se limpian de la BD. Los errores no se propagan.
    """
    sessions = (
        db.query(Sesion)
        .filter(
            Sesion.id_usuario == user_id,
            Sesion.estado_sesion == "active",
            Sesion.fcm_token.isnot(None),
            Sesion.fcm_token != "",
        )
        .all()
    )
    if not sessions:
        return 0

    sent = 0
    data: dict[str, str] = {
        "titulo": titulo,
        "mensaje": mensaje,
        "tipo_notificacion": tipo_notificacion,
        "destino": destino,
        **(extra_data or {}),
    }

    for sesion in sessions:
        result = send_to_token(
            sesion.fcm_token,
            data=data,
            title=titulo,
            body=mensaje,
        )
        if result.result == FcmResult.ok:
            sent += 1
        elif result.result == FcmResult.invalid_token:
            clear_invalid_token(db, sesion.fcm_token)
        # failed/disabled se registran dentro de send_to_token, no se propagan

    return sent


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
            fecha=datetime.now(timezone.utc),
        )
        db.add(notif)
        db.commit()
        db.refresh(notif)
        try:
            _notify_user_via_fcm(
                db,
                user_id=request.id_usuario,
                titulo=request.titulo,
                mensaje=request.mensaje,
                tipo_notificacion=request.tipo_notificacion,
                destino="user",
                extra_data={"id_notificacion": str(notif.id_notificacion)},
            )
        except Exception as e:
            logger = logging.getLogger("lichdreams.notifications")
            logger.warning(f"[FCM] No se pudo enviar push FCM: {e}")
        return NotificationCreateResponse(
            message="Notificación creada correctamente",
            count=1,
            destino="user",
        )
    elif request.destino == "all":
        users = db.query(Usuario).filter(Usuario.estado_cuenta != 'eliminado').all()
        created_count = 0
        for user in users:
            notif = Notificacion(
                id_usuario=user.id_usuario,
                titulo=request.titulo,
                mensaje=request.mensaje,
                tipo_notificacion=request.tipo_notificacion,
                estado_notificacion="pendiente",
                fecha=datetime.now(timezone.utc),
            )
            db.add(notif)
            db.flush()
            created_count += 1
            try:
                _notify_user_via_fcm(
                    db,
                    user_id=user.id_usuario,
                    titulo=request.titulo,
                    mensaje=request.mensaje,
                    tipo_notificacion=request.tipo_notificacion,
                    destino="all",
                    extra_data={"id_notificacion": str(notif.id_notificacion)},
                )
            except Exception as e:
                logger = logging.getLogger("lichdreams.notifications")
                logger.warning(f"[FCM] No se pudo enviar push FCM al usuario {user.id_usuario}: {e}")
        db.commit()
        return NotificationCreateResponse(
            message="Notificaciones creadas correctamente",
            count=created_count,
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
        if not nuevo_nombre or not nuevo_nombre.strip():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="El nombre científico no puede estar vacío ni contener solo espacios"
            )
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

def _zona_to_dict(zona: ZonaAmbiental, db: Session) -> dict:
    """Serializa una zona con sus indicadores calculados (fuente de verdad)."""
    from services.zones_service import calculate_zone_indicators

    indicators = calculate_zone_indicators(db, zona)
    return {
        "id_zona": zona.id_zona,
        "nombre_zona": zona.nombre_zona,
        "latitud": float(zona.latitud) if zona.latitud is not None else None,
        "longitud": float(zona.longitud) if zona.longitud is not None else None,
        "radio_metros": zona.radio_metros,
        "nivel_riesgo": indicators["nivel_riesgo"],
        "calidad_promedio_aire": indicators["calidad_aire"],
        "total_analisis": indicators["total_analisis"],
        "saludables": indicators["liquidos_saludables"],
        "afectados": indicators["liquidos_afectados"],
        "desconocidos": indicators["liquidos_desconocidos"],
        "porcentaje_saludable": indicators["porcentaje_saludable"],
        "descripcion": zona.descripcion,
        "fecha_actualizacion": zona.fecha_actualizacion,
    }


@router.get("/zones", response_model=List[ZonaAmbientalResponse], summary="Obtener todas las zonas ambientales (Admin)")
def get_zones(
    skip: int = 0,
    limit: int = 100,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db),
):
    """Lista todas las zonas ambientales (solo administradores)."""
    zones = db.query(ZonaAmbiental).order_by(ZonaAmbiental.nombre_zona).offset(skip).limit(limit).all()
    return [_zona_to_dict(zona, db) for zona in zones]


@router.post("/zones", response_model=ZonaAmbientalResponse, status_code=status.HTTP_201_CREATED, summary="Crear nueva zona ambiental (Admin)")
def create_zone(
    request: ZonaAmbientalCreate,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db),
):
    """Crea una nueva zona ambiental (solo administradores).

    El administrador define nombre, centro (lat/lng), radio y descripción.
    La calidad y el riesgo NUNCA se introducen manualmente: se calculan a
    partir de los análisis reales dentro del radio.
    """
    zona = ZonaAmbiental(
        nombre_zona=request.nombre_zona,
        latitud=request.latitud,
        longitud=request.longitud,
        radio_metros=request.radio_metros,
        descripcion=request.descripcion,
        id_usuario_creador=current_user.id_usuario,
    )
    db.add(zona)
    db.commit()
    db.refresh(zona)
    # Asociar análisis existentes que caen dentro de la nueva zona
    sync_zone_to_analyses(db, zona.id_zona)
    db.commit()
    db.refresh(zona)
    return _zona_to_dict(zona, db)


@router.put("/zones/{zone_id}", response_model=ZonaAmbientalResponse, summary="Actualizar zona ambiental (Admin)")
def update_zone(
    zone_id: int,
    request: ZonaAmbientalUpdate,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db),
):
    """Actualiza la definición descriptiva/geográfica de una zona.

    nivel_riesgo y calidad_promedio_aire son valores calculados: no se aceptan
    desde el administrador y se refrescan con los análisis asociados.
    """
    zona = db.query(ZonaAmbiental).filter(ZonaAmbiental.id_zona == zone_id).first()
    if not zona:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Zona ambiental no encontrada")

    if request.nombre_zona is not None:
        zona.nombre_zona = request.nombre_zona
    if request.latitud is not None:
        zona.latitud = request.latitud
    if request.longitud is not None:
        zona.longitud = request.longitud
    if request.radio_metros is not None:
        zona.radio_metros = request.radio_metros
    if request.descripcion is not None:
        zona.descripcion = request.descripcion

    zona.fecha_actualizacion = datetime.utcnow()
    db.commit()

    # Re-sincronizar membresías si la geometría cambió
    geometry_changed = (
        request.latitud is not None
        or request.longitud is not None
        or request.radio_metros is not None
    )
    if geometry_changed:
        sync_zone_to_analyses(db, zona.id_zona)
        db.commit()

    db.refresh(zona)
    return _zona_to_dict(zona, db)


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


@router.get("/r2-diagnostic", summary="Diagnóstico temporal de conectividad Cloudflare R2 (Admin)")
def r2_diagnostic(
    current_user: Usuario = Depends(verify_admin),
):
    """
    Diagnóstico temporal de conectividad Cloudflare R2.
    Solo accesible por administradores autenticados.
    No expone secretos.
    """
    # Configuración (sin secretos)
    bucket = os.getenv("R2_BUCKET_NAME")
    endpoint = os.getenv("R2_ENDPOINT_URL")
    account = os.getenv("R2_ACCOUNT_ID")
    access_key = os.getenv("R2_ACCESS_KEY_ID")
    secret_key = os.getenv("R2_SECRET_ACCESS_KEY")

    # Ocultar Access Key
    ak_display = f"{access_key[:8]}..." if access_key else "None"

    result = {
        "config": {
            "bucket": bucket,
            "endpoint": endpoint,
            "account_id": account,
            "access_key_id": ak_display,
            "has_access_key": bool(access_key),
            "has_secret": bool(secret_key),
        },
        "tests": {}
    }

    if not all([bucket, endpoint, account, access_key, secret_key]):
        result["tests"]["config"] = {
            "status": "FAIL",
            "detail": "Variables R2 incompletas. Faltan: " +
            ", ".join(k for k, v in {
                "R2_BUCKET_NAME": bucket,
                "R2_ENDPOINT_URL": endpoint,
                "R2_ACCOUNT_ID": account,
                "R2_ACCESS_KEY_ID": access_key,
                "R2_SECRET_ACCESS_KEY": secret_key,
            }.items() if not v)
        }
        return result

    try:
        client = boto3.client(
            "s3",
            endpoint_url=endpoint,
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
        )

        # Test 1: head_bucket
        try:
            client.head_bucket(Bucket=bucket)
            result["tests"]["head_bucket"] = {
                "status": "OK",
                "detail": f"Bucket '{bucket}' accesible"
            }
        except ClientError as e:
            result["tests"]["head_bucket"] = {
                "status": "FAIL",
                "code": e.response["Error"]["Code"],
                "message": e.response["Error"]["Message"]
            }

        # Test 2: head_object (modelo)
        try:
            obj = client.head_object(Bucket=bucket, Key="models/lichen_model_v8.keras")
            result["tests"]["head_object_model"] = {
                "status": "OK",
                "size": obj["ContentLength"],
                "content_type": obj.get("ContentType")
            }
        except ClientError as e:
            result["tests"]["head_object_model"] = {
                "status": "FAIL",
                "code": e.response["Error"]["Code"],
                "message": e.response["Error"]["Message"]
            }

        # Test 3: head_object (class_mapping)
        try:
            obj = client.head_object(Bucket=bucket, Key="models/class_mapping_v8.json")
            result["tests"]["head_object_mapping"] = {
                "status": "OK",
                "size": obj["ContentLength"],
                "content_type": obj.get("ContentType")
            }
        except ClientError as e:
            result["tests"]["head_object_mapping"] = {
                "status": "FAIL",
                "code": e.response["Error"]["Code"],
                "message": e.response["Error"]["Message"]
            }

        # Test 4: list_objects_v2
        try:
            resp = client.list_objects_v2(Bucket=bucket, Prefix="models/")
            objects = [
                {"key": o["Key"], "size": o["Size"]}
                for o in resp.get("Contents", [])
            ]
            result["tests"]["list_objects"] = {
                "status": "OK",
                "count": len(objects),
                "objects": objects
            }
        except ClientError as e:
            result["tests"]["list_objects"] = {
                "status": "FAIL",
                "code": e.response["Error"]["Code"],
                "message": e.response["Error"]["Message"]
            }

    except Exception as e:
        result["tests"]["client"] = {
            "status": "ERROR",
            "detail": str(e)
        }

    return result
