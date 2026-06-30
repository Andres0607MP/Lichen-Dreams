from fastapi import APIRouter, status, UploadFile, File
from pydantic import BaseModel, Field
from typing import List
from datetime import datetime

from services.analysis_service import AnalysisService, MockAnalysisProvider

router = APIRouter()

# Configuración de upload
UPLOAD_DIR = Path("backend/uploads")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
ALLOWED_FORMATS = {"jpg", "jpeg", "png"}
MAX_FILE_SIZE = 50 * 1024 * 1024  # 50MB


class AnalisisResponse(BaseModel):
    id_analisis: int
    id_usuario: int
    id_modelo: Optional[int]
    id_dataset: Optional[int]
    resultado: Optional[str]
    fecha: datetime

    class Config:
        orm_mode = True


class ImagenResponse(BaseModel):
    id_imagen: int
    id_analisis: int
    url: str
    descripcion: Optional[str]

    class Config:
        orm_mode = True


class AnalisisConImagenesResponse(AnalisisResponse):
    imagenes: List[ImagenResponse]


def verify_ownership_or_admin(analysis_id: int, current_user: Usuario = Depends(get_current_user), db: Session = Depends(get_db)):
    """Verifica que el usuario sea propietario del análisis o administrador"""
    analisis = db.query(Analisis).filter(Analisis.id_analisis == analysis_id).first()
    
    if not analisis:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Análisis no encontrado"
        )
    
    is_owner = analisis.id_usuario == current_user.id_usuario
    is_admin = current_user.rol and current_user.rol.nombre_rol == 'admin'
    
    if not (is_owner or is_admin):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para acceder a este análisis"
        )
    
    return analisis


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
def process_analysis(request: ProcessRequest):
    """
    Endpoint para analizar imagen con IA
    - RF03: Sistema analizar líquenes
    - RF10: Sistema procesar imagen con IA
    """
    return analysis_service.process_analysis(image_url=request.image_url)


@router.get("/{analysis_id}/status", response_model=AnalysisStatusResponse, summary="Obtener estado del análisis")
def get_analysis_status(analysis_id: int):
    """
    Endpoint para obtener el estado de un análisis
    """
    payload = analysis_service.get_status(analysis_id=analysis_id)
    payload.setdefault("id_usuario", 1)
    payload.setdefault("url_imagen", "https://example.com/image.jpg")
    payload.setdefault("resultado", "liquen saludable")
    payload.setdefault("humedad", 65.5)
    payload.setdefault("calidad_del_aire", "moderada")
    payload.setdefault("recomendacion", "Buena calidad de aire en la zona")
    payload.setdefault("fecha_creacion", datetime.now())
    return payload


@router.get("/{analysis_id}/humidity", response_model=HumidityResponse, summary="Obtener datos de humedad")
def get_humidity(analysis_id: int):
    """
    Endpoint para obtener información de humedad estimada
    - RF05: Sistema estimar humedad
    """
    payload = analysis_service.get_humidity(analysis_id=analysis_id)
    payload["ubicacion"] = "Bosque tropical"
    payload.setdefault("id_usuario", 1)
    payload.setdefault("url_imagen", "https://example.com/image.jpg")
    payload.setdefault("resultado", "liquen saludable")
    payload.setdefault("estado", "completado")
    payload.setdefault("humedad", 65.5)
    payload.setdefault("calidad_del_aire", "moderada")
    payload.setdefault("recomendacion", "Buena calidad de aire en la zona")
    payload.setdefault("fecha_creacion", datetime.now())
    return payload


@router.get("/{analysis_id}/air-quality", response_model=AirQualityResponse, summary="Obtener calidad del aire")
def get_air_quality(analysis_id: int):
    """
    Endpoint para obtener información de calidad del aire
    - RF011: Sistema estimar aire
    """
    payload = analysis_service.get_air_quality(analysis_id=analysis_id)
    payload.setdefault("id_usuario", 1)
    payload.setdefault("url_imagen", "https://example.com/image.jpg")
    payload.setdefault("resultado", "liquen saludable")
    payload.setdefault("estado", "completado")
    payload.setdefault("humedad", 65.5)
    payload.setdefault("calidad_del_aire", "moderada")
    payload.setdefault("recomendacion", "Buena calidad de aire en la zona")
    payload.setdefault("fecha_creacion", datetime.now())
    return payload


@router.get("/{analysis_id}/recommendation", response_model=RecommendationResponse, summary="Obtener recomendación ecológica")
def get_recommendation(analysis_id: int):
    """
    Endpoint para obtener recomendaciones ambientales
    - RF012: Sistema generar recomendación ecológica
    """
    payload = analysis_service.get_recommendation(analysis_id=analysis_id)
    payload.setdefault("id_usuario", 1)
    payload.setdefault("url_imagen", "https://example.com/image.jpg")
    payload.setdefault("resultado", "liquen saludable")
    payload.setdefault("estado", "completado")
    payload.setdefault("humedad", 65.5)
    payload.setdefault("calidad_del_aire", "moderada")
    payload.setdefault("recomendacion", "Aumentar cobertura vegetal en zona")
    payload.setdefault("fecha_creacion", datetime.now())
    return payload


@router.get("/results/{analysis_id}", response_model=AnalysisResponse, summary="Obtener resultados completos")
def get_results(analysis_id: int):
    """
    Endpoint para obtener resultados completos del análisis
    - RF09: Usuario consultar resultados
    """
    payload = analysis_service.process_analysis(image_url="https://example.com/image.jpg")
    payload["id"] = analysis_id
    return payload


@router.get("/{analysis_id}", response_model=AnalysisResponse, summary="Obtener análisis por ID")
def get_analysis(analysis_id: int):
    """
    Endpoint para obtener un análisis específico
    """
    payload = analysis_service.process_analysis(image_url="https://example.com/image.jpg")
    payload["id"] = analysis_id
    return payload


@router.delete("/{analysis_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar análisis")
def delete_analysis(analysis_id: int):
    """
    Endpoint para eliminar un análisis
    """
    return None
