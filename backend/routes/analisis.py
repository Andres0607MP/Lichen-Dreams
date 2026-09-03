from datetime import datetime
from typing import List
import os
import logging

from fastapi import APIRouter, File, UploadFile, status, Request, Form, HTTPException, Depends
from sqlalchemy.orm import Session
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from auth.auth_service import get_current_user, get_current_user_optional
from models.core import Analisis, EspecieLiquen, Usuario, HistorialActividad, ProcesamientoIA, Notificacion, Imagen
from config.db import get_db, SessionLocal
from services.analysis_service import AnalysisService
from services.upload_service import (
    validate_image,
    save_file,
    resolve_file_path,
    IMAGE_TYPE_ANALYSIS,
)

router = APIRouter()
analysis_service = AnalysisService()

MAX_FILE_SIZE = 50 * 1024 * 1024  # 50MB


class AnalysisBaseResponse(BaseModel):
    id: int
    id_usuario: int
    url_imagen: str = ""
    resultado: str = ""
    categoria: str = ""
    confianza: float = 0.0
    nombre_especie: str | None = None
    id_especie: int | None = None
    especie_nombre_cientifico: str | None = None
    especie_nombre_comun: str | None = None
    estado: str = ""
    status: str = ""
    humedad: float = 0.0
    humidity: float = 0.0
    calidad_del_aire: str = ""
    air_quality: str = ""
    recomendacion: str = ""
    recommendation: str = ""
    imagen_base64: str | None = None
    image_base64: str | None = None
    fecha_creacion: datetime = Field(default_factory=datetime.now)
    rechazado: bool = False
    mensaje_rechazo: str | None = None


class AnalysisResponse(AnalysisBaseResponse):
    pass


class ProcessRequest(BaseModel):
    image_url: str
    id_modelo: int = 1
    id_dataset: int | None = None
    id_usuario: int | None = None


class AnalysisStatusResponse(AnalysisBaseResponse):
    progreso: int = 0


class HumidityResponse(AnalysisBaseResponse):
    ubicacion: str = ""


class AirQualityResponse(AnalysisBaseResponse):
    indice_calidad: float = 0.0
    contaminantes: dict = Field(default_factory=dict)


class RecommendationResponse(AnalysisBaseResponse):
    prioridad: str = ""
    acciones: List[str] = Field(default_factory=list)


@router.post("/upload", summary="Cargar imagen para análisis (requiere auth)")
async def upload_image(
    file: UploadFile = File(...),
    current_user: Usuario = Depends(get_current_user),
):
    """
    Endpoint para subir una imagen de musgo/liquen
    - RF01: Usuario cargar imágenes
    - La imagen se guarda en uploads/analyses/user_{id}/
    - Requiere autenticacion
    """
    content, ext = await validate_image(file)

    if len(content) > MAX_FILE_SIZE:
        raise HTTPException(status_code=413, detail="Imagen demasiado grande")

    url_path = save_file(
        content=content,
        extension=ext,
        image_type=IMAGE_TYPE_ANALYSIS,
        user_id=current_user.id_usuario,
    )

    return {
        "file_id": os.path.basename(url_path),
        "filename": file.filename,
        "size": len(content),
        "upload_time": datetime.now(),
        "url": url_path,
    }


@router.post("/detect-lichen", summary="Detectar si es liquen")
async def detect_lichen(request: ProcessRequest):
    """
    Endpoint para detectar si la imagen corresponde a un liquen
    - RF02: Sistema detectar organismo
    """
    if not request.image_url:
        raise HTTPException(status_code=422, detail="Debes enviar image_url")

    return {
        "image_url": request.image_url,
        "is_lichen": True,
        "confidence": 0.95,
        "organism_type": "lichen",
    }


