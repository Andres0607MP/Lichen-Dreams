from dotenv import load_dotenv
import os
import logging
from urllib.parse import urlparse
from pathlib import Path

load_dotenv()

logger = logging.getLogger("lichdreams.security")
if not logger.handlers:
    handler = logging.StreamHandler()
    handler.setFormatter(logging.Formatter(
        "[%(asctime)s] [%(levelname)s] [SECURITY] %(message)s"
    ))
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)


PERMISSION_CAN_VIEW_PRIVATE_IMAGES = "CAN_VIEW_PRIVATE_IMAGES"
PERMISSIONS = {
    "admin": set(),
    "admin_privado": {PERMISSION_CAN_VIEW_PRIVATE_IMAGES},
    "auditor": {PERMISSION_CAN_VIEW_PRIVATE_IMAGES},
}


def _resolve_backend_url():
    backend_url = os.getenv("BACKEND_URL")
    if backend_url:
        return backend_url.rstrip("/")
    api_host = os.getenv("API_HOST", "localhost")
    api_port = os.getenv("API_PORT", "8000")
    return f"http://{api_host}:{api_port}"


GOOGLE_MAPS_API_KEY = os.getenv("GOOGLE_MAPS_API_KEY", "")
BACKEND_URL = _resolve_backend_url()

# Client ID esperado por el backend para validar ID tokens de Google (mismo
# valor que usa el frontend como serverClientId / aud del token).
GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID", "")

UPLOADS_BASE_DIR = Path(__file__).resolve().parent.parent / "uploads"
UPLOADS_BASE_DIR.mkdir(parents=True, exist_ok=True)

# Tipos de imagen permitidos para subida
ALLOWED_IMAGE_EXTENSIONS = {
    ".jpg",
    ".jpeg",
    ".png",
    ".webp",
    ".heic",
    ".heif",
}

ALLOWED_MIME_TYPES = {
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/webp",
    "image/heic",
    "image/heif",
}

# Tipos de imágenes dentro del sistema
IMAGE_TYPE_ARTICLE = "article"
IMAGE_TYPE_PROFILE = "profile"
IMAGE_TYPE_ANALYSIS = "analysis"
IMAGE_TYPE_SPECIES = "species"


def normalize_image_path(value, backend_url=BACKEND_URL):
    """Normaliza un path/URL de imagen a ruta relativa.

    - Si ya es una ruta relativa (empieza con '/'), se devuelve igual.
    - Si es una URL absoluta (http/https), se extrae solo el path
      manteniendo query strings.
    - Si no empieza con '/', se le antepone '/'.
    """
    if not value:
        return value
    val = value.strip()
    if not val:
        return value
    if val.startswith("/"):
        return val
    if val.startswith("http://") or val.startswith("https://"):
        parsed = urlparse(val)
        path = parsed.path or ""
        query = parsed.query
        if path:
            return path + (f"?{query}" if query else "")
        return val
    return "/" + val
