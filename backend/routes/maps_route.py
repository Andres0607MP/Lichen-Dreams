from fastapi import APIRouter

from config.settings import GOOGLE_MAPS_API_KEY

router = APIRouter()


@router.get("/api/maps/test", summary="Probar configuración de Google Maps")
def maps_test():
    return {
        "latitud": 4.7110,
        "longitud": -74.0721,
        "estado": "Google Maps API configurada",
        "api_key_configurada": bool(GOOGLE_MAPS_API_KEY),
    }
