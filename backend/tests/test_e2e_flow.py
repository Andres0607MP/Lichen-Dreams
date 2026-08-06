import os
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

os.environ.setdefault("DATABASE_URL", "sqlite:///./test.db")

from config.db import get_db
from main import app
from models.base import Base
from models.core import Dataset, ModeloIA

engine = create_engine("sqlite:///./test.db", connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


def test_flujo_completo_end_to_end():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)

    model = ModeloIA(id_modelo=1, nombre_modelo="modelo_test", version="1.0")
    dataset = Dataset(id_dataset=1, nombre_dataset="dataset_test", tipo_datos="imagenes")
    db = TestingSessionLocal()
    db.add(model)
    db.add(dataset)
    db.commit()
    db.close()

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as client:
        register = client.post(
            "/auth/register",
            json={"email": "e2e@example.com", "password": "Password123!", "name": "E2E"},
        )
        assert register.status_code == 201

        login = client.post(
            "/auth/login",
            json={"email": "e2e@example.com", "password": "Password123!"},
        )
        assert login.status_code == 200
        token = login.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        image_bytes = b"\xff\xd8\xff" + b"sample-image"
        upload = client.post(
            "/analysis/upload",
            headers=headers,
            files={"file": ("analysis.jpg", image_bytes, "image/jpeg")},
        )
        assert upload.status_code == 200

        process = client.post(
            "/analysis/process",
            headers=headers,
            files={"file": ("analysis.jpg", image_bytes, "image/jpeg")},
        )
        assert process.status_code == 200
        payload = process.json()
        assert payload["resultado"]
        assert payload["estado"]
        assert payload["calidad_del_aire"]

        results = client.get(f"/analysis/results/{payload['id']}", headers=headers)
        assert results.status_code == 200

        location = client.post(
            "/location/save",
            json={"latitude": 4.7, "longitude": -74.07, "direccion": "Bogotá"},
        )
        assert location.status_code == 200

        history = client.get("/history", headers=headers)
        assert history.status_code == 200
        assert isinstance(history.json(), list)

        points = client.get("/api/maps/points")
        assert points.status_code == 200
        assert isinstance(points.json(), list)
