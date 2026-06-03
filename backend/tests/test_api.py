import os
import shutil
import time

# Use a local sqlite DB for tests
os.environ.setdefault("DATABASE_URL", "sqlite:///./test.db")

from fastapi.testclient import TestClient
from config.database import engine
from models.base import Base

# Create tables for tests
Base.metadata.create_all(bind=engine)

from main import app

client = TestClient(app)


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
    reg = client.post("/auth/register", json={"email": email, "password": "secret", "name": "Tester"})
    assert reg.status_code == 201
    login = client.post("/auth/login", json={"email": email, "password": "secret"})
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


def teardown_module(module):
    # cleanup sqlite file and uploads
    try:
        if os.path.exists("backend/test.db"):
            os.remove("backend/test.db")
        if os.path.exists("backend/uploads"):
            shutil.rmtree("backend/uploads")
    except Exception:
        pass
