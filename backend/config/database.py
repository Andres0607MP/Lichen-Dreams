from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv
import os

load_dotenv()

DB_USER = os.getenv("DB_USER", "root")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "3306")
DB_NAME = os.getenv("DB_NAME", "lichen_dreams")
DATABASE_URL = os.getenv("DATABASE_URL")

if not DATABASE_URL:
    try:
        db_port = int(DB_PORT) if DB_PORT and DB_PORT != "None" else 3306
    except (ValueError, TypeError):
        db_port = 3306

    DATABASE_URL = (
        f"mysql+pymysql://{DB_USER}:{DB_PASSWORD}"
        f"@{DB_HOST}:{db_port}/{DB_NAME}"
    )

if DATABASE_URL.startswith("sqlite"):
    engine = create_engine(
        DATABASE_URL,
        connect_args={"check_same_thread": False}
    )
else:
    engine = create_engine(DATABASE_URL)


SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)


def get_db():
    db = SessionLocal()

    try:
        yield db

    finally:
        db.close()

try:
    connection = engine.connect()
    print("Conexion exitosa a la base de datos")
    connection.close()

except Exception as e:
    print("Error de conexion:", e)