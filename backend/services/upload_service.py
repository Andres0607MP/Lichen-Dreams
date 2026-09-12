"""Servicio de carga y validaciÃ³n de imÃ¡genes.

Centraliza la logica de:
- Validacion de extension y MIME type.
- Guardado en subdirectorios por tipo (articles, profiles, analyses).
- Resolucion de paths relativos a filesystem (now R2).
- Verificacion de propiedad para acceso a imagenes privadas.
"""
import os
import uuid
import shutil
from pathlib import Path
from typing import Optional, Tuple

import requests
import boto3
from botocore.config import Config
from botocore.exceptions import ClientError
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
    R2_ENDPOINT_URL,
    R2_ACCESS_KEY_ID,
    R2_SECRET_ACCESS_KEY,
    R2_BUCKET_NAME,
)

# Map file extension to MIME type for R2 ContentType
_CONTENT_TYPE_MAP = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
    ".heic": "image/heic",
    ".heif": "image/heif",
}


def _get_r2_client():
    """Create and return a boto3 S3 client configured for Cloudflare R2."""
    if not all([R2_ENDPOINT_URL, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET_NAME]):
        raise RuntimeError("R2 configuration is incomplete. Check environment variables.")
    return boto3.client(
        's3',
        endpoint_url=R2_ENDPOINT_URL,
        aws_access_key_id=R2_ACCESS_KEY_ID,
        aws_secret_access_key=R2_SECRET_ACCESS_KEY,
        config=Config(signature_version="s3v4"),
    )


def _r2_key_from_path(relative_path: str) -> Optional[str]:
    """
    Convert a relative path like '/uploads/articles/uuid.jpg' to R2 key 'articles/uuid.jpg'.
    Returns None if the path does not start with '/uploads/'.
    """
    normalized = normalize_image_path(relative_path)
    if not normalized or not normalized.startswith("/uploads/"):
        return None
    # Remove the leading '/uploads/'
    return normalized[len("/uploads/"):]


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
    """
    Guarda el contenido de una imagen en R2 bajo el subdirectorio correcto.

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

    unique_name = f"{uuid.uuid4().hex}{extension}"
    key = f"{subdir}/{unique_name}"
    content_type = _CONTENT_TYPE_MAP.get(extension, "application/octet-stream")

    try:
        client = _get_r2_client()
        client.put_object(
            Bucket=R2_BUCKET_NAME,
            Key=key,
            Body=content,
            ContentType=content_type,
        )
    except ClientError as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to upload image to R2: {e}",
        )

    relative_path = f"/uploads/{subdir}/{unique_name}"
    return relative_path


def resolve_file_path(relative_path: str) -> Optional[Path]:
    """
    Deprecated: Storage now in R2. Always returns None.
    Kept for backward compatibility.
    """
    return None


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


def file_exists_in_r2(relative_path: str) -> bool:
    """Check if an object exists in R2 given a relative path."""
    key = _r2_key_from_path(relative_path)
    if key is None:
        return False
    try:
        client = _get_r2_client()
        client.head_object(Bucket=R2_BUCKET_NAME, Key=key)
        return True
    except ClientError as e:
        if e.response['Error']['Code'] == '404':
            return False
        # Some other error
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error checking object existence in R2: {e}",
        )


def delete_file_r2(relative_path: str) -> None:
    """Delete an object from R2 given a relative path."""
    key = _r2_key_from_path(relative_path)
    if key is None:
        return
    try:
        client = _get_r2_client()
        client.delete_object(Bucket=R2_BUCKET_NAME, Key=key)
    except ClientError as e:
        if e.response['Error']['Code'] == '404':
            # Object already deleted, ignore
            return
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete object from R2: {e}",
        )


def get_presigned_url_r2(relative_path: str, expires_in: int = 300) -> str:
    """
    Generate a presigned GET URL for an object in R2.
    """
    key = _r2_key_from_path(relative_path)
    if key is None:
        raise ValueError("Invalid relative path")
    try:
        client = _get_r2_client()
        url = client.generate_presigned_url(
            'get_object',
            Params={'Bucket': R2_BUCKET_NAME, 'Key': key},
            ExpiresIn=expires_in,
        )
        return url
    except ClientError as e:
        if e.response['Error']['Code'] == '404':
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Image not found")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate presigned URL: {e}",
        )


def download_image_from_r2(relative_path: str) -> bytes:
    """
    Download an object from R2 given a relative path and return its bytes.
    """
    key = _r2_key_from_path(relative_path)
    if key is None:
        raise ValueError("Invalid relative path")
    try:
        client = _get_r2_client()
        response = client.get_object(Bucket=R2_BUCKET_NAME, Key=key)
        return response['Body'].read()
    except ClientError as e:
        if e.response['Error']['Code'] == '404':
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Image not found")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to download object from R2: {e}",
        )


def copy_object_r2(source_key: str, dest_key: str) -> None:
    """Copy an object within the same R2 bucket."""
    try:
        client = _get_r2_client()
        copy_source = {'Bucket': R2_BUCKET_NAME, 'Key': source_key}
        client.copy_object(
            Bucket=R2_BUCKET_NAME,
            Key=dest_key,
            CopySource=copy_source,
        )
    except ClientError as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to copy object in R2: {e}",
        )


def copy_to_article_author_photo(source_relative_path: str, user_id: int) -> str:
    """
    Copia una imagen de perfil privada a la carpeta publica de articulos
    para usarla como foto historica del autor. Devuelve la nueva ruta publica.
    """
    normalized = normalize_image_path(source_relative_path)
    if not normalized or not normalized.startswith("/uploads/"):
        raise ValueError("Ruta de imagen invalida")

    source_key = normalized[len("/uploads/"):]
    ext = Path(source_key).suffix
    unique_name = f"author_{user_id}_{uuid.uuid4().hex}{ext}"
    dest_key = f"articles/{unique_name}"

    try:
        copy_object_r2(source_key, dest_key)
    except Exception:
        # If copy fails, we could fallback to download+upload but keep simple
        raise

    return f"/uploads/articles/{unique_name}"


def download_and_save_profile_image(image_url: str, user_id: int) -> Optional[str]:
    """
    Descarga una imagen externa (p. ej. foto de Google) y la guarda en R2
    como foto de perfil del usuario.

    - Si la descarga falla, devuelve ``None`` (no lanza).
    - Preserva la extensiÃ³n original (.jpg, .png, .webp, etc.).
    - Si la extensiÃ¡n no se puede determinar, asume .jpg.
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

    # Determinar extensiÃ³n desde la URL o el content-type
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