from fastapi import APIRouter, status, UploadFile, File
from pydantic import BaseModel, Field
from typing import List
from datetime import datetime

from services.analysis_service import AnalysisService, MockAnalysisProvider

router = APIRouter()
analysis_service = AnalysisService(provider=MockAnalysisProvider())


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
