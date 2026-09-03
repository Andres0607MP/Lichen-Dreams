"""Servicio de carga y validación de imágenes.

Centraliza la logica de:
- Validacion de extension y MIME type.
- Guardado en subdirectorios por tipo (articles, profiles, analyses).
- Resolucion de paths relativos a filesystem.
- Verificacion de propiedad para acceso a imagenes privadas.
"""
import os
import uuid
import shutil
from pathlib import Path
from typing import Optional, Tuple

import requests
from fastapi import UploadFile, HTTPException, status
from config.settings import (
    UPLOADS_BASE_DIR,
    ALLOWED_IMAGE_EXTENSIONS,
    ALLOWED_MIME_TYPES,
    IMAGE_TYPE_ARTICLE,
    IMAGE_TYPE_PROFILE,
    IMAGE_TYPE_ANALYSIS,
    IMAGE_TYPE_SPECIES,
    normalize_image_path,
)


async def validate_image(file: UploadFile) -> Tuple[bytes, str]:
    """Lee y valida un archivo de imagen.

    Verifica extension y content-type contra listas blancas.
    Si el content-type es 'application/octet-stream' (comun en Android),
    se omite la validacion MIME y se confia en la extension + magic bytes.
    Devuelve (contenido_bytes, extension_con_punto).
    Lanza HTTPException 400/415 si la validacion falla.
    """
    filename = file.filename or ""
    ext = os.path.splitext(filename)[1].lower()

    if ext not in ALLOWED_IMAGE_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Extension '{ext}' no permitida. Extensiones validas: {', '.join(sorted(ALLOWED_IMAGE_EXTENSIONS))}",
        )

    content_type = (file.content_type or "").lower().strip()
    SKIP_MIME_TYPES = {"", "application/octet-stream", "application/octetstream", "binary/octet-stream",
                       "application/octet-stream; charset=binary"}
    if content_type and content_type not in SKIP_MIME_TYPES:
        if content_type not in ALLOWED_MIME_TYPES:
            raise HTTPException(
                status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
                detail=f"Tipo MIME '{content_type}' no permitido. Tipos validos: {', '.join(sorted(ALLOWED_MIME_TYPES))}",
            )

    content = await file.read()
    if not content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El archivo esta vacio",
        )

    if not _verify_magic_bytes(content, ext):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"El contenido del archivo no coincide con una imagen {ext}",
        )

    return content, ext


_MAGIC_BYTES = {
    ".jpg": [b"\xff\xd8\xff"],
    ".jpeg": [b"\xff\xd8\xff"],
    ".png": [b"\x89PNG\r\n\x1a\n"],
    ".webp": [b"RIFF"],
}


def _verify_magic_bytes(content: bytes, ext: str) -> bool:
    """Valida los primeros bytes del archivo contra el tipo esperado por la extension."""
    if ext in _MAGIC_BYTES:
        magic = _MAGIC_BYTES[ext]
        return any(content.startswith(m) for m in magic)
    return True


def save_file(
    content: bytes,
    extension: str,
    image_type: str,
    user_id: Optional[int] = None,
) -> str:
    """Guarda el contenido de una imagen en el subdirectorio correcto.

    image_type debe ser 'article', 'profile' o 'analysis'.
    Devuelve la ruta relativa almacenada en BD, ej:
        /uploads/articles/uuid.jpg
        /uploads/profiles/user_5/uuid.jpg
        /uploads/analyses/user_5/uuid.jpg
    """
    if image_type == IMAGE_TYPE_ARTICLE:
        subdir = "articles"
    elif image_type == IMAGE_TYPE_PROFILE:
        if user_id is None:
            raise ValueError("user_id es requerido para imagenes de perfil")
        subdir = f"profiles/user_{user_id}"
    elif image_type == IMAGE_TYPE_ANALYSIS:
        if user_id is None:
            raise ValueError("user_id es requerido para imagenes de analisis")
        subdir = f"analyses/user_{user_id}"
    elif image_type == IMAGE_TYPE_SPECIES:
        subdir = "species"
    else:
        raise ValueError(f"image_type '{image_type}' no reconocido")

    target_dir = UPLOADS_BASE_DIR / subdir
    target_dir.mkdir(parents=True, exist_ok=True)

    unique_name = f"{uuid.uuid4().hex}{extension}"
    dest_path = target_dir / unique_name

    dest_path.write_bytes(content)

    relative_path = f"/uploads/{subdir}/{unique_name}"
    return relative_path


