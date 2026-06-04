from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from dotenv import load_dotenv
import os
from config.database import engine
from auth.jwt_handler import create_access_token as create_token
from passlib.context import CryptContext
from pydantic import BaseModel, Field

load_dotenv()

app = FastAPI(title="Lichen Dreams API", version="1.0.0", description="API para análisis de líquenes")

# Ensure uploads directory exists and serve it
UPLOAD_DIR = os.path.join(os.path.dirname(__file__), 'uploads')
os.makedirs(UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

# Importar y registrar routers
try:
    from routes.auth import router as auth_router
    app.include_router(auth_router, prefix="/auth", tags=["Auth"])
except ImportError as e:
    print(f"Warning: auth router not found - {e}")

try:
    from routes.users import router as users_router
    app.include_router(users_router, prefix="/users", tags=["Users"])
except ImportError as e:
    print(f"Warning: users router not found - {e}")

try:
    from routes.analisis import router as analisis_router
    app.include_router(analisis_router, prefix="/analysis", tags=["Analysis"])
except ImportError as e:
    print(f"Warning: analisis router not found - {e}")

try:
    from routes.location import router as location_router
    app.include_router(location_router, prefix="/location", tags=["Location"])
except ImportError as e:
    print(f"Warning: location router not found - {e}")

try:
    from routes.history import router as history_router
    app.include_router(history_router, prefix="/history", tags=["History"])
except ImportError as e:
    print(f"Warning: history router not found - {e}")

try:
    from routes.admin import router as admin_router
    app.include_router(admin_router, prefix="/admin", tags=["Admin"])
except ImportError as e:
    print(f"Warning: admin router not found - {e}")

try:
    from routes.modelos import router as modelos_router
    app.include_router(modelos_router, prefix="/modelos", tags=["Modelos"])
except ImportError as e:
    print(f"Warning: modelos router not found - {e}")

try:
    from routes.datasets import router as datasets_router
    app.include_router(datasets_router, prefix="/datasets", tags=["Datasets"])
except ImportError as e:
    print(f"Warning: datasets router not found - {e}")

try:
    from routes.imagenes import router as imagenes_router
    app.include_router(imagenes_router, prefix="/imagenes", tags=["Imagenes"])
except ImportError as e:
    print(f"Warning: imagenes router not found - {e}")

try:
    from routes.liquenpedia import router as liquenpedia_router
    app.include_router(liquenpedia_router, prefix="/liquenpedia", tags=["LiquenPedia"])
except ImportError as e:
    print(f"Warning: liquenpedia router not found - {e}")

try:
    from routes.maps_route import router as maps_router
    app.include_router(maps_router, tags=["Maps"])
except ImportError as e:
    print(f"Warning: maps router not found - {e}")

try:
    from routes.test_route import router as test_router
    app.include_router(test_router, tags=["Test"])
except ImportError as e:
    print(f"Warning: test router not found - {e}")

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