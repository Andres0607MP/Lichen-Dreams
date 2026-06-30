from sqlalchemy import create_engine, inspect, text
from dotenv import load_dotenv
import os
import sys

load_dotenv()

DB_USER = os.getenv("DB_USER", "root")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "3306")
DB_NAME = os.getenv("DB_NAME", "lichen_dreams")
# Allow overriding full DATABASE_URL (useful for sqlite in tests or env)
DATABASE_URL = os.getenv("DATABASE_URL")

if not DATABASE_URL:
    if os.getenv("PYTEST_CURRENT_TEST") or "pytest" in sys.modules:
        DATABASE_URL = "sqlite:///./test.db"
    else:
        # Convertir puerto a entero, con valor por defecto si está vacío o "None"
        try:
            db_port = int(DB_PORT) if DB_PORT and DB_PORT != "None" else 3306
        except (ValueError, TypeError):
            db_port = 3306

        DATABASE_URL = f"mysql+pymysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{db_port}/{DB_NAME}"

# Create engine with sqlite compatibility when detected
if DATABASE_URL.startswith("sqlite"):
    engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
else:
    engine = create_engine(DATABASE_URL)

try:
    connection = engine.connect()
    print("Conexion exitosa a la base de datos")
    connection.close()
except Exception as e:
    print("Error de conexion:", e)


def ensure_schema():
    inspector = inspect(engine)
    existing_tables = set(inspector.get_table_names())

    if 'analisis' in existing_tables:
        analisis_columns = {col['name'] for col in inspector.get_columns('analisis')}
        with engine.begin() as conn:
            if 'humedad' not in analisis_columns:
                conn.execute(text("ALTER TABLE analisis ADD COLUMN humedad FLOAT"))
            if 'calidad_del_aire' not in analisis_columns:
                conn.execute(text("ALTER TABLE analisis ADD COLUMN calidad_del_aire VARCHAR(100)"))
            if 'recomendacion' not in analisis_columns:
                conn.execute(text("ALTER TABLE analisis ADD COLUMN recomendacion TEXT"))
            if 'fecha_actualizacion' not in analisis_columns:
                conn.execute(text("ALTER TABLE analisis ADD COLUMN fecha_actualizacion DATETIME"))

    if 'imagenes' in existing_tables:
        imagenes_columns = {col['name'] for col in inspector.get_columns('imagenes')}
        with engine.begin() as conn:
            if 'nombre' not in imagenes_columns:
                conn.execute(text("ALTER TABLE imagenes ADD COLUMN nombre VARCHAR(255)"))
            if 'ruta_original' not in imagenes_columns:
                conn.execute(text("ALTER TABLE imagenes ADD COLUMN ruta_original TEXT"))
            if 'ruta_procesada' not in imagenes_columns:
                conn.execute(text("ALTER TABLE imagenes ADD COLUMN ruta_procesada TEXT"))

