"""Tests de control de acceso a imagenes privadas.

Verifica las reglas de privacidad:
1. Un usuario no puede acceder a las imagenes privadas de otro usuario.
2. Un administrador no puede acceder automaticamente a imagenes privadas ajenas.
3. El propietario puede acceder a sus propias imagenes privadas.
4. Las imagenes publicas (articulos) son accesibles sin autenticacion.
"""
import os
import time
import uuid

# Use a local sqlite DB for tests
os.environ.setdefault("DATABASE_URL", "sqlite:///./test.db")

from fastapi.testclient import TestClient
from config.database import engine
from models.base import Base
from models.core import Role
from config.db import SessionLocal

# Create tables for tests
Base.metadata.create_all(bind=engine)

from main import app

client = TestClient(app)


def _register_and_login(email_prefix: str) -> tuple[str, dict]:
    """Registra un usuario y devuelve (token, headers)."""
    timestamp = int(time.time())
    unique_id = uuid.uuid4().hex[:8]
    email = f"{email_prefix}_{timestamp}_{unique_id}@example.com"
    password = "Test@1234"

    reg = client.post("/auth/register", json={
        "email": email,
        "password": password,
        "name": f"{email_prefix} User",
        "apellido": "Test",
    })
    assert reg.status_code == 201, f"Registration failed: {reg.text}"

    login = client.post("/auth/login", json={"email": email, "password": password})
    assert login.status_code == 200, f"Login failed: {login.text}"

    token = login.json().get("access_token")
    assert token
    headers = {"Authorization": f"Bearer {token}"}

    me = client.get("/auth/me", headers=headers)
    assert me.status_code == 200
    user_data = me.json()

    return token, headers, user_data


def _upload_private_image(headers: dict, image_type: str) -> str:
    """Sube una imagen privada y devuelve la ruta relativa almacenada en BD."""
    files = {"file": ("test.jpg", b"\xff\xd8\xff\xe0" + b"dummy-data", "image/jpeg")}
    data = {"imagen_tipo": image_type}
    r = client.post("/imagenes/upload", files=files, data=data, headers=headers)
    assert r.status_code == 200, f"Upload failed: {r.text}"
    return r.json().get("url", "")


def test_user_cannot_access_other_users_private_image():
    """Caso 1: Usuario B no puede acceder a la imagen de perfil de Usuario A."""
    token_a, headers_a, user_a = _register_and_login("userA")
    _token_b, headers_b, user_b = _register_and_login("userB")

    # User A sube su foto de perfil
    image_url = _upload_private_image(headers_a, "profile")
    assert "/uploads/profiles/user_" in image_url, f"Expected private profile path, got: {image_url}"

    # Extraer user_id de la ruta
    parts = image_url.split("/")
    user_id_in_path = None
    for part in parts:
        if part.startswith("user_"):
            user_id_in_path = int(part[len("user_"):])
    assert user_id_in_path == user_data_a_id(user_a), \
        f"Path user_id ({user_id_in_path}) != User A's ID ({user_data_a_id(user_a)})"

    # User B intenta acceder
    file_subpath = image_url.replace("/uploads/", "")
    r = client.get(f"/imagenes/file/{file_subpath}", headers=headers_b)
    assert r.status_code == 403, f"Expected 403, got {r.status_code}: {r.text}"


def test_admin_cannot_access_other_users_private_image():
    """Caso 2: Administrador no puede acceder a imagenes privadas ajenas (sin permiso especial)."""
    token_a, headers_a, user_a = _register_and_login("admin_test_user")

    image_url = _upload_private_image(headers_a, "profile")
    file_subpath = image_url.replace("/uploads/", "")

    # Login como admin (creado por startup event)
    admin_login = client.post("/auth/login", json={"email": "admin@gmail.com", "password": "admin123"})
    if admin_login.status_code != 200:
        from models.core import Usuario
        from auth.password_handler import hash_password
        db = SessionLocal()
        try:
            admin_role = db.query(Role).filter(Role.nombre_rol == 'admin').first()
            if not admin_role:
                admin_role = Role(nombre_rol='admin', descripcion='Admin', nivel_acceso=10)
                db.add(admin_role)
                db.commit()
            existing = db.query(Usuario).filter(Usuario.correo == 'admin@gmail.com').first()
            if existing:
                db.delete(existing)
                db.commit()
            admin = Usuario(
                nombre='Admin', apellido='Admin', correo='admin@gmail.com',
                contrasena=hash_password('admin123'), estado_cuenta='active',
                id_rol=admin_role.id_rol,
            )
            db.add(admin)
            db.commit()
        finally:
            db.close()

        admin_login = client.post("/auth/login", json={"email": "admin@gmail.com", "password": "admin123"})
    assert admin_login.status_code == 200, f"Admin login failed: {admin_login.text}"
    admin_token = admin_login.json().get("access_token")
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    # Admin intenta acceder a la imagen del usuario
    r = client.get(f"/imagenes/file/{file_subpath}", headers=admin_headers)
    assert r.status_code == 403, f"Expected 403 for admin without CAN_VIEW_PRIVATE_IMAGES, got {r.status_code}: {r.text}"


def test_owner_can_access_own_private_image():
    """Caso 3: El propietario puede acceder a su propia imagen privada."""
    token, headers, user_data = _register_and_login("owner_user")

    image_url = _upload_private_image(headers, "profile")
    file_subpath = image_url.replace("/uploads/", "")

    # El propietario accede a su imagen
    r = client.get(f"/imagenes/file/{file_subpath}", headers=headers)
    assert r.status_code == 200, f"Expected 200 for owner, got {r.status_code}: {r.text}"


def test_public_article_image_without_auth():
    """Caso 4: Imagen publica de articulo accesible sin autenticacion."""
    # Subir imagen publica (no requiere auth)
    files = {"file": ("test.jpg", b"\xff\xd8\xff\xe0" + b"article-data", "image/jpeg")}
    data = {"imagen_tipo": "article"}
    r = client.post("/imagenes/upload", files=files, data=data)
    assert r.status_code == 200, f"Upload failed: {r.text}"
    image_url = r.json().get("url", "")
    assert "/uploads/articles/" in image_url

    # Acceder sin autenticacion
    r = client.get(image_url)
    assert r.status_code == 200, f"Expected 200 for public image without auth, got {r.status_code}: {r.text}"


def test_path_traversal_blocked():
    """Un intento de path traversal debe ser bloqueado."""
    _, headers, _ = _register_and_login("traversal_user")
    # Intentar acceder a /etc/passwd o archivo fuera de uploads
    r = client.get("/imagenes/file/../../../etc/passwd", headers=headers)
    # FastAPI's routing may normalize this, but if it reaches the handler, it should 403/404
    assert r.status_code in (403, 404), f"Expected 403 or 404 for path traversal, got {r.status_code}"


def user_data_a_id(user_data: dict) -> int:
    """Helper: extract user ID from /auth/me response."""
    return user_data.get("id_usuario") or user_data.get("id") or 0
