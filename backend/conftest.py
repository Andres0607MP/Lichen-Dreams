"""Configuración global de pytest del backend.

Aísla cada ejecución de tests de forma limpia:
- Define DATABASE_URL ANTES de que cualquier módulo de test importe
  config.database (los módulos usan os.environ.setdefault, por lo que heredan
  este valor).
- Usa un archivo SQLite TEMPORAL único por proceso, eliminado antes de cada
  sesión, de modo que ninguna corrida hereda estado persistente de otra.
- Bootstrap del esquema + roles + usuario admin en esa BD temporal, para que
  cada módulo de tests sea autosuficiente (no depende de `backend/test.db`
  ni de semillas de corridas anteriores).
- Mockea el servicio de upload (R2) para que los tests NO escriban en el
  bucket de producción.

No se modifica producción, ni MySQL, ni modelos, ni migraciones.
"""
import os
import tempfile

_db_path = os.path.join(tempfile.gettempdir(), "lichen_pytest.db")

if os.path.exists(_db_path):
    try:
        os.remove(_db_path)
    except OSError:
        pass

os.environ["DATABASE_URL"] = "sqlite:///" + _db_path.replace("\\", "/")

# Bootstrap del esquema y semillas mínimas (roles + admin) sobre la BD temporal.
try:
    from config.db import SessionLocal, engine
    from models.base import Base
    from models.core import Role, Usuario, ModeloIA
    from auth.password_handler import hash_password
    import json as _json
    from pathlib import Path as _Path

    _MODEL_V3 = _Path(__file__).resolve().parent / "ia" / "modelos" / "lichen_model_v3.keras"

    Base.metadata.create_all(bind=engine)
    with SessionLocal() as db:
        admin_role = db.query(Role).filter(Role.nombre_rol == "admin").first()
        if not admin_role:
            admin_role = Role(nombre_rol="admin", descripcion="Administrador", nivel_acceso=10)
            user_role = Role(nombre_rol="user", descripcion="Usuario normal", nivel_acceso=1)
            db.add(admin_role)
            db.add(user_role)
            db.flush()
            if not db.query(Usuario).filter(Usuario.correo == "admin@gmail.com").first():
                db.add(
                    Usuario(
                        nombre="Admin",
                        apellido="",
                        correo="admin@gmail.com",
                        contrasena=hash_password("admin123"),
                        estado_cuenta="active",
                        id_rol=admin_role.id_rol,
                        proveedor="local",
                    )
                )
            db.commit()

        # Modelo activo de referencia: V3 (coherente con produccion). Usa un
        # id_modelo alto para no colisionar con los id_modelo=1 de otros tests.
        # refleja el estado real esperado: 0=saludable, 1=contaminado, 2=desconocido.
        if _MODEL_V3.exists() and not db.query(ModeloIA).filter(
                ModeloIA.estado_modelo == "activo",
                ModeloIA.version == "v3.0").first():
            db.add(ModeloIA(
                id_modelo=900,
                nombre_modelo="clasificador ambiental 3 clases",
                version="v3.0",
                tipo_modelo="cnn",
                descripcion="CNN 3 clases (tests): saludable=0, contaminado=1, desconocido=2.",
                precision_modelo=0.4517,
                estado_modelo="activo",
                observaciones=_json.dumps({
                    "f1_macro": 0.2406,
                    "accuracy": 0.4517,
                    "clases": {"0": "liquen saludable", "1": "liquen contaminado", "2": "desconocido"},
                    "archivo": str(_MODEL_V3),
                }, ensure_ascii=False),
            ))
            db.commit()
except Exception as e:  # pragma: no cover
    import sys

    print(f"[pytest] bootstrap ignorado: {e}", file=sys.stderr)


# Fixtures para mockear upload_service y evitar escrituras en R2 producción
import pytest
from unittest.mock import MagicMock, AsyncMock


