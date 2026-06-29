from datetime import datetime
from typing import Any, Dict, Optional


class MockAnalysisProvider:
    def generate_analysis(self, image_url: str) -> Dict[str, Any]:
        return {
            "id": 1,
            "id_usuario": 1,
            "url_imagen": image_url,
            "resultado": "liquen saludable",
            "estado": "completado",
            "humedad": 65.5,
            "calidad_del_aire": "moderada",
            "recomendacion": "Buena calidad de aire en la zona",
            "fecha_creacion": datetime.now(),
        }

    def generate_status(self, analysis_id: int) -> Dict[str, Any]:
        return {
            "id": analysis_id,
            "estado": "completado",
            "progreso": 100,
        }

    def generate_humidity(self, analysis_id: int) -> Dict[str, Any]:
        return {
            "id": analysis_id,
            "humedad": 65.5,
            "fecha_creacion": datetime.now(),
            "ubicacion": "Bosque tropical",
        }

    def generate_air_quality(self, analysis_id: int) -> Dict[str, Any]:
        return {
            "id": analysis_id,
            "calidad_del_aire": "moderada",
            "indice_calidad": 45.2,
            "contaminantes": {
                "PM2.5": 12.3,
                "PM10": 25.5,
                "NO2": 15.0,
            },
            "fecha_creacion": datetime.now(),
        }

    def generate_recommendation(self, analysis_id: int) -> Dict[str, Any]:
        return {
            "id": analysis_id,
            "recomendacion": "Aumentar cobertura vegetal en zona",
            "prioridad": "alta",
            "acciones": ["Plantar árboles nativos", "Reducir contaminación", "Proteger ecosistema"],
        }


class AnalysisService:
    def __init__(self, provider: Optional[object] = None):
        self.provider = provider or MockAnalysisProvider()

    def process_analysis(self, image_url: str) -> Dict[str, Any]:
        return self.provider.generate_analysis(image_url=image_url)

    def get_status(self, analysis_id: int) -> Dict[str, Any]:
        return self.provider.generate_status(analysis_id=analysis_id)

    def get_humidity(self, analysis_id: int) -> Dict[str, Any]:
        return self.provider.generate_humidity(analysis_id=analysis_id)

    def get_air_quality(self, analysis_id: int) -> Dict[str, Any]:
        return self.provider.generate_air_quality(analysis_id=analysis_id)

    def get_recommendation(self, analysis_id: int) -> Dict[str, Any]:
        return self.provider.generate_recommendation(analysis_id=analysis_id)
