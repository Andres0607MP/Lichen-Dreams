from fastapi import APIRouter, Depends, File, Header, HTTPException, UploadFile, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime

from auth.auth_service import get_current_user
from config.db import get_db
from models.core import Usuario
from services.analysis_service import AnalysisService

router = APIRouter()
analysis_service = AnalysisService()


def optional_current_user(
    authorization: Optional[str] = Header(default=None),
    db: Session = Depends(get_db),
):
    if not authorization:
        return None
    token = authorization.replace("Bearer ", "", 1) if authorization.startswith("Bearer ") else authorization
    try:
        return get_current_user(token=token, db=db)
    except HTTPException:
        return None


class AnalysisBaseResponse(BaseModel):
    id: int
    id_usuario: int = 1
    url_imagen: str = ""
    resultado: str = ""
    estado: str = ""
    humedad: float = 0.0
    calidad_del_aire: str = ""
    recomendacion: str = ""
    fecha_creacion: datetime = Field(default_factory=datetime.now)


class AnalysisResponse(AnalysisBaseResponse):
    pass


class ProcessRequest(BaseModel):
    image_url: str


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


@router.post("/upload", summary="Cargar imagen para análisis")
async def upload_image(file: UploadFile = File(...)):
    """
    Endpoint para subir una imagen de musgo/liquen
    - RF01: Usuario cargar imágenes
    """
    return {
        "file_id": "file_123",
        "filename": file.filename,
        "size": file.size,
        "upload_time": datetime.now(),
    }


@router.post("/detect-lichen", summary="Detectar si es liquen")
async def detect_lichen(request: ProcessRequest):
    """
    Endpoint para detectar si la imagen corresponde a un liquen
    - RF02: Sistema detectar organismo
    """
    return {
        "image_url": request.image_url,
        "is_lichen": True,
        "confidence": 0.95,
        "organism_type": "lichen",
    }


@router.post("/process", response_model=AnalysisResponse, summary="Procesar imagen con IA")
def process_analysis(
    request: ProcessRequest,
    current_user: Optional[Usuario] = Depends(optional_current_user),
    db: Session = Depends(get_db),
):
    """
    Endpoint para analizar imagen con IA
    - RF03: Sistema analizar líquenes
    - RF10: Sistema procesar imagen con IA
    """
    current_user_id = current_user.id_usuario if current_user else 1
    return analysis_service.process(
        image_url=request.image_url,
        current_user_id=current_user_id,
        db=db,
    )


@router.get("/{analysis_id}/status", response_model=AnalysisStatusResponse, summary="Obtener estado del análisis")
def get_analysis_status(analysis_id: int, db: Session = Depends(get_db)):
    """
    Endpoint para obtener el estado de un análisis
    """
    payload = analysis_service.get_status(analysis_id=analysis_id, db=db)
    if not payload:
        raise HTTPException(status_code=404, detail="Análisis no encontrado")
    return payload


@router.get("/{analysis_id}/humidity", response_model=HumidityResponse, summary="Obtener datos de humedad")
def get_humidity(analysis_id: int, db: Session = Depends(get_db)):
    """
    Endpoint para obtener información de humedad estimada
    - RF05: Sistema estimar humedad
    """
    payload = analysis_service.get_humidity(analysis_id=analysis_id, db=db)
    if not payload:
        raise HTTPException(status_code=404, detail="Análisis no encontrado")
    return payload


@router.get("/{analysis_id}/air-quality", response_model=AirQualityResponse, summary="Obtener calidad del aire")
def get_air_quality(analysis_id: int, db: Session = Depends(get_db)):
    """
    Endpoint para obtener información de calidad del aire
    - RF011: Sistema estimar aire
    """
    payload = analysis_service.get_air_quality(analysis_id=analysis_id, db=db)
    if not payload:
        raise HTTPException(status_code=404, detail="Análisis no encontrado")
    return payload


@router.get("/{analysis_id}/recommendation", response_model=RecommendationResponse, summary="Obtener recomendación ecológica")
def get_recommendation(analysis_id: int, db: Session = Depends(get_db)):
    """
    Endpoint para obtener recomendaciones ambientales
    - RF012: Sistema generar recomendación ecológica
    """
    payload = analysis_service.get_recommendation(analysis_id=analysis_id, db=db)
    if not payload:
        raise HTTPException(status_code=404, detail="Análisis no encontrado")
    return payload


@router.get("/results/{analysis_id}", response_model=AnalysisResponse, summary="Obtener resultados completos")
def get_results(analysis_id: int, db: Session = Depends(get_db)):
    """
    Endpoint para obtener resultados completos del análisis
    - RF09: Usuario consultar resultados
    """
    payload = analysis_service.get_analysis_payload(analysis_id=analysis_id, db=db)
    if not payload:
        raise HTTPException(status_code=404, detail="Análisis no encontrado")
    return payload


@router.get("/{analysis_id}", response_model=AnalysisResponse, summary="Obtener análisis por ID")
def get_analysis(analysis_id: int, db: Session = Depends(get_db)):
    """
    Endpoint para obtener un análisis específico
    """
    payload = analysis_service.get_analysis_payload(analysis_id=analysis_id, db=db)
    if not payload:
        raise HTTPException(status_code=404, detail="Análisis no encontrado")
    return payload


@router.delete("/{analysis_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar análisis")
def delete_analysis(analysis_id: int, db: Session = Depends(get_db)):
    """
    Endpoint para eliminar un análisis
    """
    deleted = analysis_service.delete_analysis(analysis_id=analysis_id, db=db)
    if not deleted:
        raise HTTPException(status_code=404, detail="Análisis no encontrado")
    return None
