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
    response = client.get("/analysis/1/status")

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

    analysis_requests = [
        ("POST", "/analysis/process", {"image_url": "https://example.com/image.jpg"}),
        ("GET", "/analysis/results/1", None),
        ("GET", "/analysis/1/status", None),
        ("GET", "/analysis/1/humidity", None),
        ("GET", "/analysis/1/air-quality", None),
        ("GET", "/analysis/1/recommendation", None),
        ("GET", "/analysis/1", None),
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
            assert body, "La respuesta de historial no debe estar vacía"
            assert expected_fields.issubset(body[0].keys())
        else:
            assert expected_fields.issubset(body.keys())