def resolve_file_path(relative_path: str) -> Optional[Path]:
    """Resuelve una ruta relativa (ej: /uploads/profiles/user_5/x.jpg)
    a un Path del filesystem. Devuelve None si el path escapa del uploads dir.
    """
    normalized = normalize_image_path(relative_path)
    if not normalized or not normalized.startswith("/uploads/"):
        return None

    rel = normalized[len("/uploads/"):]
    full_path = (UPLOADS_BASE_DIR / rel).resolve()

    try:
        full_path.relative_to(UPLOADS_BASE_DIR.resolve())
    except ValueError:
        return None

    return full_path if full_path.exists() else None


def extract_user_id_from_path(relative_path: str) -> Optional[int]:
    """Extrae el user_id de una ruta privada como:
        /uploads/profiles/user_5/avatar.jpg  -> 5
        /uploads/analyses/user_5/result.jpg  -> 5
    """
    normalized = normalize_image_path(relative_path)
    if not normalized:
        return None
    parts = normalized.strip("/").split("/")
    for part in parts:
        if part.startswith("user_"):
            try:
                return int(part[len("user_"):])
            except ValueError:
                return None
    return None


def is_private_image_path(relative_path: str) -> bool:
    """Devuelve True si la ruta corresponde a imagenes privadas
    (profiles o analyses), False si es publica (articles) o None.
    """
    normalized = normalize_image_path(relative_path)
    if not normalized or not normalized.startswith("/uploads/"):
        return False
    rel = normalized[len("/uploads/"):].strip("/")
    return rel.startswith("profiles/") or rel.startswith("analyses/")


def copy_to_article_author_photo(source_relative_path: str, user_id: int) -> str:
    """Copia una imagen de perfil privada a la carpeta publica de articulos
    para usarla como foto historica del autor. Devuelve la nueva ruta publica.
    """
    normalized = normalize_image_path(source_relative_path)
    if not normalized or not normalized.startswith("/uploads/"):
        raise ValueError("Ruta de imagen invalida")

    source_path = UPLOADS_BASE_DIR / normalized[len("/uploads/"):]
    if not source_path.exists():
        raise FileNotFoundError("Imagen de perfil original no encontrada")

    ext = source_path.suffix
    unique_name = f"author_{user_id}_{uuid.uuid4().hex}{ext}"
    dest_dir = UPLOADS_BASE_DIR / "articles"
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest_path = dest_dir / unique_name

    shutil.copy2(source_path, dest_path)

    return f"/uploads/articles/{unique_name}"


def download_and_save_profile_image(image_url: str, user_id: int) -> Optional[str]:
    """Descarga una imagen externa (p. ej. foto de Google) y la guarda localmente
    como foto de perfil del usuario.

    Esto garantiza que ``foto_perfil`` siempre sea una ruta local accesible
    por el sistema de uploads, lo que permite a ``copy_to_article_author_photo``
    funcionar correctamente y evita depender de URLs externas que pueden expirar.

    - Si la descarga falla, devuelve ``None`` (no lanza).
    - Preserva la extensión original (.jpg, .png, .webp, etc.).
    - Si la extensión no se puede determinar, asume .jpg.
    """
    if not image_url or not image_url.strip().startswith(("http://", "https://")):
        return None

    try:
        response = requests.get(image_url, timeout=15)
        response.raise_for_status()
        content = response.content
        if not content:
            return None
    except Exception:
        return None

    # Determinar extensión desde la URL o el content-type
    ext = None
    lower_url = image_url.lower()
    for allowed_ext in ALLOWED_IMAGE_EXTENSIONS:
        if lower_url.endswith(allowed_ext):
            ext = allowed_ext
            break
    if ext is None:
        try:
            response2 = requests.head(image_url, timeout=10, allow_redirects=True)
            content_type = (response2.headers.get("Content-Type") or "").lower()
            for mime, allowed_ext in zip(ALLOWED_MIME_TYPES, ALLOWED_IMAGE_EXTENSIONS):
                if content_type == mime:
                    ext = allowed_ext
                    break
        except Exception:
            pass
    if ext is None:
        ext = ".jpg"

    try:
        return save_file(
            content=content,
            extension=ext,
            image_type=IMAGE_TYPE_PROFILE,
            user_id=user_id,
        )
    except Exception:
        return None
