from routes.users import router as user_router
from routes.modelos import router as modelos_router
from routes.datasets import router as datasets_router
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from dotenv import load_dotenv
import os
from routes.liquenpedia import router as liquen_router
from config.database import engine
from config.db import SessionLocal
from config.settings import BACKEND_URL, UPLOADS_BASE_DIR
from models.base import Base
from models.core import Role, Usuario, Analisis, ModeloIA, Dataset, HistorialActividad
from auth.jwt_handler import create_access_token as create_token
from auth.password_handler import hash_password
from passlib.context import CryptContext
from pydantic import BaseModel, Field

load_dotenv()

app = FastAPI(title="Lichen Dreams API", version="1.0.0", description="API para análisis de líquenes")
Base.metadata.create_all(bind=engine)

# CORS: permitir peticiones desde el frontend en desarrollo (ajustar en producción)
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1|10\.0\.2\.2)(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Ensure uploads directory structure exists.
# Public: uploads/articles/ served via StaticFiles.
# Private: uploads/profiles/ and uploads/analyses/ served via auth-guarded endpoints.
for subdir in ("articles", "profiles", "analyses"):
    (UPLOADS_BASE_DIR / subdir).mkdir(parents=True, exist_ok=True)

# Only expose /uploads/articles as public static files.
# Private image directories (profiles/, analyses/) are served
# via auth-guarded endpoints in routes/imagenes.py.
app.mount("/uploads/articles", StaticFiles(directory=str(UPLOADS_BASE_DIR / "articles")), name="uploads-articles")

# Importar y registrar routers
try:
    from routes.auth import router as auth_router
    app.include_router(auth_router, prefix="/auth", tags=["Auth"])
except ImportError as e:
    print(f"Warning: auth router not found - {e}")

try:
    from routes.users import router as users_router
    app.include_router(user_router, prefix="/api/users", tags=["users"])
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
    app.include_router(modelos_router, prefix="/modelos", tags=["modelos"])
except ImportError as e:
    print(f"Warning: modelos router not found - {e}")

try:
    from routes.datasets import router as datasets_router
    app.include_router(datasets_router, prefix="/datasets", tags=["datasets"])
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
    from routes.dashboard import router as dashboard_router
    app.include_router(dashboard_router, prefix="/dashboard", tags=["Dashboard"])
except ImportError as e:
    print(f"Warning: dashboard router not found - {e}")

try:
    from routes.notificaciones import router as notificaciones_router
    app.include_router(notificaciones_router, prefix="/notificaciones", tags=["Notificaciones"])
except ImportError as e:
    print(f"Warning: notificaciones router not found - {e}")

try:
    from routes.maps_route import router as maps_router
    app.include_router(maps_router, prefix="/api/maps", tags=["Maps"])
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
    db = None
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
                contrasena=hash_password('admin123'),
                telefono=None,
                estado_cuenta='active',
                id_rol=admin_role.id_rol
            )
            db.add(admin_user)
        else:
            admin_user.contrasena = hash_password('admin123')

        modelo = db.query(ModeloIA).filter(ModeloIA.id_modelo == 1).first()
        if not modelo:
            modelo = ModeloIA(nombre_modelo='modelo_demo', version='1.0', descripcion='Demo')
            db.add(modelo)

        dataset = db.query(Dataset).filter(Dataset.id_dataset == 1).first()
        if not dataset:
            dataset = Dataset(nombre_dataset='dataset_demo', ruta_archivo='/data/demo', tipo_datos='imagenes')
            db.add(dataset)

        db.commit()

        if not db.query(Analisis).filter(Analisis.id_analisis == 1).first():
            seed_analysis = Analisis(
                id_analisis=1,
                id_usuario=admin_user.id_usuario,
                id_modelo=modelo.id_modelo,
                id_dataset=dataset.id_dataset,
                resultado_ia='liquen saludable',
                porcentaje_confianza=0.93,
                nivel_contaminacion='baja',
                calidad_aire='moderada',
                estado_liquen='completado',
                tiempo_procesamiento=1.2,
                observaciones='Buena calidad de aire en la zona',
                estado_validacion='completed',
                temperatura_ambiente=22.0,
                humedad_relativa=65.5,
            )
            db.add(seed_analysis)
            db.flush()

            seed_historial = HistorialActividad(
                accion_realizada='analisis_guardado',
                descripcion_accion=f'analysis_id={seed_analysis.id_analisis}; location=',
                id_usuario=seed_analysis.id_usuario,
            )
            db.add(seed_historial)
            db.commit()
    except Exception as e:
        print('Error inicializando la base de datos:', e)
    finally:
        if db:
            db.close()

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
        "backend_url": BACKEND_URL,
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