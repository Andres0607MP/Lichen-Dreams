import os
import shutil
import time

os.environ.setdefault("DATABASE_URL", "sqlite:///./test_analysis.db")

from fastapi.testclient import TestClient
from config.database import engine
from models.base import Base

Base.metadata.create_all(bind=engine)

from main import app

client = TestClient(app)


def test_analysis_flow_persists_and_returns_data():
    email = f"analysis{int(time.time())}@example.com"
    reg = client.post("/auth/register", json={"email": email, "password": "secret", "name": "Tester"})
    assert reg.status_code == 201

    login = client.post("/auth/login", json={"email": email, "password": "secret"})
    assert login.status_code == 200
    token = login.json().get("access_token")
    assert token

    headers = {"Authorization": f"Bearer {token}"}

    payload = {"image_url": "https://example.com/lichen.jpg"}
    process_resp = client.post("/analysis/process", json=payload, headers=headers)
    assert process_resp.status_code == 200
    data = process_resp.json()
    assert data["id_usuario"] == 1
    assert data["url_imagen"] == payload["image_url"]
    assert data["estado"] == "completado"
    assert data["humedad"] == 65.5
    assert data["calidad_del_aire"] == "moderada"
    assert data["recomendacion"] == "Buena calidad del aire"

    analysis_id = data["id"]

    results_resp = client.get(f"/analysis/results/{analysis_id}", headers=headers)
    assert results_resp.status_code == 200
    assert results_resp.json()["id"] == analysis_id

    humidity_resp = client.get(f"/analysis/{analysis_id}/humidity", headers=headers)
    assert humidity_resp.status_code == 200
    assert humidity_resp.json()["id"] == analysis_id

    air_resp = client.get(f"/analysis/{analysis_id}/air-quality", headers=headers)
    assert air_resp.status_code == 200
    assert air_resp.json()["id"] == analysis_id

    recommendation_resp = client.get(f"/analysis/{analysis_id}/recommendation", headers=headers)
    assert recommendation_resp.status_code == 200
    assert recommendation_resp.json()["id"] == analysis_id

    missing_resp = client.get("/analysis/999999/humidity", headers=headers)
    assert missing_resp.status_code == 404


def teardown_module(module):
    try:
        if os.path.exists("backend/test_analysis.db"):
            os.remove("backend/test_analysis.db")
        if os.path.exists("backend/uploads"):
            shutil.rmtree("backend/uploads")
    except Exception:
        pass
