from sqlalchemy import create_engine
from dotenv import load_dotenv
import os

load_dotenv()

DB_USER = os.getenv("DB_USER", "root")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "3306")
DB_NAME = os.getenv("DB_NAME", "lichen_dreams")

# Convertir puerto a entero, con valor por defecto si está vacío o "None"
try:
    db_port = int(DB_PORT) if DB_PORT and DB_PORT != "None" else 3306
except (ValueError, TypeError):
    db_port = 3306

DATABASE_URL = f"mysql+pymysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{db_port}/{DB_NAME}"

engine = create_engine(DATABASE_URL)

try:
    connection = engine.connect()
    print("Conexion exitosa a MySQL")
except Exception as e:
    print("Error de conexion:", e)

