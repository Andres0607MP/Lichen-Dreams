import os
import sys
import uuid

os.environ.setdefault("DATABASE_URL", "sqlite:///./test.db")

sys.path.append(
    os.path.abspath(
        os.path.join(
            os.path.dirname(__file__),
            ".."
        )
    )
)

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient

from config.db import get_db
from models.base import Base
from models.core import Analisis, HistorialActividad, Imagen, ModeloIA, Usuario
from main import app

ENGINE = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
SessionLocal = sessionmaker(bind=ENGINE)


def override_get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture()
def client():
    Base.metadata.drop_all(bind=ENGINE)
    Base.metadata.create_all(bind=ENGINE)
    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


def _register_and_seed(client):
    email = f"rep+{uuid.uuid4().hex[:8]}@example.com"
    reg = client.post(
        "/auth/register",
        json={"email": email, "password": "Password123!", "name": "Reporter"},
    )
    assert reg.status_code == 201

    login = client.post(
        "/auth/login",
        data={"email": email, "password": "Password123!"},
    )
    assert login.status_code == 200
    token = login.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Seed: un análisis válido + historial para que el resumen no esté vacío.
    db = SessionLocal()
    try:
        user = db.query(Usuario).filter(Usuario.correo == email).first()
        modelo = ModeloIA(nombre_modelo="test", version="1.0")
        db.add(modelo)
        db.flush()
        analisis = Analisis(
            id_usuario=user.id_usuario,
            id_modelo=modelo.id_modelo,
            resultado_ia="liquen saludable",
            estado_validacion="completado",
            nivel_contaminacion="bajo",
            temperatura_ambiente=18.5,
            humedad_relativa=60.0,
        )
        db.add(analisis)
        db.flush()
        db.add(Imagen(id_analisis=analisis.id_analisis, tipo_captura="campo"))
        db.add(HistorialActividad(id_usuario=user.id_usuario, accion_realizada="análisis"))
        db.commit()
    finally:
        db.close()

    return email, headers


def test_post_reports_environmental_crea_reporte_con_datos(client):
    _, headers = _register_and_seed(client)

    resp = client.post(
        "/reports/environmental",
        headers=headers,
        json={
            "titulo": "Resumen de prueba",
            "descripcion": "Test",
            "tipo_reporte": "ambiental",
            "formato_reporte": "json",
        },
    )
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["id_reporte"] is not None
    assert data["datos_reporte"] is not None
    assert data["datos_reporte"]["total_analisis"] >= 1
    assert data["titulo"] == "Resumen de prueba"


def test_get_reports_devuelve_lista(client):
    _, headers = _register_and_seed(client)

    resp = client.post(
        "/reports/environmental",
        headers=headers,
        json={"titulo": "Resumen A", "tipo_reporte": "ambiental"},
    )
    assert resp.status_code == 201

    listing = client.get("/reports", headers=headers)
    assert listing.status_code == 200
    assert isinstance(listing.json(), list)
    assert len(listing.json()) >= 1
    assert "datos_reporte" in listing.json()[0]


def test_get_reports_sin_datos_devuelve_lista_vacia(client):
    # Usuario sin análisis ni historial: GET /reports debe ser una lista vacía.
    email = f"rep_empty+{uuid.uuid4().hex[:8]}@example.com"
    client.post(
        "/auth/register",
        json={"email": email, "password": "Password123!", "name": "Empty"},
    )
    login = client.post(
        "/auth/login",
        data={"email": email, "password": "Password123!"},
    )
    headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

    listing = client.get("/reports", headers=headers)
    assert listing.status_code == 200
    assert listing.json() == []


def test_eliminar_reporte(client):
    _, headers = _register_and_seed(client)

    created = client.post(
        "/reports/environmental",
        headers=headers,
        json={"titulo": "Resumen a eliminar", "tipo_reporte": "ambiental"},
    )
    assert created.status_code == 201
    report_id = created.json()["id_reporte"]

    deleted = client.delete(f"/reports/{report_id}", headers=headers)
    assert deleted.status_code == 204

    listing = client.get("/reports", headers=headers)
    assert listing.status_code == 200
    assert all(r["id_reporte"] != report_id for r in listing.json())


def test_eliminar_reporte_de_otro_usuario_rechazado(client):
    _, headers_a = _register_and_seed(client)
    email_b = f"rep_b+{uuid.uuid4().hex[:8]}@example.com"
    client.post(
        "/auth/register",
        json={"email": email_b, "password": "Password123!", "name": "B"},
    )
    login_b = client.post(
        "/auth/login",
        data={"email": email_b, "password": "Password123!"},
    )
    headers_b = {"Authorization": f"Bearer {login_b.json()['access_token']}"}

    created = client.post(
        "/reports/environmental",
        headers=headers_a,
        json={"titulo": "Reporte de A", "tipo_reporte": "ambiental"},
    )
    assert created.status_code == 201
    report_id = created.json()["id_reporte"]

    # B no puede eliminar el reporte de A
    deleted = client.delete(f"/reports/{report_id}", headers=headers_b)
    assert deleted.status_code == 404


def test_generar_reporte_sin_analisis_rechazado(client):
    email = f"rep_none+{uuid.uuid4().hex[:8]}@example.com"
    client.post(
        "/auth/register",
        json={"email": email, "password": "Password123!", "name": "None"},
    )
    login = client.post(
        "/auth/login",
        data={"email": email, "password": "Password123!"},
    )
    headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

    resp = client.post(
        "/reports/environmental",
        headers=headers,
        json={"titulo": "Sin datos", "tipo_reporte": "ambiental"},
    )
    assert resp.status_code == 400