from fastapi import APIRouter, Depends
from typing import List

from config.settings import GOOGLE_MAPS_API_KEY
from models.validations import MapPointResponse
from services.analysis_service import AnalysisService
from auth.auth_service import get_current_user
from models.core import Usuario

router = APIRouter()
analysis_service = AnalysisService()


@router.get("/test", summary="Probar configuración de Google Maps")
def maps_test():
    return {
        "latitud": 4.7110,
        "longitud": -74.0721,
        "estado": "Google Maps API configurada",
        "api_key_configurada": bool(GOOGLE_MAPS_API_KEY),
    }


@router.get("/points", response_model=List[MapPointResponse], summary="Obtener puntos ambientales para el mapa")
def get_map_points(current_user: Usuario = Depends(get_current_user)):
    return analysis_service.get_map_points(user_id=current_user.id_usuario)
