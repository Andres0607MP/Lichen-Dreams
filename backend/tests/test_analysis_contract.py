import os
import sys

from fastapi.testclient import TestClient

os.environ.setdefault("DATABASE_URL", "sqlite:///./test.db")

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from auth.jwt_handler import create_access_token
from auth.password_handler import hash_password
from config.database import engine
from config.db import SessionLocal
from models.base import Base
from models.core import Usuario, Role, EspecieLiquen
from main import app

Base.metadata.create_all(bind=engine)


def _seed_admin():
    db = SessionLocal()
    try:
        admin_role = db.query(Role).filter(Role.nombre_rol == 'admin').first()
        if not admin_role:
            admin_role = Role(nombre_rol='admin', descripcion='Administrador', nivel_acceso=10)
            db.add(admin_role)
            db.commit()
            db.refresh(admin_role)
        user_role = db.query(Role).filter(Role.nombre_rol == 'user').first()
        if not user_role:
            user_role = Role(nombre_rol='user', descripcion='Usuario normal', nivel_acceso=1)
            db.add(user_role)
            db.commit()
            db.refresh(user_role)
        admin = db.query(Usuario).filter(Usuario.correo == 'admin@gmail.com').first()
        if not admin:
            admin = Usuario(
                nombre='Admin',
                apellido='User',
                tipo_documento='CC',
                numero_documento='123456789',
                correo='admin@gmail.com',
                contrasena=hash_password('admin123'),
                telefono='3000000000',
                estado_cuenta='active',
                id_rol=admin_role.id_rol,
            )
            db.add(admin)
            db.commit()
        else:
            admin.estado_cuenta = 'active'
            admin.contrasena = hash_password('admin123')
            db.commit()
    finally:
        db.close()


_seed_admin()

client = TestClient(app)


def get_admin_headers():
    token = create_access_token(subject="admin@gmail.com")
    return {"Authorization": f"Bearer {token}"}


ADMIN_HEADERS = get_admin_headers()


def _create_test_analysis():
    """Helper to create a real analysis for testing."""
    response = client.post(
        "/analysis/process",
        json={"image_url": "https://example.com/test_image.jpg"},
        headers=ADMIN_HEADERS,
    )
    if response.status_code == 200:
        return response.json().get("id")
    return None


def test_analysis_process_contract_uses_spanish_fields():
    response = client.post(
        "/analysis/process",
        json={"image_url": "https://example.com/image.jpg"},
        headers=ADMIN_HEADERS,
    )

    assert response.status_code == 200
    payload = response.json()

    expected_fields = {
        "id",
        "id_usuario",
        "url_imagen",
        "resultado",
        "estado",
        "humedad",
        "calidad_del_aire",
        "recomendacion",
        "fecha_creacion",
    }
    assert expected_fields.issubset(payload.keys())
    assert isinstance(payload["resultado"], str)
    assert isinstance(payload["estado"], str)
    assert isinstance(payload["humedad"], (int, float))


def test_analysis_status_contract_uses_spanish_fields():
    analysis_id = _create_test_analysis()
    assert analysis_id is not None, "No se pudo crear el análisis de prueba"

    response = client.get(f"/analysis/{analysis_id}/status", headers=ADMIN_HEADERS)

    assert response.status_code == 200
    payload = response.json()
    assert {"id", "estado", "progreso"}.issubset(payload.keys())


def test_history_contract_uses_spanish_fields():
    response = client.post(
        "/history/save",
        json={"analysis_id": 1, "location": "Bogotá, Colombia"},
        headers=ADMIN_HEADERS,
    )

    assert response.status_code == 201
    payload = response.json()

    expected_fields = {
        "id",
        "id_usuario",
        "id_analisis",
        "resultado",
        "estado",
        "humedad",
        "calidad_del_aire",
        "ubicacion",
        "fecha_creacion",
    }
    assert expected_fields.issubset(payload.keys())
    assert payload["ubicacion"] == "Bogotá, Colombia"