@router.post("/process", response_model=AnalysisResponse, summary="Procesar imagen con IA")
async def process_analysis(
    request: Request,
    file: UploadFile | None = File(default=None),
    image_url: str | None = Form(default=None),
    id_modelo: int | None = Form(default=None),
    id_dataset: int | None = Form(default=None),
    id_ubicacion: int | None = Form(default=None),
    id_especie: int | None = Form(default=None),
    image_source: str | None = Form(default=None),
    current_user: Usuario = Depends(get_current_user),
):
    """
    Endpoint para analizar imagen con IA
    - RF03: Sistema analizar líquenes
    - RF10: Sistema procesar imagen con IA
    """
    resolved_image_url = image_url
    resolved_modelo = id_modelo
    resolved_dataset = id_dataset
    resolved_usuario = current_user.id_usuario
    resolved_ubicacion = id_ubicacion
    resolved_especie = id_especie
    resolved_image_source = image_source if image_source in ('camera', 'gallery') else 'upload'

    if file is not None:
        content, ext = await validate_image(file)

        if len(content) > MAX_FILE_SIZE:
            raise HTTPException(status_code=413, detail="Imagen demasiado grande")

        resolved_image_url = save_file(
            content=content,
            extension=ext,
            image_type=IMAGE_TYPE_ANALYSIS,
            user_id=resolved_usuario,
        )
    else:
        # Compatibilidad con clientes que envían JSON en lugar de multipart.
        try:
            body = await request.json()
        except Exception:
            body = None

        if isinstance(body, dict):
            resolved_image_url = body.get("image_url", resolved_image_url)
            resolved_modelo = int(body.get("id_modelo", resolved_modelo)) if body.get("id_modelo") is not None else resolved_modelo
            resolved_dataset = body.get("id_dataset", resolved_dataset)
            resolved_ubicacion = body.get("id_ubicacion", resolved_ubicacion)
            resolved_especie = body.get("id_especie", resolved_especie)

    if not resolved_image_url:
        raise HTTPException(status_code=422, detail="Debes enviar una imagen o image_url")

    if resolved_image_source == "camera" and resolved_ubicacion is None:
        raise HTTPException(
            status_code=422,
            detail="Los análisis desde cámara requieren una ubicación válida. Activa el GPS e intenta de nuevo.",
        )

    if resolved_especie is not None:
        db = SessionLocal()
        try:
            especie = db.query(EspecieLiquen).filter(
                EspecieLiquen.id_especie == resolved_especie
            ).first()
            if not especie:
                raise HTTPException(status_code=404, detail=f"Especie {resolved_especie} no encontrada")
        finally:
            db.close()

    return analysis_service.process_analysis(
        image_url=resolved_image_url,
        id_modelo=resolved_modelo,
        id_dataset=resolved_dataset,
        id_usuario=resolved_usuario,
        id_ubicacion=resolved_ubicacion,
        id_especie=resolved_especie,
        image_source=resolved_image_source,
    )


@router.get("/{analysis_id}/status", response_model=AnalysisStatusResponse, summary="Obtener estado del análisis")
def get_analysis_status(analysis_id: int, current_user: Usuario = Depends(get_current_user)):
    """
    Endpoint para obtener el estado de un análisis
    """
    user_id = current_user.id_usuario if current_user else None
    return analysis_service.get_status(analysis_id=analysis_id, user_id=user_id)


@router.get("/{analysis_id}/humidity", response_model=HumidityResponse, summary="Obtener datos de humedad")
def get_humidity(analysis_id: int, current_user: Usuario = Depends(get_current_user)):
    """
    Endpoint para obtener información de humedad estimada
    - RF05: Sistema estimar humedad
    """
    user_id = current_user.id_usuario if current_user else None
    payload = analysis_service.get_humidity(analysis_id=analysis_id, user_id=user_id)
    payload["ubicacion"] = "Bosque tropical"
    return payload


@router.get("/{analysis_id}/air-quality", response_model=AirQualityResponse, summary="Obtener calidad del aire")
def get_air_quality(analysis_id: int, current_user: Usuario = Depends(get_current_user)):
    """
    Endpoint para obtener información de calidad del aire
    - RF011: Sistema estimar aire
    """
    user_id = current_user.id_usuario if current_user else None
    return analysis_service.get_air_quality(analysis_id=analysis_id, user_id=user_id)


@router.get("/{analysis_id}/recommendation", response_model=RecommendationResponse, summary="Obtener recomendación ecológica")
def get_recommendation(analysis_id: int, current_user: Usuario = Depends(get_current_user)):
    """
    Endpoint para obtener recomendaciones ambientales
    - RF012: Sistema generar recomendación ecológica
    """
    user_id = current_user.id_usuario if current_user else None
    return analysis_service.get_recommendation(analysis_id=analysis_id, user_id=user_id)


