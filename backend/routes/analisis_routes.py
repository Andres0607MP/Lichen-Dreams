from fastapi import APIRouter

router = APIRouter()

@router.get("/api/analisis")
def obtener_analisis():

    return {
        "analisis": []
    }