def test_analysis_and_history_endpoints_include_frontend_contract_fields():
    expected_fields = {
        "id",
        "id_usuario",
        "url_imagen",
        "resultado",
        "estado",
        "humedad",
        "calidad_del_aire",
        "recomendacion",
        "fecha_creacion",
    }

    analysis_id = _create_test_analysis()
    assert analysis_id is not None, "No se pudo crear el análisis de prueba"

    analysis_requests = [
        ("GET", f"/analysis/results/{analysis_id}", None),
        ("GET", f"/analysis/{analysis_id}/status", None),
        ("GET", f"/analysis/{analysis_id}/humidity", None),
        ("GET", f"/analysis/{analysis_id}/air-quality", None),
        ("GET", f"/analysis/{analysis_id}/recommendation", None),
        ("GET", f"/analysis/{analysis_id}", None),
    ]

    for method, path, payload in analysis_requests:
        response = client.request(method, path, json=payload, headers=ADMIN_HEADERS)
        assert response.status_code == 200, f"Fallo en {method} {path}: {response.text}"
        body = response.json()
        assert expected_fields.issubset(body.keys()), f"Faltan campos en {path}: {body}"

    history_requests = [
        ("GET", "/history", None),
        ("GET", "/history/user/1", None),
    ]

    for method, path, payload in history_requests:
        response = client.request(method, path, json=payload, headers=ADMIN_HEADERS)
        assert response.status_code == 200, f"Fallo en {method} {path}: {response.text}"
        body = response.json()
        if isinstance(body, list):
            if body:
                assert expected_fields.issubset(body[0].keys())
        else:
            assert expected_fields.issubset(body.keys())


def test_unauthorized_analysis_read_requires_auth():
    """Sin token el acceso a análisis se rechaza: no se expone la existencia."""
    response = client.get("/analysis/99999/status")
    assert response.status_code in (401, 403)

    response = client.get("/analysis/results/99999")
    assert response.status_code in (401, 403)


def test_nonexistent_analysis_returns_404_for_authenticated_user():
    """Autenticado, un análisis inexistente devuelve 404."""
    response = client.get("/analysis/99999/status", headers=ADMIN_HEADERS)
    assert response.status_code == 404

    response = client.get("/analysis/results/99999", headers=ADMIN_HEADERS)
    assert response.status_code == 404


def _ensure_test_species():
    """Crea o reutiliza una especie de prueba en la DB."""
    db = SessionLocal()
    try:
        species = db.query(EspecieLiquen).filter(
            EspecieLiquen.nombre_cientifico == "Test Lichen sp."
        ).first()
        if not species:
            species = EspecieLiquen(
                nombre_cientifico="Test Lichen sp.",
                nombre_comun="Líquen de prueba",
                descripcion="Especie de prueba para tests",
                color_predominante="verde",
                tipo_crecimiento="terricola",
                nivel_tolerancia_contaminacion="medio",
                indicador_calidad_aire="Test indicator",
                habitat="Test habitat",
            )
            db.add(species)
            db.commit()
            db.refresh(species)
        return species.id_especie
    finally:
        db.close()


def test_process_analysis_with_id_especie():
    """POST /analysis/process accepts id_especie and returns species fields."""
    species_id = _ensure_test_species()
    assert species_id is not None

    response = client.post(
        "/analysis/process",
        json={
            "image_url": "https://example.com/test_image.jpg",
            "id_especie": species_id,
        },
        headers=ADMIN_HEADERS,
    )

    assert response.status_code == 200, f"Response: {response.text}"
    payload = response.json()

    assert payload["id_especie"] == species_id
    assert payload["especie_nombre_cientifico"] == "Test Lichen sp."
    assert payload["especie_nombre_comun"] == "Líquen de prueba"


def test_process_analysis_invalid_id_especie_returns_404():
    """POST /analysis/process rejects a non-existent id_especie with 404."""
    response = client.post(
        "/analysis/process",
        json={
            "image_url": "https://example.com/test_image.jpg",
            "id_especie": 999999,
        },
        headers=ADMIN_HEADERS,
    )

    assert response.status_code == 404, f"Expected 404, got {response.status_code}: {response.text}"
