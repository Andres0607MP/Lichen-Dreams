from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from dotenv import load_dotenv
import os
from config.database import engine
from config.db import SessionLocal
from models.base import Base
from models.core import Role, Usuario
from auth.jwt_handler import create_access_token as create_token
from auth.password_handler import hash_password
from passlib.context import CryptContext
from pydantic import BaseModel, Field

load_dotenv()

app = FastAPI(title="Lichen Dreams API", version="1.0.0", description="API para análisis de líquenes")

# CORS: permitir peticiones desde el frontend en desarrollo (ajustar en producción)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

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
    from routes.profile import router as profile_router
    app.include_router(profile_router, tags=["Profile"])
except ImportError as e:
    print(f"Warning: profile router not found - {e}")

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
    # Create missing tables and seed default roles/admin user.
    try:
        Base.metadata.create_all(bind=engine)
        db = SessionLocal()
        admin_role = db.query(Role).filter(Role.nombre_rol == 'admin').first()
        if not admin_role:
            admin_role = Role(nombre_rol='admin', descripcion='Administrador', nivel_acceso=10)
            db.add(admin_role)
        user_role = db.query(Role).filter(Role.nombre_rol == 'user').first()
        if not user_role:
            user_role = Role(nombre_rol='user', descripcion='Usuario normal', nivel_acceso=1)
            db.add(user_role)
        db.commit()

        admin_user = db.query(Usuario).filter(Usuario.correo == 'admin@gmail.com').first()
        if not admin_user:
            admin_user = Usuario(
                nombre='Admin',
                apellido='Admin',
                correo='admin@gmail.com',
                contrasena=hash_password('admin'),
                telefono=None,
                estado_cuenta='active',
                id_rol=admin_role.id_rol
            )
            db.add(admin_user)
            db.commit()
    except Exception as e:
        print('Error inicializando la base de datos:', e)
    finally:
        try:
            db.close()
        except Exception:
            pass

@app.get("/")
def root():
    return {
        "message": "Lichen Dreams API funcionando",
        "db_host": DB_HOST
    }

@app.get("/api/config")
def get_config():
    """Devuelve variables de configuración para el frontend (ej: Google Maps API Key)"""
    return {
        "google_maps_api_key": os.getenv("GOOGLE_MAPS_API_KEY", ""),
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