@pytest.fixture(autouse=True)
def mock_upload_service(monkeypatch):
    """Mockea services.upload_service para que los tests no usen R2 real."""
    from services import upload_service
    from routes import imagenes as imagenes_routes
    from routes import auth as auth_routes
    from routes import liquenpedia as liquenpedia_routes
    
    # Mock functions
    async def mock_validate_image(file):
        return b"\xff\xd8\xff" + b"test-image-content", ".jpg"
    
    def mock_save_file(content, extension, image_type, user_id=None):
        if image_type == "article":
            return "/uploads/articles/test_mock.jpg"
        elif image_type == "analysis":
            return f"/uploads/analyses/user_{user_id}/test_mock.jpg"
        elif image_type == "profile":
            return f"/uploads/profiles/user_{user_id}/profile.jpg"
        elif image_type == "species":
            return "/uploads/species/test_mock.jpg"
        return "/uploads/test_mock.jpg"
    
    def mock_save_profile_image(content, extension, user_id):
        return f"/uploads/profiles/user_{user_id}/profile.jpg"
    
    def mock_download_and_save_profile_image(image_url, user_id):
        return f"/uploads/profiles/user_{user_id}/profile.jpg"
    
    def mock_delete_file_r2(relative_path):
        return None
    
    def mock_delete_user_r2_objects(user_id):
        return None
    
    def mock_get_presigned_url_r2(relative_path, expires_in=300):
        # Return a realistic R2-like URL for tests
        if "articles/author_" in relative_path:
            return f"https://test.r2.cloudflarestorage.com/lichen-dreams-images{relative_path.replace('/uploads/', '/')}?sig=mock"
        elif "articles" in relative_path:
            return f"https://test.r2.cloudflarestorage.com/lichen-dreams-images/articles/test.jpg?sig=mock"
        elif "species" in relative_path:
            return f"https://test.r2.cloudflarestorage.com/lichen-dreams-images/species/test.jpg?sig=mock"
        elif "profiles" in relative_path:
            return f"https://test.r2.cloudflarestorage.com/lichen-dreams-images/profiles/user_1/profile.jpg?sig=mock"
        elif "analyses" in relative_path:
            return f"https://test.r2.cloudflarestorage.com/lichen-dreams-images/analyses/user_1/test.jpg?sig=mock"
        return f"https://test.r2.cloudflarestorage.com/lichen-dreams-images/test.jpg?sig=mock"
    
    def mock_file_exists_in_r2(relative_path):
        return True
    
    def mock_copy_to_article_author_photo(source_relative_path, user_id):
        return f"/uploads/articles/author_{user_id}_mock.jpg"
    
    def mock_extract_user_id_from_path(relative_path):
        if not relative_path:
            return None
        # Handle both old UUID format and new deterministic format
        # /uploads/profiles/user_1/profile.jpg -> 1
        # /uploads/analyses/user_5/uuid.jpg -> 5
        parts = relative_path.strip("/").split("/")
        for i, part in enumerate(parts):
            if part.startswith("user_") and part[5:].isdigit():
                return int(part[5:])
        return None
    
    def mock_is_private_image_path(relative_path):
        if not relative_path:
            return False
        return "profiles" in relative_path or "analyses" in relative_path
    
    # Apply mocks to the upload_service module
    monkeypatch.setattr(upload_service, "validate_image", mock_validate_image)
    monkeypatch.setattr(upload_service, "save_file", mock_save_file)
    monkeypatch.setattr(upload_service, "save_profile_image", mock_save_profile_image)
    monkeypatch.setattr(upload_service, "download_and_save_profile_image", mock_download_and_save_profile_image)
    monkeypatch.setattr(upload_service, "delete_file_r2", mock_delete_file_r2)
    monkeypatch.setattr(upload_service, "delete_user_r2_objects", mock_delete_user_r2_objects)
    monkeypatch.setattr(upload_service, "get_presigned_url_r2", mock_get_presigned_url_r2)
    monkeypatch.setattr(upload_service, "file_exists_in_r2", mock_file_exists_in_r2)
    monkeypatch.setattr(upload_service, "copy_to_article_author_photo", mock_copy_to_article_author_photo)
    
    # Also patch in routes that imported the functions directly
    monkeypatch.setattr(imagenes_routes, "validate_image", mock_validate_image)
    monkeypatch.setattr(imagenes_routes, "save_file", mock_save_file)
    monkeypatch.setattr(imagenes_routes, "save_profile_image", mock_save_profile_image)
    monkeypatch.setattr(imagenes_routes, "file_exists_in_r2", mock_file_exists_in_r2)
    monkeypatch.setattr(imagenes_routes, "get_presigned_url_r2", mock_get_presigned_url_r2)
    monkeypatch.setattr(imagenes_routes, "delete_file_r2", mock_delete_file_r2)
    monkeypatch.setattr(imagenes_routes, "extract_user_id_from_path", mock_extract_user_id_from_path)
    monkeypatch.setattr(imagenes_routes, "is_private_image_path", mock_is_private_image_path)
    
    monkeypatch.setattr(liquenpedia_routes, "copy_to_article_author_photo", mock_copy_to_article_author_photo)
    
    monkeypatch.setattr(auth_routes, "download_and_save_profile_image", mock_download_and_save_profile_image)
    
    yield