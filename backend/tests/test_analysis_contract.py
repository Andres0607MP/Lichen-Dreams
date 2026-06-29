import os
import sys

from fastapi.testclient import TestClient

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from main import app


client = TestClient(app)


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
