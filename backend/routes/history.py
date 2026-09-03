from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime
from sqlalchemy.orm import Session, joinedload as db_joinedload

from config.db import get_db
from models.core import Analisis, HistorialActividad, Usuario, ProcesamientoIA, Notificacion, Imagen
from auth.auth_service import get_current_user
from services.analysis_service import AnalysisService

analysis_service = AnalysisService()

router = APIRouter()


class HistoryResponse(BaseModel):
    id: int
    id_usuario: int
    id_analisis: int
    url_imagen: str = ""
    resultado: str = ""
    estado: str = ""
    estado_validacion: str = ""
    visibilidad: str = ""
    humedad: float = 0.0
    calidad_del_aire: str = ""
    recomendacion: str = ""
    ubicacion: str = ""
    fecha_creacion: datetime = Field(default_factory=datetime.now)


class HistorySaveRequest(BaseModel):
    analysis_id: int
    location: str
    accion: Optional[str] = "analisis_guardado"


def verify_admin(current_user: Usuario = Depends(get_current_user)):
    """Verifica que el usuario sea administrador."""
    if current_user.rol is None or current_user.rol.nombre_rol != 'admin':
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo administradores pueden acceder a este recurso"
        )
    return current_user


def _history_item_to_contract(item: HistorialActividad) -> HistoryResponse:
    analysis_id = 0
    location = ""
    if item.descripcion_accion:
        for part in item.descripcion_accion.split(";"):
            key_value = part.strip().split("=", 1)
            if len(key_value) == 2:
                key, value = key_value
                if key == "analysis_id":
                    try:
                        analysis_id = int(value)
                    except ValueError:
                        analysis_id = 0
                elif key == "location":
                    location = value
    analysis_data = {}
    if analysis_id:
        try:
            analysis_data = analysis_service.get_results(analysis_id)
        except Exception:
            analysis_data = {}

    # Ubicación: preferir la relación real Analisis -> Ubicacion. Solo si no
    # existe, usar el texto legacy `location=` (compatibilidad con historiales
    # antiguos). Esto independiza el historial del parser frágil de cadenas.
    if analysis_id:
        try:
            from config.db import SessionLocal
            from models.core import Analisis, Ubicacion
            with SessionLocal() as db:
                a = (
                    db.query(Analisis)
                    .options(db_joinedload(Analisis.ubicacion))
                    .filter(Analisis.id_analisis == analysis_id)
                    .first()
                )
                if a and a.ubicacion and a.ubicacion.latitud is not None:
                    ub = a.ubicacion
                    location = (
                        str(ub.direccion or "")
                        or str(ub.municipio or "")
                        or str(ub.departamento or "")
                        or f"{float(ub.latitud):.6f},{float(ub.longitud):.6f}"
                    )
        except Exception:
            pass

    return HistoryResponse(
        id=item.id_historial,
        id_usuario=item.id_usuario,
        id_analisis=analysis_id,
        url_imagen=analysis_data.get('imagen_url') or analysis_data.get('url_imagen') or analysis_data.get('image_url') or "",
        resultado=analysis_data.get('resultado') or "",
        estado=analysis_data.get('estado') or "",
        estado_validacion=analysis_data.get('estado_validacion') or "",
        visibilidad=analysis_data.get('visibilidad') or "",
        humedad=float(analysis_data.get('humedad') or 0.0),
        calidad_del_aire=analysis_data.get('calidad_del_aire') or "",
        recomendacion=analysis_data.get('recomendacion') or "",
        ubicacion=location,
        fecha_creacion=item.fecha or datetime.now(),
    )


@router.post("/save", response_model=HistoryResponse, status_code=status.HTTP_201_CREATED, summary="Guardar análisis en historial")
def save_history(
    request: HistorySaveRequest,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Guarda un análisis en el historial del usuario autenticado."""
    registro = HistorialActividad(
        accion_realizada=request.accion or "analisis_guardado",
        descripcion_accion=f"analysis_id={request.analysis_id}; location={request.location}",
        id_usuario=current_user.id_usuario,
    )
    db.add(registro)
    db.commit()
    db.refresh(registro)
    return _history_item_to_contract(registro)


@router.get("", response_model=List[HistoryResponse], summary="Obtener historial del usuario")
def get_history(
    skip: int = 0,
    limit: int = 100,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Obtiene el historial del usuario autenticado."""
    items = db.query(HistorialActividad).filter(
        HistorialActividad.id_usuario == current_user.id_usuario
    ).order_by(HistorialActividad.fecha.desc()).offset(skip).limit(limit).all()
    return [_history_item_to_contract(item) for item in items]


@router.get("/user/{user_id}", response_model=List[HistoryResponse], summary="Obtener historial de usuario específico (admin)")
def get_user_history(
    user_id: int,
    skip: int = 0,
    limit: int = 100,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db),
):
    """Obtiene el historial de un usuario específico (solo administradores)."""
    items = db.query(HistorialActividad).filter(
        HistorialActividad.id_usuario == user_id
    ).order_by(HistorialActividad.fecha.desc()).offset(skip).limit(limit).all()
    return [_history_item_to_contract(item) for item in items]


@router.delete("/{history_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar registro de historial")
def delete_history(
    history_id: int,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Elimina un registro del historial y su análisis asociado si existe."""
    registro = db.query(HistorialActividad).filter(
        HistorialActividad.id_historial == history_id
    ).first()

    if not registro:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Registro de historial no encontrado")

    is_owner = registro.id_usuario == current_user.id_usuario
    is_admin = current_user.rol is not None and current_user.rol.nombre_rol == 'admin'

    if not (is_owner or is_admin):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="No tienes permiso para eliminar este registro")

    # Extraer analysis_id del historial
    analysis_id = None
    if registro.descripcion_accion:
        for part in registro.descripcion_accion.split(";"):
            key_value = part.strip().split("=", 1)
            if len(key_value) == 2:
                key, value = key_value
                if key == "analysis_id":
                    try:
                        analysis_id = int(value)
                    except ValueError:
                        analysis_id = None
                    break

    try:
        # Eliminar historial
        db.delete(registro)

        # Si hay análisis asociado, eliminarlo también
        if analysis_id is not None:
            analysis = db.query(Analisis).filter(Analisis.id_analisis == analysis_id).first()
            if analysis:
                # Eliminar notificaciones asociadas
                db.query(Notificacion).filter(
                    Notificacion.id_usuario == analysis.id_usuario,
                    Notificacion.tipo_notificacion == "analysis",
                    Notificacion.mensaje.like(f"%analysis_id={analysis_id}|%")
                ).delete(synchronize_session=False)

                # Eliminar procesamiento IA
                db.query(ProcesamientoIA).filter(
                    ProcesamientoIA.id_analisis == analysis_id
                ).delete(synchronize_session=False)

                # Eliminar imágenes físicas y registros
                from services.upload_service import resolve_file_path
                imagenes = db.query(Imagen).filter(Imagen.id_analisis == analysis_id).all()
                for imagen in imagenes:
                    for path_attr in ['ruta_imagen', 'url']:
                        path = getattr(imagen, path_attr, None)
                        if path:
                            physical_path = resolve_file_path(path)
                            if physical_path and physical_path.exists():
                                try:
                                    physical_path.unlink()
                                except OSError:
                                    pass
                    db.delete(imagen)

                db.delete(analysis)

        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error al eliminar: {str(e)}")

    return None
