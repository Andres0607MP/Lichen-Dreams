from fastapi import APIRouter

router = APIRouter()

@router.get("/api/test")
def test_connection():
    return {
        "message": "Conexion exitosa con FastAPI"
    }