@router.get("/my", response_model=List[dict], summary="Obtener análisis del usuario")
def get_my_analyses(
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Obtiene todos los análisis del usuario autenticado."""
    analyses = db.query(Analisis).filter(
        Analisis.id_usuario == current_user.id_usuario
    ).order_by(Analisis.fecha.desc()).all()

    return [
        {
            "id_analisis": a.id_analisis,
            "resultado_ia": a.resultado_ia,
            "visibilidad": a.visibilidad,
            "fecha_creacion": a.fecha.isoformat() if a.fecha else None,
            "confianza": a.porcentaje_confianza,
            "id_especie": a.id_especie,
            "especie_nombre_cientifico": a.especie.nombre_cientifico if a.especie else None,
            "especie_nombre_comun": a.especie.nombre_comun if a.especie else None,
        }
        for a in analyses
    ]


@router.get("/results/{analysis_id}", response_model=AnalysisResponse, summary="Obtener resultados completos")
def get_results(analysis_id: int, current_user: Usuario = Depends(get_current_user)):
    """
    Endpoint para obtener resultados completos del análisis
    - RF09: Usuario consultar resultados
    """
    user_id = current_user.id_usuario if current_user else None
    return analysis_service.get_results(analysis_id=analysis_id, user_id=user_id)


@router.get("/{analysis_id}", response_model=AnalysisResponse, summary="Obtener análisis por ID")
def get_analysis(analysis_id: int, current_user: Usuario = Depends(get_current_user)):
    """
    Endpoint para obtener un análisis específico
    """
    user_id = current_user.id_usuario if current_user else None
    return analysis_service.get_analysis(analysis_id=analysis_id, user_id=user_id)


@router.delete("/{analysis_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar análisis")
def delete_analysis(
    analysis_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """
    Elimina un análisis y todos sus recursos asociados.
    Solo el propietario del análisis o un administrador pueden eliminarlo.
    """
    analysis = db.query(Analisis).filter(
        Analisis.id_analisis == analysis_id
    ).first()

    if not analysis:
        raise HTTPException(
            status_code=404,
            detail="Análisis no encontrado"
        )

    is_owner = analysis.id_usuario == current_user.id_usuario
    is_admin = (
        current_user.rol
        and current_user.rol.nombre_rol == "admin"
    )

    if not is_owner and not is_admin:
        raise HTTPException(
            status_code=403,
            detail="No tienes permiso para eliminar este análisis"
        )

    try:
        # Eliminar historial asociado (busca por analysis_id en descripcion_accion)
        db.query(HistorialActividad).filter(
            HistorialActividad.id_usuario == analysis.id_usuario,
            HistorialActividad.descripcion_accion.like(f"%analysis_id={analysis_id};%")
        ).delete(synchronize_session=False)

        # Eliminar notificaciones asociadas a este análisis
        db.query(Notificacion).filter(
            Notificacion.id_usuario == analysis.id_usuario,
            Notificacion.tipo_notificacion == "analysis",
            Notificacion.mensaje.like(f"%analysis_id={analysis_id}|%")
        ).delete(synchronize_session=False)

        # Eliminar procesamiento IA asociado
        db.query(ProcesamientoIA).filter(
            ProcesamientoIA.id_analisis == analysis_id
        ).delete(synchronize_session=False)

        # Eliminar imágenes físicas y registros de imagen
        imagenes = db.query(Imagen).filter(Imagen.id_analisis == analysis_id).all()
        for imagen in imagenes:
            for path_attr in ['ruta_imagen', 'url']:
                path = getattr(imagen, path_attr, None)
                if path:
                    physical_path = resolve_file_path(path)
                    if physical_path and physical_path.exists():
                        try:
                            physical_path.unlink()
                        except OSError as e:
                            logging.warning(f"No se pudo eliminar archivo {physical_path}: {e}")
            db.delete(imagen)

        # Eliminar análisis
        db.delete(analysis)

        db.commit()
    except Exception as e:
        db.rollback()
        logging.error(f"Error al eliminar análisis {analysis_id}: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Error al eliminar el análisis: {str(e)}"
        )

    return None


@router.get("/{analysis_id}/species", response_model=dict, summary="Obtener especie asociada a un análisis")
def get_analysis_species(analysis_id: int, current_user: Usuario = Depends(get_current_user), db: Session = Depends(get_db)):
    """Devuelve la especie asociada manualmente a un análisis (si el usuario la seleccionó)."""
    analysis = db.query(Analisis).filter(Analisis.id_analisis == analysis_id).first()
    if not analysis:
        raise HTTPException(status_code=404, detail="Análisis no encontrado")
    if analysis.id_usuario != current_user.id_usuario:
        raise HTTPException(status_code=403, detail="No tienes acceso a este análisis")

    especie = analysis.especie
    if not especie:
        return {
            "id_analisis": analysis_id,
            "id_especie": None,
            "nombre_cientifico": None,
            "nombre_comun": None,
            "nivel_tolerancia_contaminacion": None,
            "indicador_calidad_aire": None,
        }

    return {
        "id_analisis": analysis_id,
        "id_especie": especie.id_especie,
        "nombre_cientifico": especie.nombre_cientifico,
        "nombre_comun": especie.nombre_comun,
        "nivel_tolerancia_contaminacion": especie.nivel_tolerancia_contaminacion,
        "indicador_calidad_aire": especie.indicador_calidad_aire,
    }


class SpeciesUpdateRequest(BaseModel):
    id_especie: int | None = None


@router.put("/{analysis_id}/species", response_model=dict, summary="Asociar o quitar especie de un análisis")
def update_analysis_species(
    analysis_id: int,
    request: SpeciesUpdateRequest,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Selección MANUAL del usuario: asocia (o quita) una especie del catálogo.

    La especie nunca es un resultado de la IA; esta operación solo persiste la
    elección del usuario (id_especie o NULL al omitir).
    """
    analysis = db.query(Analisis).filter(Analisis.id_analisis == analysis_id).first()
    if not analysis:
        raise HTTPException(status_code=404, detail="Análisis no encontrado")
    if analysis.id_usuario != current_user.id_usuario:
        raise HTTPException(status_code=403, detail="No tienes acceso a este análisis")

    if request.id_especie is not None:
        especie = db.query(EspecieLiquen).filter(
            EspecieLiquen.id_especie == request.id_especie
        ).first()
        if not especie:
            raise HTTPException(status_code=404, detail="Especie no encontrada")
        analysis.id_especie = especie.id_especie
    else:
        analysis.id_especie = None

    db.commit()
    return get_analysis_species(analysis_id, current_user, db)


@router.get("/{analysis_id}/location", response_model=dict, summary="Obtener ubicación de un análisis")
def get_analysis_location(analysis_id: int, current_user: Usuario = Depends(get_current_user), db: Session = Depends(get_db)):
    """Devuelve la ubicación geográfica asociada a un análisis."""
    analysis = db.query(Analisis).filter(Analisis.id_analisis == analysis_id).first()
    if not analysis:
        raise HTTPException(status_code=404, detail="Análisis no encontrado")
    if analysis.id_usuario != current_user.id_usuario:
        raise HTTPException(status_code=403, detail="No tienes acceso a este análisis")

    ubicacion = analysis.ubicacion
    if not ubicacion:
        return {
            "id_analisis": analysis_id,
            "latitud": None,
            "longitud": None,
            "direccion": None,
            "municipio": None,
            "departamento": None,
            "pais": None,
        }

    return {
        "id_analisis": analysis_id,
        "latitud": float(ubicacion.latitud) if ubicacion.latitud else None,
        "longitud": float(ubicacion.longitud) if ubicacion.longitud else None,
        "direccion": ubicacion.direccion,
        "municipio": ubicacion.municipio,
        "departamento": ubicacion.departamento,
        "pais": ubicacion.pais,
    }


@router.post("/{analysis_id}/share", response_model=dict, summary="Compartir análisis en el mapa")
def share_analysis(
    analysis_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    """Permite compartir un análisis para que aparezca en el mapa público."""
    analysis = db.query(Analisis).filter(Analisis.id_analisis == analysis_id).first()
    if not analysis:
        raise HTTPException(status_code=404, detail="Análisis no encontrado")

    is_owner = analysis.id_usuario == current_user.id_usuario
    is_admin = current_user.rol and current_user.rol.nombre_rol == "admin"
    if not is_owner and not is_admin:
        raise HTTPException(status_code=403, detail="No tienes permiso para compartir este análisis")

    analysis.visibilidad = "shared"
    db.commit()
    db.refresh(analysis)

    return {
        "id_analisis": analysis_id,
        "message": "Análisis compartido exitosamente en el mapa",
        "visibilidad": analysis.visibilidad,
    }


class VisibilityRequest(BaseModel):
    visibilidad: str


@router.put("/{analysis_id}/visibility", response_model=dict, summary="Cambiar visibilidad del análisis")
def update_visibility(
    analysis_id: int,
    request: VisibilityRequest,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    """Cambia la visibilidad de un análisis (private/shared)."""
    if request.visibilidad not in ("private", "shared"):
        raise HTTPException(status_code=400, detail="Visibilidad debe ser 'private' o 'shared'")

    analysis = db.query(Analisis).filter(Analisis.id_analisis == analysis_id).first()
    if not analysis:
        raise HTTPException(status_code=404, detail="Análisis no encontrado")

    if analysis.id_usuario != current_user.id_usuario:
        raise HTTPException(status_code=403, detail="No tienes permiso para modificar este análisis")

    analysis.visibilidad = request.visibilidad
    db.commit()
    db.refresh(analysis)

    return {
        "id_analisis": analysis_id,
        "visibilidad": analysis.visibilidad,
        "message": f"Visibilidad actualizada a {request.visibilidad}"
    }
