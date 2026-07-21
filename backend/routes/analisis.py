from pathlib import Path
from datetime import datetime
from typing import List
import uuid

from fastapi import APIRouter, File, UploadFile, status, Request, Form, HTTPException, Depends
from pydantic import BaseModel, Field

from auth.auth_service import get_current_user
from models.core import Usuario
from services.analysis_service import AnalysisService

router = APIRouter()
analysis_service = AnalysisService()

# Configuración de upload: usar la misma carpeta `uploads` relativa al paquete backend
UPLOAD_DIR = Path(__file__).resolve().parent.parent / 'uploads'
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
ALLOWED_FORMATS = {"jpg", "jpeg", "png"}
MAX_FILE_SIZE = 50 * 1024 * 1024  # 50MB


class AnalysisBaseResponse(BaseModel):
    id: int
    id_usuario: int = 1
    url_imagen: str = ""    
    resultado: str = ""
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


@router.post("/upload", summary="Cargar imagen para análisis")
async def upload_image(file: UploadFile = File(...)):
    """
    Endpoint para subir una imagen de musgo/liquen
    - RF01: Usuario cargar imágenes
    """
    extension = (file.filename or '').split('.')[-1].lower()
    if extension not in ALLOWED_FORMATS:
        raise HTTPException(status_code=400, detail="Formato de imagen no soportado")

    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail="La imagen está vacía")
    if len(content) > MAX_FILE_SIZE:
        raise HTTPException(status_code=413, detail="Imagen demasiado grande")

    unique_name = f"{uuid.uuid4().hex}.{extension}"
    destination = UPLOAD_DIR / unique_name
    destination.write_bytes(content)

    return {
        "file_id": unique_name,
        "filename": file.filename,
        "size": len(content),
        "upload_time": datetime.now(),
        "url": f"/uploads/{unique_name}",
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
    id_modelo: int = Form(default=1),
    id_dataset: int | None = Form(default=None),
    id_usuario: int | None = Form(default=None),
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

    if file is not None:
        extension = (file.filename or '').split('.')[-1].lower()
        if extension not in ALLOWED_FORMATS:
            raise HTTPException(status_code=400, detail="Formato de imagen no soportado")

        content = await file.read()
        if not content:
            raise HTTPException(status_code=400, detail="La imagen está vacía")
        if len(content) > MAX_FILE_SIZE:
            raise HTTPException(status_code=413, detail="Imagen demasiado grande")

        unique_name = f"{uuid.uuid4().hex}.{extension}"
        destination = UPLOAD_DIR / unique_name
        destination.write_bytes(content)
        resolved_image_url = f"/uploads/{unique_name}"
    else:
        # Compatibilidad con clientes que envían JSON en lugar de multipart.
        try:
            body = await request.json()
        except Exception:
            body = None

        if isinstance(body, dict):
            resolved_image_url = body.get("image_url", resolved_image_url)
            resolved_modelo = int(body.get("id_modelo", resolved_modelo) or 1)
            resolved_dataset = body.get("id_dataset", resolved_dataset)
            resolved_usuario = int(body.get("id_usuario", resolved_usuario) or 1)

    if not resolved_image_url:
        raise HTTPException(status_code=422, detail="Debes enviar una imagen o image_url")

    return analysis_service.process_analysis(
        image_url=resolved_image_url,
        id_modelo=resolved_modelo,
        id_dataset=resolved_dataset,
        id_usuario=resolved_usuario,
    )


@router.get("/{analysis_id}/status", response_model=AnalysisStatusResponse, summary="Obtener estado del análisis")
def get_analysis_status(analysis_id: int):
    """
    Endpoint para obtener el estado de un análisis
    """
    return analysis_service.get_status(analysis_id=analysis_id)


@router.get("/{analysis_id}/humidity", response_model=HumidityResponse, summary="Obtener datos de humedad")
def get_humidity(analysis_id: int):
    """
    Endpoint para obtener información de humedad estimada
    - RF05: Sistema estimar humedad
    """
    payload = analysis_service.get_humidity(analysis_id=analysis_id)
    payload["ubicacion"] = "Bosque tropical"
    return payload


@router.get("/{analysis_id}/air-quality", response_model=AirQualityResponse, summary="Obtener calidad del aire")
def get_air_quality(analysis_id: int):
    """
    Endpoint para obtener información de calidad del aire
    - RF011: Sistema estimar aire
    """
    return analysis_service.get_air_quality(analysis_id=analysis_id)


@router.get("/{analysis_id}/recommendation", response_model=RecommendationResponse, summary="Obtener recomendación ecológica")
def get_recommendation(analysis_id: int):
    """
    Endpoint para obtener recomendaciones ambientales
    - RF012: Sistema generar recomendación ecológica
    """
    return analysis_service.get_recommendation(analysis_id=analysis_id)


@router.get("/results/{analysis_id}", response_model=AnalysisResponse, summary="Obtener resultados completos")
def get_results(analysis_id: int):
    """
    Endpoint para obtener resultados completos del análisis
    - RF09: Usuario consultar resultados
    """
    return analysis_service.get_results(analysis_id=analysis_id)


@router.get("/{analysis_id}", response_model=AnalysisResponse, summary="Obtener análisis por ID")
def get_analysis(analysis_id: int):
    """
    Endpoint para obtener un análisis específico
    """
    return analysis_service.get_analysis(analysis_id=analysis_id)


@router.delete("/{analysis_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar análisis")
def delete_analysis(analysis_id: int):
    """
    Endpoint para eliminar un análisis
    """
    return None
