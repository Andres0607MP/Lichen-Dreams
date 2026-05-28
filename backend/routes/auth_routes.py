from fastapi import APIRouter

router = APIRouter()

@router.post("/api/auth/login")
def login():

    return {
        "message": "Login exitoso"
    }
@router.post("/api/auth/register")
def register():

    return {
        "message": "Usuario registrado"
    }