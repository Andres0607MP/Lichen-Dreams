from sqlalchemy import create_engine
from dotenv import load_dotenv
import os

load_dotenv()

DB_USER = os.getenv("DB_USER", "root")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "3306")
DB_NAME = os.getenv("DB_NAME", "lichen_dreams")
DATABASE_URL = os.getenv("DATABASE_URL")

# SSL configuration (required by Aiven/MySQL over TLS)
DB_SSL = os.getenv("DB_SSL", "").lower() in ("true", "1", "yes")
DB_SSL_CA = os.getenv("DB_SSL_CA")

if not DATABASE_URL:
    # Convert port to integer, default if empty or "None"
    try:
        db_port = int(DB_PORT) if DB_PORT and DB_PORT != "None" else 3306
    except (ValueError, TypeError):
        db_port = 3306

    DATABASE_URL = f"mysql+pymysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{db_port}/{DB_NAME}"


def _make_connect_args(url: str) -> dict:
    """Build SQLAlchemy connect_args, adding SSL for MySQL when DB_SSL is set."""
    if url.startswith("sqlite"):
        return {"check_same_thread": False}
    args: dict = {}
    if DB_SSL:
        if DB_SSL_CA:
            args["ssl"] = {"ca": DB_SSL_CA}
        else:
            args["ssl"] = {"check_hostname": False}
    return args


# Create engine with sqlite compatibility or SSL for MySQL
engine = create_engine(DATABASE_URL, connect_args=_make_connect_args(DATABASE_URL))

try:
    connection = engine.connect()
    print("Conexion exitosa a la base de datos")
    connection.close()
except Exception as e:
    print("Error de conexion:", e)

