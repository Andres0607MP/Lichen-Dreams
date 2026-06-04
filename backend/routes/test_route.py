from fastapi import APIRouter

router = APIRouter()


@router.get("/api/test", summary="Probar conexión con el backend")
def test_connection():
    return {"message": "Conexion exitosa con FastAPI"}
