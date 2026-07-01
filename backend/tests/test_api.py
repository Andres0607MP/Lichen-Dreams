import os
import shutil
import time

from sqlalchemy.orm import sessionmaker

# Use a local sqlite DB for tests
os.environ.setdefault("DATABASE_URL", "sqlite:///./test.db")

from fastapi.testclient import TestClient
from config.database import engine
from models.base import Base
from models.core import LiquenPedia, Role, Usuario
from models.validations import ArticuloCreate
from routes.liquenpedia import create_article

# Create tables for tests
Base.metadata.create_all(bind=engine)

from main import app

client = TestClient(app)
SessionLocal = sessionmaker(bind=engine)


def test_root():
    r = client.get("/")
    assert r.status_code == 200
    assert "message" in r.json()


def test_get_modelos_empty():
    r = client.get("/modelos")
    assert r.status_code == 200
    assert isinstance(r.json(), list)


def test_create_and_get_dataset():
    payload = {"nombre_dataset": "test_ds", "ruta_archivo": "/tmp/x", "tipo_datos": "imagenes"}
    r = client.post("/datasets", json=payload)
    assert r.status_code == 201
    data = r.json()
    assert data["nombre_dataset"] == "test_ds" or data.get("nombre_dataset") == "test_ds"


def test_register_login_and_me():
    email = f"test{int(time.time())}@example.com"
    reg = client.post("/auth/register", json={"email": email, "password": "secret@", "name": "Tester"})
    assert reg.status_code == 201
    login = client.post("/auth/login", json={"email": email, "password": "secret@"})
    assert login.status_code == 200
    token = login.json().get("access_token")
    assert token
    headers = {"Authorization": f"Bearer {token}"}
    me = client.get("/auth/me", headers=headers)
    assert me.status_code == 200


def test_image_upload_and_delete():
    # create a dummy file
    files = {"file": ("test.jpg", b"dummydata", "image/jpeg")}
    r = client.post("/imagenes/upload", files=files)
    assert r.status_code == 200
    data = r.json()
    img_id = data.get("id_imagen")
    assert img_id
    get_r = client.get(f"/imagenes/{img_id}")
    assert get_r.status_code == 200
    del_r = client.delete(f"/imagenes/{img_id}")
    assert del_r.status_code == 204


def test_analysis_process_accepts_multipart_file():
    files = {"file": ("analysis.jpg", b"fake-image-content", "image/jpeg")}
    response = client.post("/analysis/process", files=files)

    assert response.status_code == 200
    payload = response.json()
    assert payload.get("id") is not None
    assert payload.get("url_imagen", "").startswith("/uploads/")


def test_liquenpedia_create_respects_requested_state():
    db = SessionLocal()
    try:
        role = Role(nombre_rol="admin", descripcion="Admin", nivel_acceso=1)
        db.add(role)
        db.commit()
        db.refresh(role)

        admin = Usuario(
            nombre="Admin",
            apellido="User",
            correo="admin-state@example.com",
            contrasena="hashed",
            id_rol=role.id_rol,
            estado_cuenta="active",
        )
        db.add(admin)
        db.commit()
        db.refresh(admin)

        payload = ArticuloCreate(
            titulo="Artículo de prueba",
            contenido="x" * 60,
            categoria="Ecología",
            autor="Admin",
            estado_publicacion="published",
        )

        result = create_article(payload=payload, db=db, current_user=admin)

        assert result["estado_publicacion"] == "published"

        saved = db.query(LiquenPedia).filter(LiquenPedia.id_articulo == result["id_articulo"]).first()
        assert saved is not None
        assert saved.estado_publicacion == "published"
    finally:
        db.close()


def teardown_module(module):
    # cleanup sqlite file and uploads
    try:
        if os.path.exists("backend/test.db"):
            os.remove("backend/test.db")
        if os.path.exists("backend/uploads"):
            shutil.rmtree("backend/uploads")
    except Exception:
        pass
