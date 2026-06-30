from fastapi import APIRouter, HTTPException, status, UploadFile, File, Depends
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from sqlalchemy.orm import Session

from config.db import get_db
from models.core import Analisis, Usuario, Imagen
from auth.auth_service import get_current_user

router = APIRouter()


class AnalysisResponse(BaseModel):
    id: int
    user_id: int
    image_url: str
    lichen_detected: bool
    confidence: float
    state: str
    humidity: float
    air_quality: str
    recommendation: str
    created_at: datetime


class ProcessRequest(BaseModel):
    image_url: str
    id_modelo: int
    id_dataset: Optional[int] = None


class HumidityResponse(BaseModel):
    id: int
    humidity_level: float
    timestamp: datetime
    location: str


class AirQualityResponse(BaseModel):
    id: int
    air_quality_index: float
    pollutants: dict
    timestamp: datetime


class RecommendationResponse(BaseModel):
    id: int
    recommendation: str
    priority: str
    actions: List[str]


@router.post("/upload", summary="Cargar imagen para análisis")
async def upload_image(file: UploadFile = File(...)):
    return {
        "file_id": "file_123",
        "filename": file.filename,
        "size": file.size,
        "upload_time": datetime.now()
    }


@router.post("/detect-lichen", summary="Detectar si es liquen")
async def detect_lichen(request: ProcessRequest):
    return {
        "image_url": request.image_url,
        "is_lichen": True,
        "confidence": 0.95,
        "organism_type": "lichen"
    }


@router.post(
    "/process",
    response_model=AnalysisResponse,
    summary="Procesar imagen con IA"
)
def process_analysis(
    request: ProcessRequest,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):

    nuevo_analisis = Analisis(
        id_usuario=current_user.id_usuario,
        id_modelo=request.id_modelo,
        id_dataset=request.id_dataset,
        resultado="Análisis procesado",
        estado="completed",

        metadata_resultado={
            "image_url": request.image_url,
            "lichen_detected": True,
            "confidence": 0.92,
            "humidity": 65.5,
            "air_quality": "moderate",
            "recommendation": "Buena calidad de aire en zona"
        }
    )

    db.add(nuevo_analisis)
    db.commit()
    db.refresh(nuevo_analisis)

    imagen = Imagen(
        url=request.image_url,
        id_analisis=nuevo_analisis.id_analisis
    )

    db.add(imagen)
    db.commit()

    data = nuevo_analisis.metadata_resultado

    return {
        "id": nuevo_analisis.id_analisis,
        "user_id": nuevo_analisis.id_usuario,
        "image_url": data["image_url"],
        "lichen_detected": data["lichen_detected"],
        "confidence": data["confidence"],
        "state": nuevo_analisis.estado,
        "humidity": data["humidity"],
        "air_quality": data["air_quality"],
        "recommendation": data["recommendation"],
        "created_at": nuevo_analisis.fecha_creacion
    }


@router.get(
    "/{analysis_id}/status",
    summary="Obtener estado del análisis"
)
def get_analysis_status(
    analysis_id: int,
    db: Session = Depends(get_db)
):

    analisis = db.query(Analisis).filter(
        Analisis.id_analisis == analysis_id
    ).first()

    if not analisis:
        raise HTTPException(
            status_code=404,
            detail="Análisis no encontrado"
        )

    return {
        "id": analisis.id_analisis,
        "status": analisis.estado,
        "progress": 100
    }


@router.get(
    "/{analysis_id}/humidity",
    response_model=HumidityResponse,
    summary="Obtener datos de humedad"
)
def get_humidity(
    analysis_id: int,
    db: Session = Depends(get_db)
):

    analisis = db.query(Analisis).filter(
        Analisis.id_analisis == analysis_id
    ).first()

    if not analisis:
        raise HTTPException(
            status_code=404,
            detail="Análisis no encontrado"
        )

    data = analisis.metadata_resultado

    return {
        "id": analisis.id_analisis,
        "humidity_level": data["humidity"],
        "timestamp": analisis.fecha_creacion,
        "location": "Zona registrada"
    }


@router.get(
    "/{analysis_id}/air-quality",
    response_model=AirQualityResponse,
    summary="Obtener calidad del aire"
)
def get_air_quality(
    analysis_id: int,
    db: Session = Depends(get_db)
):

    analisis = db.query(Analisis).filter(
        Analisis.id_analisis == analysis_id
    ).first()

    if not analisis:
        raise HTTPException(
            status_code=404,
            detail="Análisis no encontrado"
        )

    return {
        "id": analisis.id_analisis,
        "air_quality_index": 45.2,
        "pollutants": {
            "PM2.5": 12.3,
            "PM10": 25.5,
            "NO2": 15.0
        },
        "timestamp": analisis.fecha_creacion
    }


@router.get(
    "/{analysis_id}/recommendation",
    response_model=RecommendationResponse,
    summary="Obtener recomendación ecológica"
)
def get_recommendation(
    analysis_id: int,
    db: Session = Depends(get_db)
):

    analisis = db.query(Analisis).filter(
        Analisis.id_analisis == analysis_id
    ).first()

    if not analisis:
        raise HTTPException(
            status_code=404,
            detail="Análisis no encontrado"
        )

    data = analisis.metadata_resultado

    return {
        "id": analisis.id_analisis,
        "recommendation": data["recommendation"],
        "priority": "high",
        "actions": [
            "Plantar árboles nativos",
            "Reducir contaminación",
            "Proteger ecosistema"
        ]
    }


@router.get(
    "/results/{analysis_id}",
    response_model=AnalysisResponse,
    summary="Obtener resultados completos"
)
def get_results(
    analysis_id: int,
    db: Session = Depends(get_db)
):

    analisis = db.query(Analisis).filter(
        Analisis.id_analisis == analysis_id
    ).first()

    if not analisis:
        raise HTTPException(
            status_code=404,
            detail="Análisis no encontrado"
        )

    data = analisis.metadata_resultado

    return {
        "id": analisis.id_analisis,
        "user_id": analisis.id_usuario,
        "image_url": data["image_url"],
        "lichen_detected": data["lichen_detected"],
        "confidence": data["confidence"],
        "state": analisis.estado,
        "humidity": data["humidity"],
        "air_quality": data["air_quality"],
        "recommendation": data["recommendation"],
        "created_at": analisis.fecha_creacion
    }


@router.get(
    "/{analysis_id}",
    response_model=AnalysisResponse,
    summary="Obtener análisis por ID"
)
def get_analysis(
    analysis_id: int,
    db: Session = Depends(get_db)
):

    analisis = db.query(Analisis).filter(
        Analisis.id_analisis == analysis_id
    ).first()

    if not analisis:
        raise HTTPException(
            status_code=404,
            detail="Análisis no encontrado"
        )

    data = analisis.metadata_resultado

    return {
        "id": analisis.id_analisis,
        "user_id": analisis.id_usuario,
        "image_url": data["image_url"],
        "lichen_detected": data["lichen_detected"],
        "confidence": data["confidence"],
        "state": analisis.estado,
        "humidity": data["humidity"],
        "air_quality": data["air_quality"],
        "recommendation": data["recommendation"],
        "created_at": analisis.fecha_creacion
    }


@router.delete(
    "/{analysis_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Eliminar análisis"
)
def delete_analysis(
    analysis_id: int,
    db: Session = Depends(get_db)
):

    analisis = db.query(Analisis).filter(
        Analisis.id_analisis == analysis_id
    ).first()

    if not analisis:
        raise HTTPException(
            status_code=404,
            detail="Análisis no encontrado"
        )

    db.delete(analisis)
    db.commit()

    return None