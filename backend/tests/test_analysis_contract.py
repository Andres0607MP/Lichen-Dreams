import os
import sys

from fastapi.testclient import TestClient

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from auth.jwt_handler import create_access_token
from main import app


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
    )
    if response.status_code == 200:
        return response.json().get("id")
    return None


def test_analysis_process_contract_uses_spanish_fields():
    response = client.post(
        "/analysis/process",
        json={"image_url": "https://example.com/image.jpg"},
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

    response = client.get(f"/analysis/{analysis_id}/status")

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
        response = client.request(method, path, json=payload)
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


def test_nonexistent_analysis_returns_404():
    """Verify that requesting a non-existent analysis returns 404."""
    response = client.get("/analysis/99999/status")
    assert response.status_code == 404

    response = client.get("/analysis/99999/results")
    assert response.status_code == 404
