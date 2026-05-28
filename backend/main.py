from fastapi import FastAPI
from dotenv import load_dotenv
import os
from config.database import engine
from auth.jwt_handler import create_token
from passlib.context import CryptContext
from pydantic import BaseModel, Field

load_dotenv()

app = FastAPI()

try:
    from routes.test_route import router
    app.include_router(router)
except ImportError:
    print("Warning: routes.test_route not found")

DB_HOST = os.getenv("DB_HOST")
JWT_SECRET = os.getenv("JWT_SECRET")

@app.on_event("startup")
def startup():
    try:
        connection = engine.connect()
        print("Conexion exitosa a MySQL")
        connection.close()
    except Exception as e:
        print("Error de conexion:", e)

@app.get("/")
def root():
    return {
        "message": "Lichen Dreams API funcionando",
        "db_host": DB_HOST
    }

@app.get("/token")
def generate():
    token = create_token({"user": "admin"})
    return {"token": token}

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

class PasswordRequest(BaseModel):
    password: str = Field(..., min_length=1, max_length=72, description="Contraseña (máximo 72 caracteres)")

@app.post("/registro")
def registro(request: PasswordRequest):
    password = request.password[:72]
    hash_password = pwd_context.hash(password)

    return {
        "password_original": password,
        "password_hash": hash_password
    }
